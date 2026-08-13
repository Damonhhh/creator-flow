import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(scriptDir, '..');
const defaultRulesPath = path.join(workspaceRoot, 'config', 'ai-daily-briefing-public-rules.json');

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith('--')) {
      args[key] = true;
    } else {
      args[key] = next;
      index += 1;
    }
  }
  return args;
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/, ''));
}

function canonicalizeUrl(value, trackingParams) {
  try {
    const url = new URL(value);
    for (const key of [...url.searchParams.keys()]) {
      const lower = key.toLowerCase();
      if (trackingParams.some((param) => lower === param || lower.startsWith(param))) {
        url.searchParams.delete(key);
      }
    }
    url.hash = '';
    return url.toString();
  } catch {
    return String(value || '').trim();
  }
}

function hostnameFor(value) {
  try {
    return new URL(value).hostname.replace(/^www\./, '').toLowerCase();
  } catch {
    return '';
  }
}

function domainMatches(host, domain) {
  return host === domain || host.endsWith(`.${domain}`);
}

function isOfficialSocialSource(source, policy) {
  const text = String(source || '').toLowerCase();
  return (policy.official_social_sources || []).some((needle) => text.includes(String(needle).toLowerCase()));
}

function sourceTierFor(host, source, policy) {
  for (const [tier, domains] of Object.entries(policy.tier_domains || {})) {
    if ((domains || []).some((domain) => domainMatches(host, String(domain).toLowerCase()))) {
      if (tier === 'social_signal' && isOfficialSocialSource(source, policy)) return 'official_social';
      return tier;
    }
  }
  return host ? 'unknown' : 'missing_link';
}

function evidenceRoleFor(tier) {
  if (tier === 'official' || tier === 'research') return 'primary_source_candidate';
  if (tier === 'credible_media' || tier === 'developer_community' || tier === 'official_social') {
    return 'confirmation_source_candidate';
  }
  return 'discovery_only';
}

function verificationNoteFor(tier) {
  if (tier === 'official') return '阅读原文，确认发布时间、能力边界、开放范围和限制。';
  if (tier === 'research') return '回到论文、代码或模型卡，区分作者主张与独立复现。';
  if (tier === 'credible_media') return '媒体可作交叉确认；关键数字、引语和产品细节仍回到一手源。';
  if (tier === 'developer_community') return '先确认项目归属、版本、许可证和可复现状态。';
  if (tier === 'official_social') return '可确认官方宣布与时间；完整能力、灰度和价格仍查官方文档。';
  if (tier === 'social_signal') return '只作线索，必须找到官方原文或第二个可靠来源。';
  if (tier === 'aggregator') return '聚合页不作证据，必须跳转并核验原始来源。';
  return '来源等级未登记，进入简报前必须人工核验。';
}

