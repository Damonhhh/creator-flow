param(
  [Parameter(Mandatory = $true)]
  [string]$VideoDir,

  [string]$Topic = "",
  [switch]$Force,
  [switch]$ForceBeatMap
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Utf8NoBom {
  param(
    [string]$Path,
    [string]$Content
  )

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$resolvedVideoDir = if ([System.IO.Path]::IsPathRooted($VideoDir)) {
  $VideoDir
} else {
  Join-Path $workspaceRoot $VideoDir
}

if (-not (Test-Path -LiteralPath $resolvedVideoDir)) {
  throw "VideoDir does not exist: $resolvedVideoDir"
}

$webAssetsDir = Join-Path $resolvedVideoDir "draft\web-assets"
$visualPlanDir = Join-Path $resolvedVideoDir "draft\visual-plan"
$generatedIncomingDir = Join-Path $resolvedVideoDir "assets\generated\incoming"
$generatedAcceptedDir = Join-Path $resolvedVideoDir "assets\generated\accepted"
$motionIncomingDir = Join-Path $resolvedVideoDir "assets\motion\incoming"
$motionAcceptedDir = Join-Path $resolvedVideoDir "assets\motion\raw"
New-Item -ItemType Directory -Force -Path $webAssetsDir | Out-Null
New-Item -ItemType Directory -Force -Path $visualPlanDir | Out-Null
New-Item -ItemType Directory -Force -Path $generatedIncomingDir | Out-Null
New-Item -ItemType Directory -Force -Path $generatedAcceptedDir | Out-Null
New-Item -ItemType Directory -Force -Path $motionIncomingDir | Out-Null
New-Item -ItemType Directory -Force -Path $motionAcceptedDir | Out-Null

$topicLine = if ([string]::IsNullOrWhiteSpace($Topic)) { "" } else { $Topic.Trim() }
$createdAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$agentReachCommand = Get-Command agent-reach -ErrorAction SilentlyContinue
$mcporterCommand = Get-Command mcporter -ErrorAction SilentlyContinue
$ghCommand = Get-Command gh -ErrorAction SilentlyContinue
$ytDlpCommand = Get-Command yt-dlp -ErrorAction SilentlyContinue
$curlCommand = Get-Command curl.exe -ErrorAction SilentlyContinue
$channelAvailabilitySummary = @(
  "Agent Reach route=$(if ($agentReachCommand) { 'available' } else { 'unavailable' })",
  "agent-reach wrapper=$(if ($agentReachCommand) { 'available' } else { 'unavailable' })",
  "mcporter=$(if ($mcporterCommand) { 'available' } else { 'unavailable' })",
  "gh=$(if ($ghCommand) { 'available' } else { 'unavailable' })",
  "yt-dlp=$(if ($ytDlpCommand) { 'available' } else { 'unavailable' })",
  "curl=$(if ($curlCommand) { 'available' } else { 'unavailable' })"
) -join "; "
$searchFallback = if ($mcporterCommand) {
  "mcporter Exa after server preflight; gh for repositories; curl/Jina or browser for page reading"
} elseif ($ghCommand) {
  "gh for repositories; curl/Jina or browser for page reading; record web-search blocker"
} else {
  "curl/Jina or browser for page reading; record unavailable search channels before generated-media fallback"
}

$markdownPath = Join-Path $webAssetsDir "source-candidates.md"
$jsonPath = Join-Path $webAssetsDir "source-candidates.json"
$beatMapPath = Join-Path $visualPlanDir "material-beat-map.md"
$generatedMotionPlanPath = Join-Path $visualPlanDir "generated-motion-asset-plan.md"
$stillPromptPackPath = Join-Path $visualPlanDir "still-image-prompt-pack.md"
$carryoverPath = Join-Path (Join-Path $resolvedVideoDir "draft") "production-carryover.md"

$markdownExists = Test-Path -LiteralPath $markdownPath
$jsonExists = Test-Path -LiteralPath $jsonPath
$beatMapExists = Test-Path -LiteralPath $beatMapPath
$generatedMotionPlanExists = Test-Path -LiteralPath $generatedMotionPlanPath
$stillPromptPackExists = Test-Path -LiteralPath $stillPromptPackPath
$carryoverExists = Test-Path -LiteralPath $carryoverPath
$writeMarkdown = (-not $markdownExists) -or $Force
$writeJson = (-not $jsonExists) -or $Force
$writeBeatMap = (-not $beatMapExists) -or $ForceBeatMap
$writeGeneratedMotionPlan = (-not $generatedMotionPlanExists) -or $ForceBeatMap
$writeStillPromptPack = (-not $stillPromptPackExists) -or $ForceBeatMap
$writeCarryover = (-not $carryoverExists) -or $Force

$markdown = @'
# Internet Source Candidates

- Topic: {{TOPIC}}
- Created at: {{CREATED_AT}}
- Contract: agent-reach-material-v1
- Discovery layer: Agent Reach when installed; otherwise use only fallback channels that pass local preflight
- Extraction/download layer: Scrapling / media-downloader
- External sourcing status: not-assessed
- Channel availability summary: {{CHANNEL_AVAILABILITY}}
- Search fallback: {{SEARCH_FALLBACK}}
- Storage: this file is for one-video temporary web assets. Reusable sources move to `content-planning/04-material-library` only after their source, risk, and use are clear.

Set `External sourcing status` to `sourced`, `exhausted`, `blocked`, or `not-needed` after the search pass.

## Rules

1. Start from a locked `LINE##` spoken sentence and its visual task: prove, explain, analogize, transition, or close.
2. Build the query from the spoken subject, the visual task, and the visible action/state required on screen. Topic-only search is not enough.
3. Use Agent Reach as the discovery router: search, video, social, or web. Record the actual route/command and channel preflight result; do not claim an unavailable CLI worked.
4. Find the original source first: official pages, release pages, product pages, event pages, GitHub, original videos, and original posts.
5. Every candidate must state the exact `LINE##`, spoken time, useful source timestamp/page region, and why its visible subject/action aligns with the narration.
6. Agent Reach is for search, reading, metadata, captions, community reactions, and source discovery. Use browser capture or media-downloader only after the exact source/timestamp is clear.
7. Third-party material defaults to short quotation, screenshot evidence, transcript lead, or off-screen reference, with rights/provenance risk recorded.
8. Subtitles follow narration only. Source labels and extra explanations belong to separate visual layers.

## Candidates

### 1.

- Source URL:
- Platform / type:
- Spoken line ID / time:
- Visual task: prove / explain / analogize / transition / close
- Material role:
- Agent Reach route / command:
- Channel preflight:
- Search query:
- Useful source timestamp / page region:
- Matched visible subject / action:
- Why it aligns with the spoken sentence:
- What it proves:
- Visual use:
- Recommended handling: screenshot / short quote / transcript lead / off-screen reference / downloadable asset / discard
- Rights and risk:
- Local path:
- Status: pending

## Checklist

- [ ] At least one official or first-hand source exists
- [ ] At least one visual proof can be used in the first 10 seconds
- [ ] Every accepted candidate names its `LINE##`, visual task, query, Agent Reach route, and useful timestamp/page region
- [ ] Selected shots visibly match the spoken subject/action, not only the general topic
- [ ] Unavailable Agent Reach channels and fallbacks are recorded
- [ ] Weak webpages are not used as long-hold main visuals
- [ ] Each third-party source has a risk and use note
- [ ] Assets that enter `assets/` are separated from sources that remain in `draft\web-assets\`
'@

$markdown = $markdown.Replace("{{TOPIC}}", $topicLine).Replace("{{CREATED_AT}}", $createdAt).Replace("{{CHANNEL_AVAILABILITY}}", $channelAvailabilitySummary).Replace("{{SEARCH_FALLBACK}}", $searchFallback)

$json = [ordered]@{
  topic = $topicLine
  createdAt = $createdAt
  discoveryLayer = "agent-reach"
  externalSourcingStatus = "not-assessed"
  channelAvailabilitySummary = $channelAvailabilitySummary
  searchFallback = $searchFallback
  extractionLayer = @("scrapling", "media-downloader")
  candidates = @(
    [ordered]@{
      sourceUrl = ""
      platform = ""
      sourceType = ""
      spokenLineId = ""
      spokenTime = ""
      visualTask = ""
      materialRole = ""
      agentReachRoute = ""
      discoveryCommand = ""
      channelPreflight = ""
      searchQuery = ""
      usefulTimestampOrRegion = ""
      matchedVisibleSubjectAction = ""
      sentenceAlignment = ""
      proves = ""
      visualUse = ""
      recommendedHandling = ""
      rightsRisk = ""
      localPath = ""
      status = "pending"
    }
  )
} | ConvertTo-Json -Depth 8

$beatMap = @'
# Material Beat Map

- Topic: {{TOPIC}}
- Created at: {{CREATED_AT}}
- Contract: visual-task-v1; motion-job-v1.1
- Use this file before HyperFrames assembly. Replace every TODO row with the actual spoken sentence, exact time, visual task, source path, motion job, and fallback.

## Rules

1. Give every complete spoken sentence or semantic unit a stable `LINE##` and one primary visual task: prove, explain, analogize, transition, or close.
2. This is a coverage rule, not a forced cut rule. Two short consecutive lines may share one `VT##` only when they keep the same visible subject/action and continuous time window.
3. Job remains the material role: prove, explain, advance, or texture. Map visual tasks as `prove -> prove`, `explain/analogize -> explain`, and `transition/close -> advance`; texture is auxiliary only.
4. Explain or abstract lines must put the semantic action inside the Motion Treatment column as `motion job: <action>; subject: <visible object>; change: <from state -> to state>; fallback: <fallback plan>`.
5. The action must describe what visibly changes: enter, split, route, compress, connect, verify, fail, resolve, sort, classify, or transform.
6. Proof lines should use first-hand or product/source material. Explain/analogize lines can use diagrams, generated visuals, Xiaohei scenes, or motion graphics.
7. Subtitles follow the spoken sentence only and do not count as the visual task.
8. Do not leave TODO rows before running draft QA.

## Beat Map

| Line ID | Time | Spoken sentence | Task ID | Visual Task | Job | Material | Motion Treatment | Fallback / next action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LINE01 | 00:00-00:08 | TODO: complete opening sentence | VT01 | prove | advance + prove | TODO: first visible proof or concrete scene | motion job: enter; subject: viewer question and first proof; change: vague question -> visible proof; fallback: caption-safe proof scene with camera push | TODO |
| LINE02 | 00:08-00:18 | TODO: complete fact sentence | VT02 | prove | prove | TODO: Agent Reach source timestamp, product capture, or recorded operation | motion job: highlight; subject: source claim area; change: full screen -> cited detail; fallback: zoomed crop with readable source label | TODO |
| LINE03 | 00:18-00:30 | TODO: complete abstract-concept sentence | VT03 | explain | explain | TODO: diagram, Xiaohei scene, or generated explain asset | motion job: split; subject: abstract concept; change: one label -> visible parts; fallback: Xiaohei scene showing the split action | TODO |
| LINE04 | 00:30-00:42 | TODO: complete process sentence | VT04 | explain | explain + advance | TODO: workflow capture or motion graphic | motion job: route; subject: input request; change: raw input -> verified output state; fallback: step diagram with moving highlight | TODO |
| LINE05 | 00:42-00:54 | TODO: complete analogy/example sentence | VT05 | analogize | explain | TODO: real case, physical analogy, or side-by-side scene | motion job: compare; subject: two visible states; change: old state -> new state; fallback: side-by-side crop with reveal mask | TODO |
| LINE06 | 00:54-01:06 | TODO: complete takeaway sentence | VT06 | close | advance | TODO: concrete checklist, action path, or final scene | motion job: compress; subject: action path; change: scattered steps -> one take-away action; fallback: final checklist with sequential highlight | TODO |

## Asset Intake Notes

- Accepted asset path:
- Source or provenance:
- Dimensions / duration:
- Role in timeline:
- Risk / license note:
- Next action:
'@

$beatMap = $beatMap.Replace("{{TOPIC}}", $topicLine).Replace("{{CREATED_AT}}", $createdAt)

$generatedMotionPlan = @'
# Generated Image And Motion Asset Plan

- Topic: {{TOPIC}}
- Created at: {{CREATED_AT}}
- Contract: generated-material-readiness-v1
- Purpose: lock the script, source real material first, audit timed coverage, prepare surplus stills for the remaining gaps, inspect returned images, and only then choose HyperFrames, Jimeng, or the third-party Grok-compatible motion route.
- Reference: `.agents/skills/zimeiti-video-workflow/references/stage-material.md`

## Branch Decision

- Script status: not-locked
- Timed beat source:
- Generation branch: not-assessed
- Material readiness: sourcing
- External material coverage:
- Internal reusable asset coverage:
- Remaining uncovered beats:
- Cardification risk:
- Decision and reason:
- Minimum coverage stills: 0
- Planned still prompts: 0
- Required surplus stills: 0
- Pre-intake motion exception: none

Set `Generation branch` to `not-needed` or `required` after the coverage audit. Set `Material readiness: complete` only when all required still and motion intake is finished.

Allowed readiness sequence:

`sourcing -> prompt-pack-ready -> awaiting-user-stills -> stills-received -> motion-planned -> motion-ready -> complete`

## Rules

1. Lock the spoken script and map exact beat times before writing prompts.
2. Check material in order: external proof/source footage, existing internal assets, generated stills, then external image-to-video.
3. `not-needed` is a valid branch decision. Use `required` only when named timed beats remain uncovered or would otherwise become repetitive cards.
4. Plan enough still prompts to cover the minimum plus `max(2, ceil(minimum * 20%))` alternates. Give hook and key mechanism beats first claim on alternates.
5. Every still image needs a stable `IMG##-slug`, exact expected filename, spoken beat, material role, coverage use, and acceptance check.
6. Before still intake, use `pending-after-intake`; do not assign a motion provider or write image-to-video prompts unless the named exception does not need a source image.
7. After visual intake, mark every still `motion-required`, `local-motion`, `static-support`, or `reject` and name the owner.
8. HyperFrames owns deterministic zoom, mask, route, highlight, and sequential reveal. Jimeng or the third-party Grok-compatible route owns only named external motion jobs.
9. Every external motion clip needs a stable `MOV##-slug`, accepted source image, target duration, one visible action, end-state/tail-frame requirement, provider, and fallback.
10. External clips default to 4-6 seconds and must not exceed 10 seconds.
11. Returned assets need rename/intake maps before assembly: `source-image-rename-map.md`, `source-motion-rename-map.md`, and `motion-video-intake.md` when motion is used.
12. Raw generated assets and extra MP4s must not enter `publish\`.

## Material Coverage Gaps

| Beat / time | Visual need | External candidate | Internal candidate | Gap / cardification risk | Chosen path |
| --- | --- | --- | --- | --- | --- |
| TODO | TODO | TODO | TODO | TODO | real asset / generated still / local motion / Jimeng <=10s / not-needed |

## Prompt Packs

- Still-image prompt pack: `draft\visual-plan\still-image-prompt-pack.md`
- Motion-video prompt pack: pending-after-still-intake
- Returned stills folder: `assets\generated\incoming\`
- Accepted stills folder: `assets\generated\accepted\`
- Source-image intake map: `draft\visual-plan\source-image-rename-map.md`
- Returned motion folder: `assets\motion\incoming\`
- Accepted motion folder: `assets\motion\raw\`

## Generated Still Plan

| Image ID | Beat / time | Role | Coverage use | Visual job | Prompt source | Decision after intake | Motion owner | Acceptance check | Expected filename |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| IMG01-hook | TODO | advance + explain | primary | TODO: opening concrete scene | still prompt pack | pending-after-intake | pending | clear focal subject; no generated text; subtitle-safe | `IMG01-hook.png` |
| IMG02-hook-alt | TODO | advance + explain | alternate-for: IMG01-hook | TODO: alternate framing for the hook | still prompt pack | pending-after-intake | pending | visibly different composition; same semantic beat | `IMG02-hook-alt.png` |
| IMG03-process | TODO | explain | primary | TODO: invisible mechanism becomes a visible process | still prompt pack | pending-after-intake | pending | action-ready composition; no fake UI or logo | `IMG03-process.png` |

## Motion Clip Plan

Do not add `MOV##` rows before returned stills are inspected and accepted, unless `Pre-intake motion exception` names a source-image-free route and explains why it is necessary.

| Motion ID | Source image | Beat / time | Provider | Duration | Visible action | End-state / tail frame | Fallback | Accepted path |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- |

## Intake Checklist

- [ ] The still prompt pack is complete, copyable, and uses the same `IMG##` IDs and exact expected filenames as this plan.
- [ ] Planned prompts cover the minimum need plus the required surplus; alternates target the hook and key mechanism beats first.
- [ ] Script is locked and every generated asset maps to an exact beat/time range.
- [ ] External and internal asset coverage was checked before the generation branch was selected.
- [ ] The user handoff names the exact return folder and expected filenames.
- [ ] Returned stills were visually inspected before rename.
- [ ] Every accepted still has a post-intake decision: local motion, external motion, static support, or reject.
- [ ] Motion providers were chosen only after still intake.
- [ ] Every external motion prompt is 10 seconds or shorter and asks for only one visible action.
- [ ] Returned motion clips were visually inspected before rename.
- [ ] Rename maps were written.
- [ ] Motion clips were probed with `ffprobe`.
- [ ] Tail-frame or end-state risks were recorded for assembly.
- [ ] No raw generated assets or extra MP4s are in `publish\`.
'@

$generatedMotionPlan = $generatedMotionPlan.Replace("{{TOPIC}}", $topicLine).Replace("{{CREATED_AT}}", $createdAt)

$stillPromptPack = @'
# Still Image Prompt Pack

- Topic: {{TOPIC}}
- Created at: {{CREATED_AT}}
- Contract: still-image-prompt-pack-v1
- Prompt pack status: draft
- Return folder: `{{RETURN_FOLDER}}`
- Accepted folder after inspection: `{{ACCEPTED_FOLDER}}`
- Filename rule: use the exact `IMG##-slug.ext` names below; do not return date-based or random filenames.
- Minimum coverage stills: 0
- Planned still prompts: 0
- Required surplus stills: 0
- Surplus rule: minimum coverage plus `max(2, ceil(minimum * 20%))`; prioritize hook and key-mechanism alternates.

Set `Prompt pack status: ready` only after every expected file has a complete prompt and acceptance check.

## User Handoff

Generate every file in the table, keep the requested orientation and safe area, then place the results directly in:

`{{RETURN_FOLDER}}`

The Material stage pauses at `awaiting-user-stills` until these files return. Motion route selection happens after visual inspection; no image needs to be animated merely because it was generated.

## Expected Files

| Image ID | Expected filename | Beat / task | Coverage use | Acceptance check |
| --- | --- | --- | --- | --- |
| IMG01-hook | `IMG01-hook.png` | TODO: LINE## / VT## / time | primary | TODO: focal subject, composition, safe area, forbidden artifacts |
| IMG02-hook-alt | `IMG02-hook-alt.png` | TODO: same hook beat | alternate-for: IMG01-hook | TODO: genuinely different usable framing |
| IMG03-process | `IMG03-process.png` | TODO: LINE## / VT## / time | primary | TODO: visible process, no fake UI/text/logo |

## Prompt: IMG01-hook

- Expected filename: `IMG01-hook.png`
- Orientation / aspect ratio: TODO
- Prompt: TODO: describe one usable scene, visible subject, action-ready composition, depth, and subtitle-safe area.
- Negative constraints: no readable generated text, no logo, no watermark, no fake platform UI, no poster layout.
- Local overlay boundary: Chinese labels and interface overlays will be added later in HyperFrames.

## Prompt: IMG02-hook-alt

- Expected filename: `IMG02-hook-alt.png`
- Orientation / aspect ratio: TODO
- Prompt: TODO: create a semantically equivalent but visibly different hook composition.
- Negative constraints: no readable generated text, no logo, no watermark, no fake platform UI, no poster layout.
- Local overlay boundary: Chinese labels and interface overlays will be added later in HyperFrames.

## Prompt: IMG03-process

- Expected filename: `IMG03-process.png`
- Orientation / aspect ratio: TODO
- Prompt: TODO: make the invisible mechanism visible as one scene with a clear start state and possible change direction.
- Negative constraints: no readable generated text, no logo, no watermark, no fake platform UI, no poster layout.
- Local overlay boundary: Chinese labels and interface overlays will be added later in HyperFrames.
'@

$stillPromptPack = $stillPromptPack.Replace("{{TOPIC}}", $topicLine).Replace("{{CREATED_AT}}", $createdAt).Replace("{{RETURN_FOLDER}}", $generatedIncomingDir).Replace("{{ACCEPTED_FOLDER}}", $generatedAcceptedDir)

$carryover = @'
# Production Carryover

- Topic: {{TOPIC}}
- Created at: {{CREATED_AT}}
- Purpose: turn previous production learnings into actions for this video. Do not paste old case names here; write what this video will actually do.

## Active Rules

| Rule | This video's concrete action | Owner stage | Evidence path |
| --- | --- | --- | --- |
| Hook gives a take-away | TODO: what can the viewer take away after watching? | Script TTS | TODO |
| Proof appears before polish | TODO: what real source/proof appears in the first 10 seconds? | Material / Assembly | TODO |
| Abstract nouns become actions | TODO: which core nouns need motion jobs, and what visibly changes? | Material | `draft\visual-plan\material-beat-map.md` |
| Invisible mechanisms get process visuals | TODO: what mechanism becomes a visible process, chart, state change, or path? | Material / Assembly | `draft\visual-plan\material-beat-map.md` |
| Key terms and entities get anchors | TODO: which technical term gets emphasis, and which named company/tool/protocol gets a source or neutral entity anchor? | Material / Assembly | TODO |
| Visual rhythm has breathing points | TODO: where does the viewer get a short visual reset between dense ideas? | Assembly | TODO |
| Closing thesis lands visually | TODO: what is the final one-sentence thesis card or closing visual anchor? | Assembly / QA | TODO |
| Publish package closes the loop | TODO: title, body, first comment, cover, QA, manifest plan | Publish Wrap Up | TODO |

## Carryover Gate

- [ ] Every TODO above has been replaced with a concrete action for this video.
- [ ] The beat map contains action / subject / change / fallback for explain or abstract beats.
- [ ] Technical or invisible mechanisms have process visuals, entity anchors, and key-term emphasis where relevant.
- [ ] The first 0-3 seconds contains one focal claim and one visible proof or concrete scene.
- [ ] The ending has a deliberate closing visual, not just a leftover summary card.
- [ ] The final package will include title, body, first comment, cover, subtitles, QA report, and sync evidence.
'@

$carryover = $carryover.Replace("{{TOPIC}}", $topicLine).Replace("{{CREATED_AT}}", $createdAt)

if ($writeMarkdown) {
  Write-Utf8NoBom -Path $markdownPath -Content $markdown
}
if ($writeJson) {
  Write-Utf8NoBom -Path $jsonPath -Content ($json + "`n")
}
if ($writeBeatMap) {
  Write-Utf8NoBom -Path $beatMapPath -Content $beatMap
}
if ($writeGeneratedMotionPlan) {
  Write-Utf8NoBom -Path $generatedMotionPlanPath -Content $generatedMotionPlan
}
if ($writeStillPromptPack) {
  Write-Utf8NoBom -Path $stillPromptPackPath -Content $stillPromptPack
}
if ($writeCarryover) {
  Write-Utf8NoBom -Path $carryoverPath -Content $carryover
}

if ($writeMarkdown) {
  Write-Host "Wrote: $markdownPath"
} else {
  Write-Host "Skipped existing: $markdownPath. Use -Force to overwrite it."
}
if ($writeJson) {
  Write-Host "Wrote: $jsonPath"
} else {
  Write-Host "Skipped existing: $jsonPath. Use -Force to overwrite it."
}
if ($writeBeatMap) {
  Write-Host "Wrote: $beatMapPath"
} else {
  Write-Host "Skipped existing: $beatMapPath. Use -ForceBeatMap to overwrite it."
}
if ($writeGeneratedMotionPlan) {
  Write-Host "Wrote: $generatedMotionPlanPath"
} else {
  Write-Host "Skipped existing: $generatedMotionPlanPath. Use -ForceBeatMap to overwrite it."
}
if ($writeStillPromptPack) {
  Write-Host "Wrote: $stillPromptPackPath"
} else {
  Write-Host "Skipped existing: $stillPromptPackPath. Use -ForceBeatMap to overwrite it."
}
if ($writeCarryover) {
  Write-Host "Wrote: $carryoverPath"
} else {
  Write-Host "Skipped existing: $carryoverPath. Use -Force to overwrite it."
}

$stateScript = Join-Path $PSScriptRoot "update-video-project-state.ps1"
if (Test-Path -LiteralPath $stateScript) {
  & $stateScript `
    -VideoDir $resolvedVideoDir `
    -CurrentStage "Material" `
    -StageStatus "in_progress" `
    -NextAction "Lock LINE## timing, source first-hand material, audit coverage, then set Generation branch and Material readiness before Assembly." `
    -Source "new-video-source-candidates.ps1" | Out-Null
}
