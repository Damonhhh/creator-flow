from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path


ZH_CONTENT_PLAN = "\u5185\u5bb9\u4f01\u5212"
ZH_INBOX = "00-\u6536\u4ef6\u7bb1"
ZH_SERIES = "01-\u5408\u96c6\u4f01\u5212"
ZH_SINGLE = "02-\u5355\u6761\u4f01\u5212"
ZH_MAINLINE = "AI\u70ed\u70b9\u5b9e\u64cd\u9a8c\u8bc1\u4e3b\u7ebf"
ZH_DAILY_BRIEF = "AI\u9009\u9898\u65e5\u62a5.md"
ZH_DECISION = "\u4e3b\u7ebf\u9009\u9898\u51b3\u7b56.md"
ZH_RECOMMENDED_SECTION = "\u63a8\u8350\u5f53\u5929\u6700\u9002\u5408\u505a\u7684\u4e00\u6761"
ZH_RECOMMENDED_SECTION_ALT = "\u63a8\u8350\u4eca\u5929\u6700\u9002\u5408\u505a\u7684\u4e00\u6761"
ZH_TODAY_RECOMMENDATION = "\u4eca\u65e5\u63a8\u8350"
ZH_TODAY_RECOMMENDATION_SECTION = "\u4eca\u65e5\u63a8\u8350\u9009\u9898"
ZH_EVERGREEN_FALLBACK = "\u4eca\u65e5\u6539\u505a\u5e38\u9752\u9898"
ZH_EVERGREEN_FALLBACK_ALT = "\u4eca\u5929\u6539\u505a\u5e38\u9752\u9898"
ZH_RECOMMEND = "\u63a8\u8350"
ZH_TITLE_OPTIONS_HEADING = "### \u6807\u9898\u5907\u9009"
ZH_OPENING_HEADING = "### 30 \u79d2\u5f00\u5934\u65b9\u5411"
ZH_CORE_VIEWPOINT_HEADING = "### \u6838\u5fc3\u89c2\u70b9"
ZH_ASSET_CHECKLIST_HEADING = "### \u7d20\u6750\u6e05\u5355"
ZH_WHY_ORDINARY_PEOPLE_CARE = "\u4e3a\u4ec0\u4e48\u503c\u5f97\u666e\u901a\u4eba\u5173\u6ce8\uff1a"
ZH_ACCOUNT_CONNECTION = "\u4e0e\u672c\u8d26\u53f7\u7684\u8fde\u63a5\u70b9\uff1a"
ZH_VIDEO_ASSET_DIRECTION = "\u53ef\u7528\u89c6\u9891\u7d20\u6750\u65b9\u5411\uff1a"
ZH_EVENT_FACT = "\u4e8b\u4ef6\u4e8b\u5b9e\uff1a"
ZH_MANUAL_CONFIRMATION_PLACEHOLDER = "\u4eca\u65e5\u4e3b\u7ebf\u63a8\u8350\u5f85\u4eba\u5de5\u786e\u8ba4"

TAKEAWAY_TYPES = [
    ("\u529f\u80fd\u5dee\u5f02", ("API", "\u529f\u80fd", "\u66f4\u65b0", "\u80fd\u529b", "\u5dee\u5f02", "\u5bf9\u7167", "\u652f\u6301")),
    ("\u4f7f\u7528\u6b65\u9aa4", ("\u600e\u4e48", "\u6b65\u9aa4", "\u6559\u7a0b", "\u7167\u7740", "\u6d41\u7a0b", "\u4efb\u52a1")),
    ("\u6210\u672c\u53d8\u5316", ("\u4ef7\u683c", "\u6210\u672c", "\u989d\u5ea6", "\u7b97\u529b", "\u878d\u8d44", "\u4f30\u503c")),
    ("\u5c97\u4f4d\u5f71\u54cd", ("\u5c97\u4f4d", "\u5de5\u4f5c", "\u767d\u9886", "\u66ff\u4ee3", "\u4eba", "\u56e2\u961f")),
    ("\u98ce\u9669\u6e05\u5355", ("\u98ce\u9669", "\u5751", "\u9519", "\u5931\u8d25", "\u8bef\u5bfc", "\u4e0d\u9002\u5408")),
    ("\u771f\u5b9e\u6848\u4f8b", ("\u6848\u4f8b", "case", "\u771f\u5b9e", "\u751f\u4ea7", "\u5ba2\u6237", "\u4ece\u4e1a\u8005")),
    ("\u5de5\u5177\u5bf9\u6bd4", ("\u5bf9\u6bd4", "Cursor", "Claude", "Grok", "Gemini", "\u53ef\u63d2\u62d4", "\u5de5\u5177\u5bf9\u6bd4")),
    ("\u9002\u7528\u8fb9\u754c", ("\u9002\u7528", "\u4e0d\u9002\u7528", "\u8fb9\u754c", "\u4ec0\u4e48\u4eba", "\u573a\u666f")),
]

REPEATED_CONCLUSION_TERMS = (
    "\u8fb9\u754c",
    "\u9a8c\u6536",
    "\u56de\u6eda",
    "\u8bc4\u4f30",
    "\u7ea0\u9519",
    "\u8bda\u5b9e\u6c47\u62a5",
    "\u53ef\u9a8c\u8bc1",
)

FRONTSTAGE_TAKEAWAY_PRIORITY = (
    "\u529f\u80fd\u5dee\u5f02",
    "\u4f7f\u7528\u6b65\u9aa4",
    "\u98ce\u9669\u6e05\u5355",
    "\u771f\u5b9e\u6848\u4f8b",
    "\u5de5\u5177\u5bf9\u6bd4",
    "\u6210\u672c\u53d8\u5316",
    "\u5c97\u4f4d\u5f71\u54cd",
    "\u9002\u7528\u8fb9\u754c",
)

COST_SIGNAL_TERMS = (
    "\u8ba1\u8d39",
    "billing",
    "credits",
    "actions minutes",
    "\u9884\u7b97",
    "\u6210\u672c",
    "\u8d26\u5355",
    "\u7b97\u8d26",
    "\u989d\u5ea6",
    "\u5de5\u5177\u8c03\u7528",
    "max-wall-time",
    "max-tool-calls",
)

NARRATION_META_PHRASES = (
    "\u6536\u83b7\u7c7b\u578b",
    "\u770b\u5b8c\u80fd\u5e26\u8d70\u4e00\u4e2a",
    "\u753b\u9762\u91cc\u6211\u4f1a\u653e\u8fd9\u4e2a\u8bc1\u636e",
    "\u5c97\u4f4d\u5f71\u54cd\uff1a\u628a\u8fd9\u6761\u65b0\u95fb",
)


@dataclass
class Paths:
    workspace: Path
    inbox: Path
    strategy: Path
    single_root: Path


def default_paths(workspace: Path) -> Paths:
    planning_root = workspace / ZH_CONTENT_PLAN
    return Paths(
        workspace=workspace,
        inbox=planning_root / ZH_INBOX,
        strategy=planning_root / ZH_SERIES / ZH_MAINLINE / "series-strategy.md",
        single_root=planning_root / ZH_SINGLE,
    )