function normalizeKey(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/https?:\/\/(www\.)?/, '')
    .replace(/[?#].*$/, '')
    .replace(/[^\p{L}\p{N}]+/gu, '')
    .trim();
}

function trendRadarCategory(groups = []) {
  const values = new Set(groups.map((group) => String(group)));
  if (values.has('models_products')) return 'ai-models';
  if (values.has('agents_coding')) return 'ai-products';
  if (values.has('research_multimodal')) return 'paper';
  return 'industry';
}

function categoryBonus(category) {
  if (category === 'ai-models' || category === 'ai-products') return 10;
  if (category === 'industry' || category === 'paper') return 5;
  return 0;
}

function sourceBonus(tier) {
  return ({ official: 20, research: 16, credible_media: 12, developer_community: 10, official_social: 10, social_signal: 0, unknown: -4, aggregator: -12, missing_link: -20 })[tier] ?? -4;
}

function recencyBonus(publishedAt, since, now) {
  const published = Date.parse(publishedAt || '');
  const start = Date.parse(since);
  if (!Number.isFinite(published) || !Number.isFinite(start) || published < start) return 0;
  const span = Math.max(now - start, 1);
  return Math.max(0, Math.min(10, Math.round(((published - start) / span) * 10)));
}

function normalizeCandidate(raw, index, context) {
  const isTrendRadar = raw.__radar === 'trendradar';
  const title = String(raw.title || '').replace(/\s+/g, ' ').trim();
  const source = String(isTrendRadar ? raw.source_name : raw.source || 'AI Hot').trim();
  const url = canonicalizeUrl(isTrendRadar ? raw.url || raw.mobile_url : raw.url, context.trackingParams);
  const publishedAt = String(isTrendRadar ? raw.published_at : raw.publishedAt || '').trim();
  const category = isTrendRadar ? trendRadarCategory(raw.matched_groups || []) : String(raw.category || 'industry');
  const sourceTier = sourceTierFor(hostnameFor(url), source, context.policy);
  const baseScore = Number(isTrendRadar ? 0 : raw.score || 0);
  const triageScore = baseScore + sourceBonus(sourceTier) + categoryBonus(category) + recencyBonus(publishedAt, context.since, context.now);

  return {
    id: isTrendRadar ? `trendradar:${raw.source_id || 'source'}:${index + 1}` : `aihot:${raw.id || index + 1}`,
    discovery_source: isTrendRadar ? 'TrendRadar' : 'AI Hot',
    title,
    source,
    url,
    source_host: hostnameFor(url),
    source_tier: sourceTier,
    evidence_role: evidenceRoleFor(sourceTier),
    verification_required: true,
    verification_note: verificationNoteFor(sourceTier),
    publishedAt,
    category,
    summary: String(raw.summary || '').replace(/\s+/g, ' ').trim(),
    discovery_score: baseScore || null,
    triage_score: triageScore,
    selected_by_aihot: isTrendRadar ? null : Boolean(raw.selected),
    matched_groups: isTrendRadar ? raw.matched_groups || [] : [],
    rank: isTrendRadar ? raw.rank ?? null : null,
    attribution_url: isTrendRadar ? '' : String(raw.attribution?.canonical || raw.permalink || ''),
  };
}

function dedupe(items) {
  const seen = new Set();
  const output = [];
  for (const item of items) {
    const keys = [normalizeKey(item.url), normalizeKey(item.title)].filter((key) => key.length >= 8);
    if (keys.some((key) => seen.has(key))) continue;
    keys.forEach((key) => seen.add(key));
    output.push(item);
  }
  return output;
}

function countBy(items, field) {
  return items.reduce((result, item) => {
    const key = String(item[field] || 'unknown');
    result[key] = (result[key] || 0) + 1;
    return result;
  }, {});
}

async function fetchAihot({ since, take, mode }) {
  const url = new URL('https://aihot.virxact.com/api/public/items');
  url.searchParams.set('mode', mode);
  url.searchParams.set('since', since);
  url.searchParams.set('take', String(Math.min(Math.max(take, 20), 100)));
  const response = await fetch(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/125.0 Safari/537.36',
      Accept: 'application/json',
    },
  });
  if (!response.ok) throw new Error(`AI Hot request failed: ${response.status} ${response.statusText}`);
  return response.json();
}

function readTrendRadar(filePath) {
  if (!filePath) return { items: [], error: '', path: '' };
  const resolved = path.resolve(filePath);
  if (!fs.existsSync(resolved)) return { items: [], error: `file not found: ${resolved}`, path: resolved };
  try {
    const payload = readJson(resolved);
    return {
      items: (Array.isArray(payload.items) ? payload.items : []).filter((item) => item?.source_type !== 'error').map((item) => ({ ...item, __radar: 'trendradar' })),
      error: '',
      path: resolved,
    };
  } catch (error) {
    return { items: [], error: error instanceof Error ? error.message : String(error), path: resolved };
  }
}