def find_daily_brief(inbox: Path, target_date: str) -> Path:
    today = inbox / f"{target_date}-{ZH_DAILY_BRIEF}"
    if today.exists():
        return today

    candidates = sorted(
        inbox.glob(f"*-{ZH_DAILY_BRIEF}"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    if not candidates:
        raise FileNotFoundError(f"No daily brief found under {inbox}")
    return candidates[0]


def recent_plan_names(single_root: Path, count: int = 3) -> list[str]:
    if not single_root.exists():
        return []
    dirs = [path for path in single_root.iterdir() if path.is_dir()]
    dirs.sort(key=lambda path: path.stat().st_mtime, reverse=True)
    return [path.name for path in dirs[:count]]


def recent_plan_summaries(single_root: Path, count: int = 5) -> list[str]:
    if not single_root.exists():
        return []
    dirs = [path for path in single_root.iterdir() if path.is_dir()]
    dirs.sort(key=lambda path: path.stat().st_mtime, reverse=True)
    summaries: list[str] = []
    for directory in dirs[:count]:
        plan_path = directory / "\u4f01\u5212.md"
        if not plan_path.exists():
            summaries.append(directory.name)
            continue
        text = plan_path.read_text(encoding="utf-8", errors="ignore")
        lines = text.splitlines()
        topic = first_non_empty_after_heading(lines, "\u9009\u9898\u4e00\u53e5\u8bdd")
        core = extract_section(lines, "\u6838\u5fc3\u89c2\u70b9")
        core_line = speech_clean(next((line for line in core if line.strip().startswith("- ")), ""))
        summaries.append(" | ".join(part for part in (directory.name, topic, core_line) if part))
    return summaries


def first_non_empty_after_heading(lines: list[str], heading: str) -> str:
    block = extract_section(lines, heading)
    for line in block:
        value = line.strip().strip("*").strip()
        if value:
            return value
    return ""



def heading_match(line: str, body: str) -> bool:
    return bool(
        re.match(
            r"^##\s*(?:(?:\d+[.\u3001])|(?:[一二三四五六七八九十]+[\u3001]))?\s*"
            + re.escape(body)
            + r"$",
            line.strip(),
        )
    )


def extract_section(lines: list[str], start_body: str) -> list[str]:
    start = None
    for index, line in enumerate(lines):
        if heading_match(line, start_body):
            start = index
            break
    if start is None:
        return []

    block: list[str] = []
    for line in lines[start + 1 :]:
        if line.strip().startswith("## "):
            break
        block.append(line)
    return block


def parse_topic(lines: list[str]) -> str:
    for index, line in enumerate(lines):
        trimmed = line.strip()
        for label in (
            "\u9898\u76ee\u65b9\u5411",
            "\u63a8\u8350\u9898",
            "\u63a8\u8350\u9898\u76ee",
            "\u63a8\u8350\u9009\u9898",
        ):
            if trimmed.startswith(f"**{label}"):
                bold_labeled_match = re.match(
                    r"^\*\*" + re.escape(label) + r"[:\uff1a]\s*(.+?)\*\*$",
                    trimmed,
                )
                if bold_labeled_match:
                    return bold_labeled_match.group(1).strip().strip("*").strip()
            plain_labeled_match = re.match(
                r"^" + re.escape(label) + r"[:\uff1a]\s*(.+)$",
                trimmed,
            )
            if plain_labeled_match:
                return plain_labeled_match.group(1).strip().strip("*").strip()
            if trimmed == f"### {label}":
                for candidate in lines[index + 1 :]:
                    value = candidate.strip()
                    if not value:
                        continue
                    if value.startswith("#"):
                        break
                    return value.strip("*").strip()
        heading_topic_match = re.match(r"^###\s+([^：:]+题)[:\uff1a]\s*(.+)$", trimmed)
        if heading_topic_match:
            return heading_topic_match.group(2).strip().strip("*").strip()
        recommend_match = re.match(
            r"^###\s+(?:(?:\d+\.\s*)?)("
            + re.escape(ZH_RECOMMEND)
            + r"|"
            + re.escape(ZH_TODAY_RECOMMENDATION)
            + r")(?:[:\uff1a]\s*(.+))?$",
            trimmed,
        )
        if recommend_match:
            inline_topic = (recommend_match.group(2) or "").strip().strip("*").strip()
            if inline_topic:
                return inline_topic
            for candidate in lines[index + 1 :]:
                value = candidate.strip()
                if not value:
                    continue
                if value.startswith("#"):
                    break
                return value.strip("*").strip()
    return ""


def parse_subsection_bullets(lines: list[str], heading: str) -> list[str]:
    collect = False
    items: list[str] = []
    seen: set[str] = set()
    for line in lines:
        trimmed = line.strip()
        if trimmed == heading:
            collect = True
            continue
        if collect and trimmed.startswith("### "):
            break
        if not collect:
            continue
        if re.match(r"^\s*(?:[-*]|\d+[.、])\s+", line):
            item = re.sub(r"^\s*(?:[-*]|\d+[.、])\s+", "", line).strip()
            if item and item not in seen:
                seen.add(item)
                items.append(item)
            continue
        if trimmed.startswith(">"):
            item = trimmed.lstrip(">").strip()
            if item and item not in seen:
                seen.add(item)
                items.append(item)
    return items


def has_meaningful_lines(lines: list[str]) -> bool:
    return any(line.strip() for line in lines)


_legacy_parse_subsection_bullets = parse_subsection_bullets


def parse_subsection_items(lines: list[str], heading: str) -> list[str]:
    items = _legacy_parse_subsection_bullets(lines, heading)
    if items:
        return items

    collect = False
    in_code_block = False
    paragraph_lines: list[str] = []
    fallback_items: list[str] = []

    def flush_paragraph() -> None:
        nonlocal paragraph_lines
        if not paragraph_lines:
            return
        item = " ".join(part.strip() for part in paragraph_lines if part.strip()).strip()
        paragraph_lines = []
        if item:
            fallback_items.append(item)

    for line in lines:
        trimmed = line.strip()
        if trimmed == heading:
            collect = True
            continue
        if collect and trimmed.startswith("### "):
            flush_paragraph()
            break
        if not collect:
            continue
        if trimmed.startswith("```"):
            if in_code_block:
                flush_paragraph()
                in_code_block = False
            else:
                flush_paragraph()
                in_code_block = True
            continue
        if not trimmed:
            flush_paragraph()
            continue
        paragraph_lines.append(trimmed)

    flush_paragraph()
    return fallback_items


parse_subsection_bullets = parse_subsection_items


def extract_recommended_section(lines: list[str]) -> list[str]:
    primary = extract_section(lines, ZH_RECOMMENDED_SECTION)
    if not has_meaningful_lines(primary):
        primary = extract_section(lines, ZH_RECOMMENDED_SECTION_ALT)
    if not has_meaningful_lines(primary):
        primary = extract_section(lines, ZH_TODAY_RECOMMENDATION_SECTION)
    if not has_meaningful_lines(primary):
        primary = extract_section(lines, ZH_TODAY_RECOMMENDATION)
    if not has_meaningful_lines(primary):
        primary = extract_section(lines, ZH_EVERGREEN_FALLBACK)
    if not has_meaningful_lines(primary):
        primary = extract_section(lines, ZH_EVERGREEN_FALLBACK_ALT)
    if not primary:
        return []

    for index, line in enumerate(primary):
        trimmed = line.strip()
        if re.match(
            r"^###\s+(?:\d+\.\s*)?(?:"
            + re.escape(ZH_TODAY_RECOMMENDATION)
            + "|"
            + re.escape(ZH_EVERGREEN_FALLBACK)
            + "|"
            + re.escape(ZH_EVERGREEN_FALLBACK_ALT)
            + r")$",
            trimmed,
        ):
            return primary[index + 1 :]
        if re.match(
            r"^###\s+(?:(?:\d+\.\s*)?)("
            + re.escape(ZH_RECOMMEND)
            + r"|"
            + re.escape(ZH_TODAY_RECOMMENDATION)
            + r")(?:[:\uff1a].*)?$",
            trimmed,
        ):
            return primary[index:]
    return primary


def preflight(date: str, workspace: Path) -> dict[str, object]:
    paths = default_paths(workspace)
    brief_path = find_daily_brief(paths.inbox, date)
    lines = brief_path.read_text(encoding="utf-8").splitlines()
    section = extract_recommended_section(lines)
    topic = parse_topic(section) if section else ""
    return {
        "ok": bool(section),
        "date": date,
        "brief_path": str(brief_path),
        "topic_preview": topic,
        "reason": "" if section else f"Could not find recommended section in {brief_path}",
    }





def parse_labeled_nested_bullets(lines: list[str], label: str) -> list[str]:
    items: list[str] = []
    seen: set[str] = set()
    capture = False
    normalized_label = label.rstrip("：:")
    for line in lines:
        trimmed = line.strip()
        if trimmed.startswith("- "):
            heading = re.sub(r"^-\s*", "", trimmed).strip()
            heading = heading.rstrip("：:")
            if heading == normalized_label:
                capture = True
                continue
        if not capture:
            continue
        if capture and re.match(r"^-\S", trimmed):
            break
        if capture and re.match(r"^-\s*\S.*[：:]$", trimmed):
            break
        if capture and re.match(r"^\s{2,}[-*]\s+", line):
            item = re.sub(r"^\s+[-*]\s+", "", line).strip()
            if item and item not in seen:
                seen.add(item)
                items.append(item)
    return items


def parse_labeled_field(lines: list[str], label: str) -> str:
    normalized_label = label.rstrip("\uff1a:")
    for line in lines:
        trimmed = line.strip()
        if not trimmed.startswith("- "):
            continue
        body = re.sub(r"^-\s*", "", trimmed).strip()
        if body.rstrip("\uff1a:") == normalized_label:
            continue
        for separator in ("\uff1a", ":"):
            prefix = normalized_label + separator
            if body.startswith(prefix):
                return body[len(prefix) :].strip()
    return ""


def extract_candidate_sections(lines: list[str]) -> list[list[str]]:
    sections: list[list[str]] = []
    in_candidates = False
    current: list[str] = []
    for line in lines:
        trimmed = line.strip()
        if heading_match(line, "\u5019\u9009\u9009\u9898"):
            in_candidates = True
            continue
        if in_candidates and trimmed.startswith("## "):
            break
        if not in_candidates:
            continue
        if trimmed.startswith("### \u9009\u9898 "):
            if current:
                sections.append(current)
            current = [line]
            continue
        if current:
            current.append(line)
    if current:
        sections.append(current)
    return sections


def candidate_card_title(lines: list[str]) -> str:
    for line in lines:
        trimmed = line.strip()
        if trimmed.startswith("**") and trimmed.endswith("**"):
            return trimmed.strip("*").strip()
    return ""


def candidate_heading_topic(lines: list[str]) -> str:
    if not lines:
        return ""
    match = re.match(r"^###\s*\u9009\u9898\s*\d+\s*[：:]\s*(.+)$", lines[0].strip())
    return match.group(1).strip() if match else ""


def find_candidate_section(lines: list[str], topic: str, recommended_title: str) -> list[str]:
    tokens = {token.lower() for token in re.findall(r"[A-Za-z]+", f"{topic} {recommended_title}")}
    best_section: list[str] = []
    best_score = -1
    for section in extract_candidate_sections(lines):
        title = candidate_card_title(section)
        haystack = title + "\n" + "\n".join(section)
        score = 0
        for token in tokens:
            if token and token in haystack.lower():
                score += 1
        if "Codex" in topic and "Codex" in haystack:
            score += 3
        if score > best_score:
            best_score = score
            best_section = section
    return best_section


def extract_bullets(lines: list[str]) -> list[str]:
    items: list[str] = []
    for line in lines:
        trimmed = line.strip()
        if re.match(r"^[-*]\s+", trimmed):
            items.append(re.sub(r"^[-*]\s+", "", trimmed).strip())
    return items


def speech_clean(text: str) -> str:
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"`([^`]+)`", r"\1", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"https?://\S+", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip(" ：:。")


def detect_takeaway_type(*texts: str) -> str:
    return choose_takeaway_type_with_frontstage_guard(*texts)


def build_viewer_gain(takeaway_type: str, topic: str, core_viewpoints: list[str], reason_bullets: list[str]) -> str:
    combined = "\n".join([topic, *core_viewpoints, *reason_bullets]).lower()
    if takeaway_type == "\u6210\u672c\u53d8\u5316" and (
        "agent" in combined or "\u9884\u7b97" in combined or "billing" in combined
    ):
        return "\u770b\u5b8c\u80fd\u5e26\u8d70\u4e00\u5f20\u300cAgent \u4efb\u52a1\u9884\u7b97\u5361\u300d\uff1a\u76ee\u6807\u3001\u8303\u56f4\u3001\u65f6\u95f4\u3001\u5de5\u5177\u8c03\u7528\u3001\u82b1\u8d39\u3001\u9a8c\u6536\u3001\u505c\u6b62\u6761\u4ef6"

    if takeaway_type == "\u6210\u672c\u53d8\u5316" and ("Agent" in clean_topic or "agent" in clean_topic.lower()):
        narration_lines = [
            "\u4eca\u5929\u5f00\u59cb\uff0cAI Agent \u4e0d\u80fd\u518d\u53ea\u6309\u201c\u80fd\u4e0d\u80fd\u5e72\u6d3b\u201d\u6765\u5224\u65ad\u4e86\u3002",
            "GitHub Copilot \u7684\u65b0\u8ba1\u8d39\u4eca\u5929\u751f\u6548\uff0cAI code review \u4f1a\u6d88\u8017 AI Credits\uff0c\u79c1\u6709\u4ed3\u5e93\u8fd8\u4f1a\u5403 Actions minutes\u3002",
            "\u8fd9\u4ef6\u4e8b\u771f\u6b63\u63d0\u9192\u666e\u901a\u4eba\u7684\u662f\uff1a\u4ee5\u540e\u8ba9 Codex\u3001Copilot\u3001Qwen Code \u81ea\u52a8\u8dd1\u4efb\u52a1\uff0c\u5148\u522b\u53ea\u5199\u201c\u5e2e\u6211\u4f18\u5316\u4e00\u4e0b\u201d\u3002",
            "\u4f60\u8981\u5148\u5199\u4e00\u5f20 Agent \u4efb\u52a1\u9884\u7b97\u5361\u3002",
            "\u7b2c\u4e00\uff0c\u76ee\u6807\u662f\u4ec0\u4e48\uff0c\u53ea\u505a\u54ea\u4e00\u4ef6\u4e8b\u3002",
            "\u7b2c\u4e8c\uff0c\u5141\u8bb8\u52a8\u54ea\u4e9b\u6587\u4ef6\uff0c\u6700\u591a\u8dd1\u591a\u4e45\u3002",
            "\u7b2c\u4e09\uff0c\u6700\u591a\u8c03\u7528\u591a\u5c11\u5de5\u5177\uff0c\u6700\u591a\u82b1\u591a\u5c11\u989d\u5ea6\u3002",
            "\u7b2c\u56db\uff0c\u5fc5\u987b\u4ea4\u4ed8\u4ec0\u4e48\u7ed3\u679c\uff0c\u9047\u5230\u4ec0\u4e48\u60c5\u51b5\u7acb\u523b\u505c\u3002",
            "\u5426\u5219 AI \u4e0d\u662f\u5e2e\u4f60\u7701\u65f6\u95f4\uff0c\u800c\u662f\u5728\u4f60\u7761\u89c9\u7684\u65f6\u5019\u66ff\u4f60\u5237\u8d26\u5355\u3002",
            "\u6240\u4ee5\u4eca\u5929\u8fd9\u6761\u65b0\u95fb\uff0c\u6211\u4e0d\u5efa\u8bae\u5f53 GitHub \u8ba1\u8d39\u65b0\u95fb\u770b\u3002",
            "\u5b83\u771f\u6b63\u7684\u4ef7\u503c\u662f\u63d0\u9192\u6211\u4eec\uff1aAI \u5458\u5de5\u4e5f\u8981\u6709\u9884\u7b97\u3001\u6709\u505c\u6b62\u6761\u4ef6\u3001\u6709\u9a8c\u6536\u7ed3\u679c\u3002",
        ]
    elif takeaway_type == "\u4f7f\u7528\u6b65\u9aa4" and len(core_viewpoints) >= 3:
        step_names = []
        for item in core_viewpoints[:4]:
            clean = speech_clean(item)
            step_names.append(re.split(r"[:\uff1a]", clean, maxsplit=1)[0].strip() or clean)
        steps = " -> ".join(step_names)
        return f"\u770b\u5b8c\u80fd\u5e26\u8d70\u4e00\u4e2a\u300c{takeaway_type}\u300d\uff1a{steps}"
    clean_core = speech_clean(core_viewpoints[0]) if core_viewpoints else ""
    if clean_core and "\u9700\u8981\u5728\u4eca\u5929\u8865\u5145" not in clean_core:
        return f"\u770b\u5b8c\u80fd\u5e26\u8d70\u4e00\u4e2a\u300c{takeaway_type}\u300d\uff1a{clean_core}"
    clean_reason = ""
    for reason in reason_bullets:
        candidate = speech_clean(reason)
        if candidate and not looks_like_source_note(candidate):
            clean_reason = candidate
            break
    if clean_reason:
        return f"\u770b\u5b8c\u80fd\u5e26\u8d70\u4e00\u4e2a\u300c{takeaway_type}\u300d\uff1a{clean_reason}"
    return f"\u770b\u5b8c\u5e94\u8be5\u80fd\u56de\u7b54\uff1a{speech_clean(topic)}\u5230\u5e95\u5bf9\u6211\u6709\u4ec0\u4e48\u7528\u3002"


def looks_like_source_note(text: str) -> bool:
    source_markers = ("http", "OpenAI\uff1a", "Anthropic\uff1a", "xAI\uff1a", "\u4e3b\u4e8b\u5b9e\u6e90", "\u4f5c\u4e3a", "\u622a\u53d6")
    return any(marker in text for marker in source_markers)


def build_traffic_hook(takeaway_type: str, topic: str, recommended_title: str) -> str:
    text = speech_clean(recommended_title or topic)
    if takeaway_type == "\u6210\u672c\u53d8\u5316":
        return f"\u628a\u300c\u5927\u516c\u53f8\u65b0\u95fb\u300d\u7ffb\u6210\u666e\u901a\u4eba\u5173\u5fc3\u7684\u4ef7\u683c\u3001\u989d\u5ea6\u548c\u4f7f\u7528\u95e8\u69db\uff1a{text}"
    if takeaway_type == "\u5c97\u4f4d\u5f71\u54cd":
        return f"\u7528\u300c\u8c01\u7684\u5de5\u4f5c\u4f1a\u5148\u53d8\u300d\u5f00\u573a\uff0c\u628a\u65b0\u95fb\u843d\u5230\u5c97\u4f4d\u548c\u5de5\u4f5c\u573a\u666f\uff1a{text}"
    if takeaway_type == "\u98ce\u9669\u6e05\u5355":
        return f"\u7528\u300c\u522b\u5148\u8ddf\uff0c\u5148\u770b\u8fd9\u51e0\u4e2a\u5751\u300d\u5f00\u573a\uff0c\u8ba9\u89c2\u4f17\u7acb\u523b\u77e5\u9053\u8fd9\u6761\u548c\u81ea\u5df1\u6709\u5173\uff1a{text}"
    if takeaway_type == "\u4f7f\u7528\u6b65\u9aa4":
        return f"\u7528\u300c\u7167\u7740\u8fd9\u51e0\u6b65\u8bd5\u300d\u5f00\u573a\uff0c\u628a\u70ed\u70b9\u53d8\u6210\u53ef\u6267\u884c\u7684\u5c0f\u4efb\u52a1\uff1a{text}"
    return f"\u5f00\u5934\u8981\u5148\u7ed9\u51b2\u7a81\u6216\u5229\u76ca\uff0c\u4e0d\u8981\u5148\u89e3\u91ca\u80cc\u666f\uff1a{text}"


def build_correlation(event_fact: str, viewer_gain: str, topic: str) -> str:
    event = speech_clean(event_fact) or speech_clean(topic)
    gain = speech_clean(viewer_gain)
    return f"\u70ed\u70b9\u4e8b\u5b9e\u662f\u300c{event}\u300d\uff1b\u89c2\u4f17\u6536\u83b7\u5fc5\u987b\u76f4\u63a5\u4ece\u8fd9\u4e2a\u4e8b\u5b9e\u63a8\u51fa\uff1a{gain}"


def repeated_conclusion_score(*texts: str) -> int:
    haystack = "\n".join(texts)
    return sum(1 for term in REPEATED_CONCLUSION_TERMS if term in haystack)


def is_repeated_conclusion_bucket(*texts: str) -> bool:
    return repeated_conclusion_score(*texts) >= 2


def choose_takeaway_type_with_frontstage_guard(*texts: str) -> str:
    haystack = "\n".join(texts)
    lowered = haystack.lower()
    if any(term in lowered for term in COST_SIGNAL_TERMS):
        return "\u6210\u672c\u53d8\u5316"

    score_map: dict[str, int] = {}
    for name, keywords in TAKEAWAY_TYPES:
        score_map[name] = sum(1 for keyword in keywords if keyword and keyword.lower() in haystack.lower())

    if is_repeated_conclusion_bucket(haystack):
        for takeaway_type in FRONTSTAGE_TAKEAWAY_PRIORITY:
            if score_map.get(takeaway_type, 0) > 0:
                return takeaway_type

    ranked = sorted(((score, name) for name, score in score_map.items()), reverse=True)
    return ranked[0][1] if ranked and ranked[0][0] > 0 else "\u4fe1\u606f\u5224\u65ad"


def build_repeat_action(
    *,
    repetition_risk: bool,
    repeated_score: int,
    takeaway_type: str,
    recent_summaries: list[str],
) -> str:
    if repetition_risk or repeated_score >= 3:
        return (
            "\u4e0d\u5efa\u8bae\u6309\u5f53\u524d\u89d2\u5ea6\u76f4\u63a5\u5f00\u62cd\u3002"
            f"\u8fd9\u6761\u5fc5\u987b\u6539\u6210\u4e00\u4e2a\u66f4\u524d\u53f0\u7684\u300c{takeaway_type}\u300d\uff0c"
            "\u7528\u529f\u80fd\u5dee\u5f02\u3001\u4f7f\u7528\u6b65\u9aa4\u3001\u6210\u672c\u53d8\u5316\u3001\u5c97\u4f4d\u5f71\u54cd\u6216\u98ce\u9669\u6e05\u5355\u6765\u627f\u8f7d\uff0c"
            "\u4e0d\u8981\u518d\u628a\u300c\u9a8c\u6536 / \u8fb9\u754c / \u56de\u6eda\u300d\u5f53\u6210\u53f0\u524d\u7ed3\u8bba\u3002"
        )
    if recent_summaries:
        return "\u53ef\u4ee5\u7ee7\u7eed\uff0c\u4f46\u6807\u9898\u548c\u5f00\u5934\u8981\u5148\u7ed9\u89c2\u4f17\u6536\u83b7\uff0c\u518d\u4ea4\u4ee3\u70ed\u70b9\u6765\u6e90\u3002"
    return "\u53ef\u4ee5\u7ee7\u7eed\uff0c\u4f46\u4ecd\u9700\u5728\u5f00\u62cd\u524d\u786e\u8ba4\u5b83\u4e0d\u662f\u7eaf\u65b0\u95fb\u590d\u8ff0\u3002"


def build_frontstage_core_viewpoints(
    takeaway_type: str,
    topic: str,
    event_fact: str,
    reason_bullets: list[str],
    risk_note: str,
) -> list[str]:
    clean_topic = speech_clean(topic)
    clean_fact = speech_clean(event_fact)
    clean_reason = first_clean_reason(reason_bullets, clean_topic)
    clean_risk = speech_clean(risk_note)

    if takeaway_type == "\u529f\u80fd\u5dee\u5f02":
        return [
            f"\u65b0\u53d8\u5316\u4e0d\u662f\u6a21\u578b\u540d\u5b57\uff0c\u800c\u662f\uff1a{clean_fact or clean_topic}",
            "\u548c\u65e7\u7528\u6cd5\u7684\u5dee\u522b\u5728\u4e8e\uff0c\u5b83\u5f00\u59cb\u4ece\u201c\u7ed9\u5efa\u8bae\u201d\u8d70\u5411\u201c\u78b0\u771f\u5b9e\u684c\u9762\u4efb\u52a1\u201d\u3002",
            f"\u666e\u901a\u4eba\u6700\u5148\u8be5\u5173\u5fc3\u7684\u4e0d\u662f\u9177\u70ab\uff0c\u800c\u662f\uff1a{clean_reason}",
        ]
    if takeaway_type == "\u4f7f\u7528\u6b65\u9aa4":
        return [
            "\u7b2c\u4e00\u6b65\uff0c\u5148\u786e\u8ba4\u8fd9\u4e2a\u529f\u80fd\u5bf9\u4f60\u7684\u8d26\u53f7\u3001\u7cfb\u7edf\u548c\u573a\u666f\u662f\u771f\u53ef\u7528\u7684\u3002",
            f"\u7b2c\u4e8c\u6b65\uff0c\u5148\u6311\u4e00\u4e2a\u4f4e\u98ce\u9669\u3001\u53ef\u89c1\u7ed3\u679c\u7684\u5c0f\u4efb\u52a1\u53bb\u8bd5\uff1a{clean_reason}",
            "\u7b2c\u4e09\u6b65\uff0c\u4e00\u5b9a\u8981\u7559\u4e0b\u53ef\u68c0\u67e5\u7684\u8bc1\u636e\uff1a\u6539\u4e86\u4ec0\u4e48\u3001\u8dd1\u4e86\u4ec0\u4e48\u3001\u7ed3\u679c\u662f\u5426\u901a\u8fc7\u3002",
        ]
    if takeaway_type == "\u98ce\u9669\u6e05\u5355":
        return [
            "\u7b2c\u4e00\u4e2a\u5751\uff1a\u628a\u53d1\u5e03\u80fd\u529b\u8bef\u4ee5\u4e3a\u662f\u81ea\u5df1\u73b0\u5728\u5c31\u80fd\u7528\u7684\u80fd\u529b\u3002",
            f"\u7b2c\u4e8c\u4e2a\u5751\uff1a{clean_risk or clean_reason}",
            "\u7b2c\u4e09\u4e2a\u5751\uff1a\u8fd8\u6ca1\u6709\u4f4e\u98ce\u9669\u6f14\u793a\u548c\u53ef\u68c0\u67e5\u8bc1\u636e\uff0c\u5c31\u76f4\u63a5\u8bb2\u6210\u201c\u5b83\u4f1a\u63a5\u7ba1\u4f60\u7684\u7535\u8111\u201d\u3002",
        ]
    if takeaway_type == "\u5c97\u4f4d\u5f71\u54cd":
        return [
            f"\u771f\u6b63\u53d7\u5f71\u54cd\u7684\u4e0d\u662f\u201c\u4f1a\u4e0d\u4f1a\u5199\u63d0\u793a\u8bcd\u201d\uff0c\u800c\u662f\u8c01\u80fd\u628a AI \u63a5\u8fdb\u771f\u5b9e\u5de5\u4f5c\u52a8\u4f5c\u3002",
            f"\u8fd9\u6761\u70ed\u70b9\u5bf9\u666e\u901a\u4eba\u6700\u73b0\u5b9e\u7684\u4ef7\u503c\u662f\uff1a{clean_reason}",
            "\u5148\u4f1a\u53d8\u7684\u662f\u90a3\u4e9b\u91cd\u590d\u64cd\u4f5c\u3001\u53ef\u62c6\u6210\u5c0f\u5de5\u5355\u3001\u53ef\u68c0\u67e5\u7ed3\u679c\u7684\u684c\u9762\u5de5\u4f5c\u3002",
        ]
    if takeaway_type == "\u6210\u672c\u53d8\u5316":
        return [
            "\u771f\u6b63\u7684\u53d8\u5316\u4e0d\u662f Agent \u66f4\u4f1a\u5e72\u6d3b\uff0c\u800c\u662f Agent \u5f00\u59cb\u6709\u4e86\u6bcf\u6b21\u4efb\u52a1\u7684\u6210\u672c\u5355\u4f4d\u3002",
            "\u666e\u901a\u4eba\u4e0d\u80fd\u53ea\u5199\u201c\u5e2e\u6211\u4f18\u5316\u9879\u76ee\u201d\uff0c\u800c\u8981\u5199\u6e05\u76ee\u6807\u3001\u8303\u56f4\u3001\u65f6\u95f4\u3001\u5de5\u5177\u8c03\u7528\u548c\u505c\u6b62\u6761\u4ef6\u3002",
            "\u4eca\u5929\u7684\u89c2\u4f17\u4ea4\u4ed8\u7269\u4e0d\u662f\u4e00\u53e5\u6001\u5ea6\uff0c\u800c\u662f\u4e00\u5f20\u53ef\u76f4\u63a5\u590d\u7528\u7684 Agent \u4efb\u52a1\u9884\u7b97\u5361\u3002",
        ]
    return [
        f"\u4eca\u5929\u771f\u6b63\u7684\u65b0\u4fe1\u606f\u662f\uff1a{clean_fact or clean_topic}",
        f"\u5b83\u4e0d\u8be5\u505c\u5728\u65b0\u95fb\u5c42\uff0c\u800c\u8981\u843d\u5230\u89c2\u4f17\u80fd\u5e26\u8d70\u7684\u4e1c\u897f\uff1a{clean_reason}",
        "\u8fd9\u6761\u7684\u53f0\u524d\u7ed3\u679c\u5fc5\u987b\u662f\u529f\u80fd\u5dee\u522b\u3001\u6b65\u9aa4\u3001\u6848\u4f8b\u6216\u98ce\u9669\uff0c\u4e0d\u662f\u62bd\u8c61\u65b9\u6cd5\u8bba\u3002",
    ]


def build_frontstage_opening_direction(takeaway_type: str, event_fact: str, topic: str) -> list[str]:
    clean_fact = speech_clean(event_fact) or speech_clean(topic)
    if takeaway_type == "\u529f\u80fd\u5dee\u5f02":
        return [
            f"\u5f00\u573a\u5148\u7ed9\u8fd9\u4e2a\u5177\u4f53\u65b0\u53d8\u5316\uff1a{clean_fact}",
            "\u7b2c\u4e00\u53e5\u5148\u8bf4\u5b83\u6bd4\u4e4b\u524d\u591a\u4e86\u4ec0\u4e48\u52a8\u4f5c\uff0c\u4e0d\u5148\u8bb2\u65b9\u6cd5\u8bba\u3002",
        ]
    if takeaway_type == "\u4f7f\u7528\u6b65\u9aa4":
        return [
            "\u5f00\u573a\u5148\u629b\u201c\u6211\u4eca\u5929\u51c6\u5907\u600e\u4e48\u8bd5\u201d\uff0c\u76f4\u63a5\u8fdb\u5c0f\u6b65\u9aa4\u3002",
            f"\u7528\u5177\u4f53\u65b0\u529f\u80fd\u5f15\u51fa\uff1a{clean_fact}",
        ]
    if takeaway_type == "\u98ce\u9669\u6e05\u5355":
        return [
            "\u5f00\u573a\u5148\u8bf4\u201c\u522b\u5148\u8ddf\uff0c\u5148\u770b\u8fd9\u4e09\u4e2a\u5751\u201d\u3002",
            f"\u7136\u540e\u518d\u8865\u4e00\u53e5\u65b0\u4e8b\u5b9e\uff1a{clean_fact}",
        ]
    if takeaway_type == "\u6210\u672c\u53d8\u5316":
        return [
            "\u5f00\u573a\u5148\u7ed9\u51fa\u51b2\u7a81\uff1aAI Agent \u4ee5\u540e\u4e0d\u662f\u514d\u8d39\u52b3\u52a8\u529b\uff0c\u800c\u662f\u4f1a\u8dd1\u51fa\u4e00\u5f20\u8d26\u5355\u3002",
            "\u524d 3 \u79d2\u7528\u300c\u65e0\u9884\u7b97\u4efb\u52a1\u300d\u5bf9\u6bd4\u300cAgent \u4efb\u52a1\u9884\u7b97\u5361\u300d\uff0c\u4e0d\u8981\u5148\u653e\u9759\u6001\u6807\u9898\u5361\u3002",
        ]
    return [
        "\u5f00\u5934 3 \u79d2\u5fc5\u987b\u5148\u4e0a\u771f\u5b9e\u52a8\u4f5c\u6216\u7ed3\u679c\u3002",
        f"\u7b2c\u4e00\u53e5\u5148\u8bf4\u89c2\u4f17\u4eca\u5929\u80fd\u5e26\u8d70\u4ec0\u4e48\uff0c\u80cc\u666f\u4ece {clean_fact} \u518d\u8ddf\u4e0a\u3002",
    ]


def build_candidate_profile(section: list[str], current_topic: str) -> dict[str, object]:
    topic = candidate_heading_topic(section) or candidate_card_title(section)
    event_fact = parse_labeled_field(section, ZH_EVENT_FACT)
    reason_bullets = [
        *parse_labeled_nested_bullets(section, "为什么值得普通人关注："),
        *parse_labeled_nested_bullets(section, "与本账号连接点："),
    ]
    for field_label in (
        "\u4e3a\u4ec0\u4e48\u503c\u5f97\u666e\u901a\u4eba\u5173\u6ce8\uff1a",
        "\u4e0e\u672c\u8d26\u53f7\u7684\u8fde\u63a5\u70b9\uff1a",
    ):
        field_value = parse_labeled_field(section, field_label)
        if field_value:
            reason_bullets.append(field_value)
    asset_checklist = parse_labeled_nested_bullets(section, "\u53ef\u7528\u89c6\u9891\u7d20\u6750\u65b9\u5411\uff1a")
    asset_field = parse_labeled_field(section, "\u53ef\u7528\u89c6\u9891\u7d20\u6750\u65b9\u5411\uff1a")
    if asset_field:
        asset_checklist.insert(0, asset_field)
    risk_note = parse_labeled_field(section, "\u98ce\u9669\u6216\u4e0d\u9002\u5408\u70b9\uff1a")
    combined_text = "\n".join([topic, event_fact, *reason_bullets, *asset_checklist, risk_note])
    takeaway_type = choose_takeaway_type_with_frontstage_guard(combined_text)
    repeated_score = repeated_conclusion_score(topic, event_fact, "\n".join(reason_bullets))
    current_tokens = {token.lower() for token in re.findall(r"[A-Za-z][A-Za-z0-9.+-]*", current_topic)}
    shared_tokens = {
        token for token in current_tokens
        if token in (topic + "\n" + event_fact).lower()
    }
    freshness_score = 0
    if topic and topic != current_topic:
        freshness_score += 2
    if takeaway_type in FRONTSTAGE_TAKEAWAY_PRIORITY[:6]:
        freshness_score += 3
    freshness_score += min(len(reason_bullets), 3)
    freshness_score += min(len(asset_checklist), 2)
    freshness_score += len(shared_tokens) * 2
    freshness_score -= repeated_score * 3
    if "Codex" in current_topic and "Codex" in topic:
        freshness_score += 2
    return {
        "topic": topic,
        "event_fact": event_fact,
        "reason_bullets": reason_bullets[:4],
        "asset_checklist": asset_checklist,
        "risk_note": risk_note,
        "takeaway_type": takeaway_type,
        "repeated_score": repeated_score,
        "freshness_score": freshness_score,
    }


def choose_better_candidate(
    lines: list[str],
    current_topic: str,
) -> dict[str, object] | None:
    profiles = [build_candidate_profile(section, current_topic) for section in extract_candidate_sections(lines)]
    profiles = [profile for profile in profiles if profile.get("topic")]
    if not profiles:
        return None
    profiles.sort(key=lambda profile: int(profile["freshness_score"]), reverse=True)
    best = profiles[0]
    return best if int(best["freshness_score"]) > 0 else None


def demand_type_from_takeaway(takeaway_type: str) -> str:
    mapping = {
        "\u529f\u80fd\u5dee\u5f02": "\u4fe1\u606f\u5dee\u5f02 / \u9009\u62e9\u5224\u65ad",
        "\u4f7f\u7528\u6b65\u9aa4": "\u5b9e\u7528\u9700\u6c42",
        "\u6210\u672c\u53d8\u5316": "\u6210\u672c / \u95e8\u69db\u9700\u6c42",
        "\u5c97\u4f4d\u5f71\u54cd": "\u5c97\u4f4d / \u804c\u4e1a\u5b89\u5168\u9700\u6c42",
        "\u98ce\u9669\u6e05\u5355": "\u98ce\u9669\u964d\u4f4e\u9700\u6c42",
        "\u771f\u5b9e\u6848\u4f8b": "\u6848\u4f8b\u590d\u5236 / \u51b3\u7b56\u652f\u6301",
        "\u5de5\u5177\u5bf9\u6bd4": "\u9009\u578b\u51b3\u7b56\u9700\u6c42",
        "\u9002\u7528\u8fb9\u754c": "\u51b3\u7b56\u652f\u6301 / \u907f\u5751\u9700\u6c42",
    }
    return mapping.get(takeaway_type, "\u4fe1\u606f\u5224\u65ad\u9700\u6c42")


def build_angle_candidates(topic: str, recommended_title: str, backup_titles: list[str], takeaway_type: str) -> list[str]:
    candidates = [recommended_title, *backup_titles]
    defaults = [
        "\u4f7f\u7528\u6b65\u9aa4\uff1a\u628a\u5b83\u62c6\u6210\u4eca\u5929\u5c31\u80fd\u7167\u7740\u8bd5\u7684 3-4 \u6b65",
        "\u98ce\u9669\u6e05\u5355\uff1a\u5b83\u6700\u5bb9\u6613\u8ba9\u666e\u901a\u4eba\u8bef\u5224\u7684 3 \u4e2a\u5751",
        f"\u6848\u4f8b\u62c6\u89e3\uff1a\u8fd9\u4e2a\u70ed\u70b9\u80fd\u6284\u7684\u662f\u54ea\u4e2a\u673a\u5236\uff0c\u4e0d\u662f\u54ea\u4e2a\u7ed3\u8bba\uff1f",
        f"\u51b3\u7b56\u5224\u65ad\uff1a\u8c01\u5e94\u8be5\u8ddf\uff0c\u8c01\u5e94\u8be5\u5148\u89c2\u671b\uff1f",
        f"\u5bf9\u6bd4\u89d2\u5ea6\uff1a\u5b83\u548c\u6700\u8fd1\u7684 AI \u5de5\u5177 / \u6848\u4f8b\u5dee\u5f02\u5728\u54ea\uff1f",
    ]
    if takeaway_type != "\u4f7f\u7528\u6b65\u9aa4":
        defaults.insert(0, f"{takeaway_type}\uff1a\u628a\u8fd9\u6761\u65b0\u95fb\u6539\u6210\u4e00\u4e2a\u89c2\u4f17\u53ef\u4ee5\u5e26\u8d70\u7684\u300c{takeaway_type}\u300d")
    for item in defaults:
        if item not in candidates:
            candidates.append(item)
    return [speech_clean(item) for item in candidates if speech_clean(item)][:5]


def build_hotspot_extraction_package(
    *,
    topic: str,
    recommended_title: str,
    backup_titles: list[str],
    event_fact: str,
    takeaway_type: str,
    viewer_gain: str,
    traffic_hook: str,
    asset_checklist: list[str],
    repeat_action: str,
) -> str:
    fact = speech_clean(event_fact) or speech_clean(topic)
    evidence = asset_checklist[:5] if asset_checklist else ["\u5fc5\u987b\u8865\u5145\u5b98\u65b9\u9875\u3001\u5b9e\u6d4b\u7ed3\u679c\u3001\u8bc4\u8bba\u6216\u6848\u4f8b\u8bc1\u636e\uff0c\u5426\u5219\u4e0d\u8fdb\u5165\u4e3b\u7ebf\u751f\u4ea7\u3002"]
    angles = build_angle_candidates(topic, recommended_title, backup_titles, takeaway_type)
    return "\n".join(
        [
            f"- \u70ed\u70b9\u4e8b\u5b9e\uff1a{fact}",
            f"- \u9700\u6c42\u4fe1\u53f7\uff1a{traffic_hook}",
            "- \u53d7\u4f17\u5206\u5c42\uff1a\u4f18\u5148\u9762\u5411\u5df2\u7ecf\u5728\u7528 AI \u505a\u5185\u5bb9\u3001\u5de5\u4f5c\u6216\u5c0f\u751f\u610f\u7684\u666e\u901a\u4eba\uff0c\u800c\u4e0d\u662f\u53ea\u9762\u5411\u6a21\u578b\u53d1\u70e7\u53cb\u3002",
            f"- \u9700\u6c42\u7c7b\u578b\uff1a{demand_type_from_takeaway(takeaway_type)}",
            f"- \u89c2\u4f17\u4ea4\u4ed8\uff1a{viewer_gain}",
            "- \u89d2\u5ea6\u5019\u9009\uff1a",
            *[f"  - {angle}" for angle in angles],
            "- \u8bc1\u636e\u6e05\u5355\uff1a",
            *[f"  - {item}" for item in evidence],
            f"- \u91cd\u590d\u98ce\u9669\uff1a{repeat_action}",
        ]
    )


def build_traffic_titles(topic: str, takeaway_type: str, backup_titles: list[str]) -> list[str]:
    base = [title for title in backup_titles if title]
    def add_generated(title: str) -> None:
        if base:
            base.append(title)
        else:
            base.insert(0, title)

    if takeaway_type == "\u98ce\u9669\u6e05\u5355":
        add_generated("\u522b\u5148\u8ddf\u8fd9\u4e2a AI \u70ed\u70b9\uff0c\u5148\u770b\u5b83\u6700\u5bb9\u6613\u5751\u666e\u901a\u4eba\u7684\u5730\u65b9")
    elif takeaway_type == "\u4f7f\u7528\u6b65\u9aa4":
        if "OpenAI" in topic and "Tax AI" in topic:
            add_generated("OpenAI \u8fd9\u4e2a Tax AI \u6848\u4f8b\u600e\u4e48\u7528\uff1f\u6211\u628a\u5b83\u62c6\u6210 4 \u6b65")
        elif "\u8bb0\u5fc6" in topic:
            pass
        else:
            add_generated("\u8fd9\u4e2a AI \u65b0\u4e1c\u897f\u5230\u5e95\u600e\u4e48\u7528\uff1f\u6211\u628a\u6b65\u9aa4\u62c6\u51fa\u6765\u4e86")
    elif takeaway_type == "\u5c97\u4f4d\u5f71\u54cd":
        add_generated("\u8fd9\u4e2a AI \u65b0\u95fb\u6700\u8be5\u7d27\u5f20\u7684\uff0c\u4e0d\u662f\u7a0b\u5e8f\u5458")
    elif takeaway_type == "\u6210\u672c\u53d8\u5316":
        if "Agent" in topic or "agent" in topic.lower():
            add_generated("AI Agent \u4ece\u4eca\u5929\u5f00\u59cb\u8981\u7b97\u8d26\u4e86")
        else:
            add_generated("\u8fd9\u4e2a AI \u65b0\u95fb\u7684\u771f\u95ee\u9898\uff1a\u666e\u901a\u4eba\u4f1a\u4e0d\u4f1a\u53d8\u5f97\u66f4\u8d35")
    else:
        add_generated(speech_clean(topic))
    deduped: list[str] = []
    for title in base:
        title = title.strip()
        if title and title not in deduped:
            deduped.append(title)
    return deduped[:4]


def first_clean_reason(reason_bullets: list[str], fallback: str) -> str:
    for reason in reason_bullets:
        candidate = speech_clean(reason)
        if candidate and not looks_like_source_note(candidate):
            return candidate
    return fallback


def first_clean_asset(asset_checklist: list[str], fallback: str) -> str:
    for asset in asset_checklist:
        candidate = speech_clean(asset)
        if candidate and not looks_like_source_note(candidate):
            return candidate
    return fallback


def slugify(text: str) -> str:
    mapping = [
        ("Google", "google"),
        ("Gemini", "gemini"),
        ("Cursor", "cursor"),
        ("OpenAI", "openai"),
        ("Anthropic", "anthropic"),
        ("MiniMax", "minimax"),
        ("Codex", "codex"),
        ("AI", "ai"),
        ("proof", "proof"),
        ("workflow", "workflow"),
        ("agent", "agent"),
        ("agents", "agents"),
        ("product", "product"),
    ]
    tokens: list[str] = []
    normalized_text = text.lower()
    for source, target in mapping:
        if source.lower() in normalized_text and target not in tokens:
            tokens.append(target)
    return "-".join(tokens) if tokens else "mainline-topic"


def bullets(items: list[str], fallback: str) -> str:
    source = items if items else [fallback]
    return "\n".join(f"- {item}" for item in source)


def build_decision_content(
    *,
    date: str,
    brief_path: Path,
    strategy_path: Path,
    topic: str,
    recommended_title: str,
    backup_titles: list[str],
    reason_bullets: list[str],
    asset_checklist: list[str],
    opening_direction: list[str],
    recent_plans: list[str],
    repetition_risk: bool,
    takeaway_type: str,
    viewer_gain: str,
    traffic_hook: str,
    correlation: str,
    hotspot_package: str,
    repeat_action: str,
    recent_summaries: list[str],
    plan_directory: Path,
) -> str:
    fallback_reason = "这条更符合主线“热点实操验证”的表达方式。"
    fallback_evidence = "需要补充今天的录屏与证据画面。"
    fallback_opening = "先上真实动作或结果，不要静态标题卡。"
    recent_text = " / ".join(recent_plans) if recent_plans else "暂无最近单条企划记录"
    repeat_text = "是，发布前需再人工确认。" if repetition_risk else "否。"

    return "\n".join(
        [
            f"# {date} 主线选题决策",
            "",
            "## 上游输入",
            "",
            f"- 日报文件：`{brief_path}`",
            f"- 主线策略：`{strategy_path}`",
            "",
            "## 今日主线推荐",
            "",
            topic,
            "",
            "## 流量与观众收获闸门",
            "",
            f"- 观众收益类型：{takeaway_type}",
            f"- 看完能带走什么：{viewer_gain}",
            f"- 流量钩子：{traffic_hook}",
            "",
            "## 热点和结论相关性",
            "",
            f"- {correlation}",
            "",
            "## 热点拆解包",
            "",
            hotspot_package,
            "",
            "## 推荐标题",
            "",
            recommended_title,
            "",
            "## 备选标题",
            "",
            bullets(backup_titles, topic),
            "",
            "## 为什么今天选这条",
            "",
            bullets(reason_bullets, fallback_reason),
            "",
            "## 今日可拍证据",
            "",
            bullets(asset_checklist, fallback_evidence),
            "",
            "## 开头 3 秒方向",
            "",
            bullets(opening_direction, fallback_opening),
            "",
            "## 重复风险检查",
            "",
            f"- 最近 3 条单条企划：{recent_text}",
            f"- 是否疑似撞题：{repeat_text}",
            f"- 处置：{repeat_action}",
            "",
            "## 最近结论对照",
            "",
            bullets(recent_summaries, "暂无最近结论对照。"),
            "",
            "## 自动创建的单条企划目录",
            "",
            f"`{plan_directory}`",
            "",
        ]
    )


def build_plan_files(
    *,
    date: str,
    topic: str,
    recommended_title: str,
    backup_titles: list[str],
    core_viewpoints: list[str],
    opening_direction: list[str],
    asset_checklist: list[str],
    reason_bullets: list[str],
    takeaway_type: str,
    viewer_gain: str,
    traffic_hook: str,
    correlation: str,
    repeat_action: str,
    decision_path: Path,
    brief_path: Path,
) -> tuple[str, str, str, str]:
    fallback_reason = "这条最符合今天主线的表达任务。"
    fallback_opening = "开头 3 秒必须先上真实动作或结果。"
    fallback_core = "需要在今天补充更具体的核心观点。"
    fallback_asset = "需要补录今天主线对应的证据画面。"

    backup_text = bullets(backup_titles, topic)
    reason_text = bullets(reason_bullets, fallback_reason)
    opening_text = bullets(opening_direction, fallback_opening)
    core_text = bullets(core_viewpoints, fallback_core)
    asset_text = bullets(asset_checklist, fallback_asset)
    clean_topic = speech_clean(topic)
    clean_title = speech_clean(recommended_title)
    primary_core = speech_clean(core_viewpoints[0]) if core_viewpoints else ""
    if not primary_core or primary_core == clean_topic or primary_core == clean_title:
        primary_core = "真正要看的不是模型名字更大，而是它有没有把长任务拆开、执行、验收和诚实汇报的能力"
    primary_reason = first_clean_reason(reason_bullets, "它不是单纯的新闻，而是普通人判断 AI 工具价值的一个样本")
    second_reason = first_clean_reason(reason_bullets[1:], "我们要看它能不能落到真实使用，而不是只停留在发布会和参数表")
    first_asset = first_clean_asset(asset_checklist, "官方页面、产品演示和真实使用画面")
    final_conclusion = speech_clean(viewer_gain)
    if takeaway_type == "\u6210\u672c\u53d8\u5316" and ("Agent" in clean_topic or "agent" in clean_topic.lower()):
        narration_lines = [
            "今天开始，AI Agent 不能再只按“能不能干活”来判断了。",
            "GitHub Copilot 的新计费今天生效，AI code review 会消耗 AI Credits，私有仓库还会吃 Actions minutes。",
            "这件事真正提醒普通人的是：以后让 Codex、Copilot、Qwen Code 自动跑任务，先别只写“帮我优化一下”。",
            "你要先写一张 Agent 任务预算卡。",
            "第一，目标是什么，只做哪一件事。",
            "第二，允许动哪些文件，最多跑多久。",
            "第三，最多调用多少工具，最多花多少额度。",
            "第四，必须交付什么结果，遇到什么情况立刻停。",
            "否则 AI 不是帮你省时间，而是在你睡觉的时候替你刷账单。",
            "所以今天这条新闻，我不建议当 GitHub 计费新闻看。",
            "它真正的价值是提醒我们：AI 员工也要有预算、有停止条件、有验收结果。",
        ]
    elif takeaway_type == "\u4f7f\u7528\u6b65\u9aa4" and len(core_viewpoints) >= 3:
        narration_lines = [
            "今天这个 AI 热点，先别急着跟。",
            f"我真正想回答的是：{clean_topic}",
            f"先看事实：{primary_reason}",
            "如果你也想把 AI 用进自己的工作流，可以先照着这四步试。",
            f"第一步，{speech_clean(core_viewpoints[0])}。",
            f"第二步，{speech_clean(core_viewpoints[1])}。",
            f"第三步，{speech_clean(core_viewpoints[2])}。",
            f"第四步，{speech_clean(core_viewpoints[3]) if len(core_viewpoints) > 3 else '把改进任务交给 Agent，并保留验证命令'}。",
            f"这条视频的证据我会放：{first_asset}",
            "所以这不是又一个模型新闻。真正该带走的是：AI 能不能帮你变强，取决于你能不能把真实错误变成下一轮可执行的任务。",
        ]
    else:
        narration_lines = [
            "今天这个 AI 热点，先别急着跟。",
            f"我真正想回答的是：{clean_topic}",
            f"先看事实：{primary_reason}",
            f"它和普通人的关系是：{second_reason}",
            f"我会用这个证据来判断：{first_asset}",
            f"我的判断是：{primary_core}",
            f"所以别把它当成又一个 AI 新闻，真正该带走的是：{final_conclusion.replace('看完能带走一个', '今天可以带走的')}",
        ]

    narration_text = "\n".join(narration_lines)
    meta_hits = [phrase for phrase in NARRATION_META_PHRASES if phrase in narration_text]
    if meta_hits:
        raise ValueError("\u5f55\u97f3\u7a3f\u542b\u751f\u4ea7\u5b57\u6bb5\uff0c\u4e0d\u80fd\u8fdb\u5165\u514b\u9686\u58f0\u97f3\uff1a" + " / ".join(meta_hits))

    plan_content = "\n".join(
        [
            f"# {date} 单条企划",
            "",
            "## 选题一句话",
            "",
            topic,
            "",
            "## 推荐标题",
            "",
            f"**{recommended_title}**",
            "",
            "## 备用标题",
            "",
            backup_text,
            "",
            "## 内容类型",
            "",
            "热点实操验证 / 主线内容",
            "",
            "## 流量与观众收获",
            "",
            f"- 观众收益类型：{takeaway_type}",
            f"- 流量钩子：{traffic_hook}",
            f"- 看完能带走什么：{viewer_gain}",
            f"- 重复结论处置：{repeat_action}",
            "",
            "## 热点和结论相关性",
            "",
            f"- {correlation}",
            "",
            "## 核心观点",
            "",
            core_text,
            "",
            "## 为什么适合今天主线",
            "",
            reason_text,
            "",
            "## 事实依据",
            "",
            f"- 主线决策来源：`{decision_path}`",
            f"- 日报来源：`{brief_path}`",
            "",
            "## 开头 3 秒方向",
            "",
            opening_text,
            "",
            "## 今天的交付物",
            "",
            "- 一条可以直接进入录制的主线视频企划",
            "- 一套与口播同步的证据画面",
            "",
        ]
    )

    asset_content = "\n".join(
        [
            "# 分镜素材清单",
            "",
            "## 开头画面",
            "",
            opening_text,
            "",
            "## 事实证据画面",
            "",
            asset_text,
            "",
            "## 核心观点画面",
            "",
            core_text,
            "",
            "## 观众收获画面",
            "",
            f"- 用一张明确的信息卡承载：{viewer_gain}",
            f"- 这条必须按 `{takeaway_type}` 做成可保存、可复述、可评论的结果，不要只做方法论总结。",
            "",
            "## 对比画面",
            "",
            "- 失败 proof / 真 proof 对比",
            "- 静态说法 / 真实结果对比",
            "",
            "## 结尾画面",
            "",
            "- 今天的结论",
            "- 下一步要试什么",
            "",
        ]
    )

    voice_content = "\n".join(
        [
            "# 配音文案",
            "",
            "建议时长：60-90 秒",
            "",
            "## 口播骨架",
            "",
            "这份文档用于人工确认；自动配音默认读取同目录的 `录音稿.txt`。",
            "",
            "### 1. 开头",
            "",
            "- 先抛今天的真实问题",
            "- 第一句就进入结果或动作",
            "",
            "### 2. 事实层",
            "",
            "- 说明今天为什么是这条",
            "- 用 1-2 句交代背景，不做大段资讯复述",
            "",
            "### 3. 验证层",
            "",
            "- 我今天怎么试的",
            "- 我看到的结果是什么",
            "",
            "### 4. 结论层",
            "",
            "- 这件事对普通人值不值得跟",
            "- 为什么它值得 / 不值得",
            "",
            "## 需要和画面对齐的关键句",
            "",
            core_text,
            "",
            "## 不允许写成的方向",
            "",
            "- 不要再把台前结论写成“边界 / 验收 / 回滚”。",
            "- 不要把来源备注、素材备注、生产备注念进口播。",
            "- 不要只证明我们的工作流正确；必须让观众拿到新信息。",
            "",
            "## 自动生成录音稿",
            "",
            "```text",
            narration_text,
            "```",
        ]
    )

    return plan_content, asset_content, voice_content, narration_text


def run(date: str, workspace: Path, write: bool) -> dict[str, str]:
    paths = default_paths(workspace)
    brief_path = find_daily_brief(paths.inbox, date)
    recent = recent_plan_names(paths.single_root)
    recent_summaries = [
        summary for summary in recent_plan_summaries(paths.single_root)
        if not summary.startswith(f"{date}-")
    ]

    lines = brief_path.read_text(encoding="utf-8").splitlines()
    section = extract_recommended_section(lines)
    if not section:
        raise RuntimeError(f"Could not find recommended section in {brief_path}")

    topic = parse_topic(section) or "今日主线推荐待人工确认"
    title_options = parse_subsection_bullets(section, "### 标题备选")
    recommended_title = title_options[0] if title_options else topic
    backup_titles = title_options[1:4]
    opening_direction = parse_subsection_bullets(section, "### 30 秒开头方向")
    core_viewpoints = parse_subsection_bullets(section, "### 核心观点")
    asset_checklist = parse_subsection_bullets(section, "### 素材清单")

    candidate_section = find_candidate_section(lines, topic, recommended_title)
    candidate_reason_fields = [
        parse_labeled_field(candidate_section, "\u4e3a\u4ec0\u4e48\u503c\u5f97\u666e\u901a\u4eba\u5173\u6ce8\uff1a"),
        parse_labeled_field(candidate_section, "\u4e0e\u672c\u8d26\u53f7\u7684\u8fde\u63a5\u70b9\uff1a"),
    ]
    candidate_reasons = (
        parse_labeled_nested_bullets(candidate_section, "为什么值得普通人关注：")
        + parse_labeled_nested_bullets(candidate_section, "与本账号连接点：")
        + [item for item in candidate_reason_fields if item]
    )
    candidate_asset_field = parse_labeled_field(candidate_section, "\u53ef\u7528\u89c6\u9891\u7d20\u6750\u65b9\u5411\uff1a")
    candidate_assets = parse_labeled_nested_bullets(candidate_section, "可用视频素材方向：")
    if candidate_asset_field:
        candidate_assets.insert(0, candidate_asset_field)
    reason_bullets = candidate_reasons[:4] if candidate_reasons else extract_bullets(section)[:4]
    if candidate_assets:
        asset_checklist = candidate_assets
    event_fact = parse_labeled_field(candidate_section, ZH_EVENT_FACT) if candidate_section else ""

    primary_takeaway_text = "\n".join([topic, recommended_title, *core_viewpoints, *opening_direction])
    combined_text = "\n".join([primary_takeaway_text, *reason_bullets, *asset_checklist])
    takeaway_type = detect_takeaway_type(primary_takeaway_text)
    repeated_score = repeated_conclusion_score(combined_text, "\n".join(recent_summaries))

    should_force_frontstage_reset = repeated_score >= 4 and takeaway_type not in FRONTSTAGE_TAKEAWAY_PRIORITY[:5]
    if is_repeated_conclusion_bucket(topic, recommended_title, *core_viewpoints) or should_force_frontstage_reset:
        better_candidate = choose_better_candidate(lines, topic)
        if better_candidate and int(better_candidate["repeated_score"]) < repeated_score:
            topic = str(better_candidate["topic"])
            event_fact = str(better_candidate["event_fact"])
            reason_bullets = list(better_candidate["reason_bullets"])
            asset_checklist = list(better_candidate["asset_checklist"])
            takeaway_type = str(better_candidate["takeaway_type"])
            core_viewpoints = build_frontstage_core_viewpoints(
                takeaway_type=takeaway_type,
                topic=topic,
                event_fact=event_fact,
                reason_bullets=reason_bullets,
                risk_note=str(better_candidate["risk_note"]),
            )
            opening_direction = build_frontstage_opening_direction(takeaway_type, event_fact, topic)
            recommended_title = topic
            backup_titles = []
        else:
            takeaway_type = choose_takeaway_type_with_frontstage_guard(primary_takeaway_text, event_fact)
            core_viewpoints = build_frontstage_core_viewpoints(
                takeaway_type=takeaway_type,
                topic=topic,
                event_fact=event_fact,
                reason_bullets=reason_bullets,
                risk_note="",
            )
            opening_direction = build_frontstage_opening_direction(takeaway_type, event_fact, topic)

    viewer_gain = build_viewer_gain(takeaway_type, topic, core_viewpoints, reason_bullets)
    traffic_hook = build_traffic_hook(takeaway_type, topic, recommended_title)
    correlation = build_correlation(event_fact, viewer_gain, topic)

    traffic_titles = build_traffic_titles(topic, takeaway_type, [recommended_title, *backup_titles])
    if traffic_titles:
        recommended_title = traffic_titles[0]
        backup_titles = traffic_titles[1:4]

    slug = slugify(f"{recommended_title} {topic}")
    plan_dir = paths.single_root / f"{date}-{slug}"
    decision_path = paths.inbox / f"{date}-{ZH_DECISION}"
    combined_text = "\n".join([topic, recommended_title, *core_viewpoints, *reason_bullets, *asset_checklist, viewer_gain])
    repeated_score = repeated_conclusion_score(combined_text, "\n".join(recent_summaries))
    repetition_risk = any(slug in name and not name.startswith(f"{date}-") for name in recent) or repeated_score >= 4
    repeat_action = build_repeat_action(
        repetition_risk=repetition_risk,
        repeated_score=repeated_score,
        takeaway_type=takeaway_type,
        recent_summaries=recent_summaries,
    )

    hotspot_package = build_hotspot_extraction_package(
        topic=topic,
        recommended_title=recommended_title,
        backup_titles=backup_titles,
        event_fact=event_fact,
        takeaway_type=takeaway_type,
        viewer_gain=viewer_gain,
        traffic_hook=traffic_hook,
        asset_checklist=asset_checklist,
        repeat_action=repeat_action,
    )

    decision_content = build_decision_content(
        date=date,
        brief_path=brief_path,
        strategy_path=paths.strategy,
        topic=topic,
        recommended_title=recommended_title,
        backup_titles=backup_titles,
        reason_bullets=reason_bullets,
        asset_checklist=asset_checklist,
        opening_direction=opening_direction,
        recent_plans=recent,
        repetition_risk=repetition_risk,
        takeaway_type=takeaway_type,
        viewer_gain=viewer_gain,
        traffic_hook=traffic_hook,
        correlation=correlation,
        hotspot_package=hotspot_package,
        repeat_action=repeat_action,
        recent_summaries=recent_summaries,
        plan_directory=plan_dir,
    )
    plan_content, asset_content, voice_content, narration_text = build_plan_files(
        date=date,
        topic=topic,
        recommended_title=recommended_title,
        backup_titles=backup_titles,
        core_viewpoints=core_viewpoints,
        opening_direction=opening_direction,
        asset_checklist=asset_checklist,
        reason_bullets=reason_bullets,
        takeaway_type=takeaway_type,
        viewer_gain=viewer_gain,
        traffic_hook=traffic_hook,
        correlation=correlation,
        repeat_action=repeat_action,
        decision_path=decision_path,
        brief_path=brief_path,
    )

    plan_path = plan_dir / "企划.md"
    asset_path = plan_dir / "分镜素材清单.md"
    voice_path = plan_dir / "配音文案.md"
    narration_text_path = plan_dir / "录音稿.txt"

    if write:
        decision_path.write_text(decision_content, encoding="utf-8")
        plan_dir.mkdir(parents=True, exist_ok=True)
        plan_path.write_text(plan_content, encoding="utf-8")
        asset_path.write_text(asset_content, encoding="utf-8")
        voice_path.write_text(voice_content, encoding="utf-8")
        narration_text_path.write_text(narration_text, encoding="utf-8")

    return {
        "date": date,
        "decision_path": str(decision_path),
        "plan_directory": str(plan_dir),
        "plan_path": str(plan_path),
        "asset_path": str(asset_path),
        "voice_path": str(voice_path),
        "narration_text_path": str(narration_text_path),
        "topic": topic,
        "recommended_title": recommended_title,
        "takeaway_type": takeaway_type,
        "viewer_gain": viewer_gain,
        "traffic_hook": traffic_hook,
        "hotspot_package": hotspot_package,
        "repetition_risk": str(repetition_risk),
        "slug": slug,
    }


def _load_json_object(path: Path, label: str) -> dict[str, object]:
    if not path.is_file():
        raise RuntimeError(f"{label} file does not exist: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"{label} file is not valid JSON: {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise RuntimeError(f"{label} file must contain a JSON object: {path}")
    return data


def _validate_portable_inputs(
    input_path: Path,
    rubric_path: Path,
) -> tuple[list[dict[str, object]], dict[str, object], list[dict[str, object]]]:
    candidate_document = _load_json_object(input_path, "Candidate input")
    rubric = _load_json_object(rubric_path, "Rubric")

    candidates = candidate_document.get("candidates")
    dimensions = rubric.get("dimensions")
    score_range = rubric.get("scoreRange")
    if not isinstance(candidates, list) or not candidates:
        raise RuntimeError("Candidate input must define a non-empty candidates array")
    if not isinstance(dimensions, list) or not dimensions:
        raise RuntimeError("Rubric must define a non-empty dimensions array")
    if not isinstance(score_range, dict):
        raise RuntimeError("Rubric must define scoreRange.minimum and scoreRange.maximum")

    minimum = score_range.get("minimum")
    maximum = score_range.get("maximum")
    if not isinstance(minimum, (int, float)) or not isinstance(maximum, (int, float)) or minimum >= maximum:
        raise RuntimeError("Rubric scoreRange must contain numeric minimum < maximum")

    validated_dimensions: list[dict[str, object]] = []
    total_weight = 0.0
    for index, dimension in enumerate(dimensions):
        if not isinstance(dimension, dict):
            raise RuntimeError(f"Rubric dimension {index + 1} must be an object")
        field = dimension.get("field")
        label = dimension.get("label")
        weight = dimension.get("weight")
        direction = dimension.get("direction")
        if not isinstance(field, str) or not field.strip():
            raise RuntimeError(f"Rubric dimension {index + 1} needs a field")
        if not isinstance(label, str) or not label.strip():
            raise RuntimeError(f"Rubric dimension {field} needs a label")
        if not isinstance(weight, (int, float)) or weight <= 0:
            raise RuntimeError(f"Rubric dimension {field} needs a positive numeric weight")
        if direction not in ("higher", "lower"):
            raise RuntimeError(f"Rubric dimension {field} direction must be higher or lower")
        total_weight += float(weight)
        validated_dimensions.append(dimension)
    if abs(total_weight - 100.0) > 0.0001:
        raise RuntimeError(f"Rubric dimension weights must total 100, got {total_weight:g}")

    minimum_evidence = rubric.get("minimumEvidenceItems", 1)
    if not isinstance(minimum_evidence, int) or minimum_evidence < 1:
        raise RuntimeError("Rubric minimumEvidenceItems must be a positive integer")

    required_text_fields = ("title", "source")
    validated_candidates: list[dict[str, object]] = []
    for index, candidate in enumerate(candidates):
        if not isinstance(candidate, dict):
            raise RuntimeError(f"Candidate {index + 1} must be an object")
        for field in required_text_fields:
            value = candidate.get(field)
            if not isinstance(value, str) or not value.strip():
                raise RuntimeError(f"Candidate {index + 1} needs a non-empty {field}")
        evidence = candidate.get("evidence")
        if (
            not isinstance(evidence, list)
            or len(evidence) < minimum_evidence
            or any(not isinstance(item, str) or not item.strip() for item in evidence)
        ):
            raise RuntimeError(
                f"Candidate {index + 1} needs at least {minimum_evidence} non-empty evidence item(s)"
            )
        for dimension in validated_dimensions:
            field = str(dimension["field"])
            value = candidate.get(field)
            if not isinstance(value, (int, float)) or not minimum <= value <= maximum:
                raise RuntimeError(
                    f"Candidate {index + 1} field {field} must be between {minimum:g} and {maximum:g}"
                )
        validated_candidates.append(candidate)

    return validated_candidates, rubric, validated_dimensions


def portable_topic_preflight(input_path: Path, rubric_path: Path) -> dict[str, object]:
    candidates, rubric, dimensions = _validate_portable_inputs(input_path, rubric_path)
    return {
        "ok": True,
        "success": True,
        "mode": "offline-fixture",
        "candidateCount": len(candidates),
        "rubricName": str(rubric.get("name", rubric_path.stem)),
        "dimensions": [str(item["field"]) for item in dimensions],
        "inputPath": str(input_path.resolve()),
        "rubricPath": str(rubric_path.resolve()),
    }


def _score_portable_candidates(
    candidates: list[dict[str, object]],
    rubric: dict[str, object],
    dimensions: list[dict[str, object]],
) -> list[dict[str, object]]:
    score_range = rubric["scoreRange"]
    assert isinstance(score_range, dict)
    minimum = float(score_range["minimum"])
    maximum = float(score_range["maximum"])
    del minimum

    ranked: list[dict[str, object]] = []
    for original_index, candidate in enumerate(candidates):
        contributions: list[dict[str, object]] = []
        for dimension in dimensions:
            field = str(dimension["field"])
            raw_score = float(candidate[field])
            weight = float(dimension["weight"])
            direction = str(dimension["direction"])
            effective_score = raw_score if direction == "higher" else maximum + 1.0 - raw_score
            contribution = round((effective_score / maximum) * weight, 2)
            contributions.append(
                {
                    "field": field,
                    "label": str(dimension["label"]),
                    "rawScore": raw_score,
                    "direction": direction,
                    "weight": weight,
                    "contribution": contribution,
                }
            )
        total_score = round(sum(float(item["contribution"]) for item in contributions), 2)
        explanation = "; ".join(
            f"{item['label']} {item['rawScore']:g}/{maximum:g} -> {item['contribution']:g}"
            for item in contributions
        )
        ranked.append(
            {
                **candidate,
                "totalScore": total_score,
                "scoreExplanation": f"{explanation}; total {total_score:g}/100",
                "scoreBreakdown": contributions,
                "rejectionReason": None,
                "_originalIndex": original_index,
            }
        )

    ranked.sort(key=lambda item: (-float(item["totalScore"]), int(item["_originalIndex"])))
    selected = ranked[0]
    for candidate in ranked[1:]:
        gap = round(float(selected["totalScore"]) - float(candidate["totalScore"]), 2)
        weakest = min(
            candidate["scoreBreakdown"],
            key=lambda item: float(item["contribution"]),
        )
        candidate["rejectionReason"] = (
            f"Scored {gap:g} points below the selected topic; "
            f"weakest weighted dimension: {weakest['label']} ({weakest['contribution']:g} points)."
        )
    for candidate in ranked:
        candidate.pop("_originalIndex", None)
    return ranked


def _build_portable_decision_markdown(
    date: str,
    ranked: list[dict[str, object]],
    input_path: Path,
    rubric_path: Path,
) -> str:
    selected = ranked[0]
    lines = [
        f"# Topic decision — {date}",
        "",
        "## Selected topic",
        "",
        f"**{selected['title']}** — {selected['totalScore']:g}/100",
        "",
        str(selected["scoreExplanation"]),
        "",
        "Evidence:",
        "",
        *[f"- {item}" for item in selected["evidence"]],
        "",
        "## Full ranking",
        "",
        "| Rank | Topic | Score | Decision |",
        "| ---: | --- | ---: | --- |",
    ]
    for index, candidate in enumerate(ranked, start=1):
        decision = "Selected" if index == 1 else str(candidate["rejectionReason"])
        lines.append(f"| {index} | {candidate['title']} | {candidate['totalScore']:g} | {decision} |")
    lines.extend(
        [
            "",
            "## Reproducibility",
            "",
            f"- Candidate input: `{input_path.resolve()}`",
            f"- Rubric: `{rubric_path.resolve()}`",
            "- Collection mode: offline fixture; no network request was made.",
            "",
        ]
    )
    return "\n".join(lines)


def run_portable_topic_decision(
    date: str,
    input_path: Path,
    rubric_path: Path,
    output_root: Path,
    write: bool,
) -> dict[str, object]:
    candidates, rubric, dimensions = _validate_portable_inputs(input_path, rubric_path)
    ranked = _score_portable_candidates(candidates, rubric, dimensions)
    output_root = output_root.resolve()
    ranking_path = output_root / "topic-ranking.json"
    decision_path = output_root / "topic-decision.md"
    selected = ranked[0]
    ranking_document = {
        "schemaVersion": 1,
        "date": date,
        "mode": "offline-fixture",
        "rubricName": str(rubric.get("name", rubric_path.stem)),
        "selectedTopic": selected,
        "rankedCandidates": ranked,
    }
    if write:
        output_root.mkdir(parents=True, exist_ok=True)
        ranking_path.write_text(
            json.dumps(ranking_document, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        decision_path.write_text(
            _build_portable_decision_markdown(date, ranked, input_path, rubric_path),
            encoding="utf-8",
        )
    return {
        "ok": True,
        "success": True,
        "mode": "offline-fixture",
        "date": date,
        "candidateCount": len(ranked),
        "selectedTopic": selected,
        "rankedCandidates": ranked,
        "rankingPath": str(ranking_path),
        "decisionPath": str(decision_path),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True)
    parser.add_argument("--workspace", default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument("--input")
    parser.add_argument("--rubric")
    parser.add_argument("--output-root")
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()

    portable_mode = any((args.input, args.rubric, args.output_root))
    if portable_mode:
        if not args.input or not args.rubric:
            parser.error("portable mode requires both --input and --rubric")
        output_root = Path(args.output_root) if args.output_root else Path(args.workspace) / "output" / args.date
        if args.preflight:
            result = portable_topic_preflight(Path(args.input), Path(args.rubric))
        else:
            result = run_portable_topic_decision(
                date=args.date,
                input_path=Path(args.input),
                rubric_path=Path(args.rubric),
                output_root=output_root,
                write=args.write,
            )
    elif args.preflight:
        result = preflight(date=args.date, workspace=Path(args.workspace))
    else:
        result = run(date=args.date, workspace=Path(args.workspace), write=args.write)
    print(json.dumps(result, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