const args = parseArgs(process.argv.slice(2));
const date = args.date || new Date().toISOString().slice(0, 10);
const hours = Number(args.hours || 48);
const maxItems = Math.min(Math.max(Number(args.max || 100), 1), 100);
const now = Date.now();
const since = args.since ? new Date(args.since).toISOString() : new Date(now - hours * 60 * 60 * 1000).toISOString();
const outputRoot = path.resolve(args['output-root'] || path.join(workspaceRoot, 'output', 'ai-daily-signal-radar', date));
const outputPath = path.resolve(args.out || path.join(outputRoot, `${date}-ai-daily-signal-radar.json`));
const rulesPath = path.resolve(args.rules || defaultRulesPath);
const rules = readJson(rulesPath);
const policy = rules.source_policy || {};
const trackingParams = policy.tracking_params || [];
const fallbackMin = Number(args['selected-fallback-min-items'] ?? policy.selected_fallback_min_items ?? 10);
const liveCollection = args['live-collection'] === true || args['live-collection'] === 'true';

try {
  let selectedPayload;
  let allPayload = { items: [] };
  if (args['aihot-input']) {
    selectedPayload = readJson(path.resolve(args['aihot-input']));
  } else if (liveCollection) {
    selectedPayload = await fetchAihot({ since, take: maxItems, mode: 'selected' });
  } else {
    selectedPayload = { items: [] };
  }

  const selectedItems = Array.isArray(selectedPayload.items) ? selectedPayload.items : [];
  if (liveCollection && !args['aihot-input'] && selectedItems.length < Math.min(fallbackMin, maxItems)) {
    allPayload = await fetchAihot({ since, take: 100, mode: 'all' });
  }
  const fallbackItems = Array.isArray(allPayload.items) ? allPayload.items : [];
  const trendRadar = readTrendRadar(args['trendradar-input']);
  const rawItems = [...selectedItems, ...fallbackItems, ...trendRadar.items];
  const normalized = rawItems
    .map((item, index) => normalizeCandidate(item, index, { policy, trackingParams, since, now }))
    .filter((item) => item.title && (!item.publishedAt || Date.parse(item.publishedAt) >= Date.parse(since)));
  const items = dedupe(normalized)
    .sort((left, right) => right.triage_score - left.triage_score || String(right.publishedAt).localeCompare(String(left.publishedAt)))
    .slice(0, maxItems);

  const result = {
    date,
    generated_at: new Date(now).toISOString(),
    since,
    hours,
    role: 'discovery_candidates_only',
    decision_boundary: '候选池不等于今日选题。内部简报只保留 1~3 条，并在回到官方原文或可靠交叉来源核验后再写。',
    rules_path: rulesPath,
    sources: {
      aihot: {
        endpoint: 'https://aihot.virxact.com/api/public/items',
        live_collection: liveCollection,
        mode: 'selected',
        selected_count: selectedItems.length,
        all_fallback_count: fallbackItems.length,
        fallback_triggered: fallbackItems.length > 0,
      },
      trendradar: {
        path: trendRadar.path,
        candidate_count: trendRadar.items.length,
        error: trendRadar.error,
      },
    },
    health: {
      status: selectedItems.length > 0 ? (trendRadar.error ? 'degraded' : 'healthy') : 'degraded',
      raw_count: rawItems.length,
      candidate_count: items.length,
      duplicate_or_filtered_count: rawItems.length - items.length,
      category_counts: countBy(items, 'category'),
      source_tier_counts: countBy(items, 'source_tier'),
      discovery_source_counts: countBy(items, 'discovery_source'),
      primary_source_candidate_count: items.filter((item) => item.evidence_role === 'primary_source_candidate').length,
      discovery_only_count: items.filter((item) => item.evidence_role === 'discovery_only').length,
    },
    items,
  };

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
  console.log(JSON.stringify({ success: true, output_path: outputPath, candidate_count: items.length, health: result.health.status, aihot_selected_count: selectedItems.length, aihot_all_fallback_count: fallbackItems.length, trendradar_count: trendRadar.items.length }));
} catch (error) {
  console.error(error instanceof Error ? error.stack : String(error));
  process.exit(1);
}
