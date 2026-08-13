import argparse
import json
import re
import subprocess
from pathlib import Path


TIME_RE = re.compile(
    r"(?P<sh>\d{2}):(?P<sm>\d{2}):(?P<ss>\d{2}),(?P<sms>\d{3})\s+-->\s+"
    r"(?P<eh>\d{2}):(?P<em>\d{2}):(?P<es>\d{2}),(?P<ems>\d{3})"
)


def parse_time(h: str, m: str, s: str, ms: str) -> float:
    return int(h) * 3600 + int(m) * 60 + int(s) + int(ms) / 1000


def ffprobe_duration(ffprobe: Path, audio: Path) -> float:
    raw = subprocess.check_output(
        [
            str(ffprobe),
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=nw=1:nk=1",
            str(audio),
        ],
        text=True,
        encoding="utf-8",
    ).strip()
    return float(raw)


def parse_srt(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8-sig")
    blocks = re.split(r"\n\s*\n", text.strip())
    cues = []
    for block in blocks:
        lines = [line.strip() for line in block.splitlines() if line.strip()]
        if len(lines) < 3:
            continue
        match = TIME_RE.search(lines[1])
        if not match:
            continue
        data = match.groupdict()
        start = parse_time(data["sh"], data["sm"], data["ss"], data["sms"])
        end = parse_time(data["eh"], data["em"], data["es"], data["ems"])
        cues.append(
            {
                "index": lines[0],
                "start": start,
                "end": end,
                "duration": end - start,
                "text": " ".join(lines[2:]),
            }
        )
    return cues


def main() -> None:
    parser = argparse.ArgumentParser(description="Verify whether an SRT has a plausible real timeline.")
    parser.add_argument("--audio", required=True)
    parser.add_argument("--srt", required=True)
    parser.add_argument("--ffprobe", default="ffprobe")
    parser.add_argument("--report", required=True)
    parser.add_argument("--json-report", default="")
    args = parser.parse_args()

    audio = Path(args.audio)
    srt = Path(args.srt)
    report = Path(args.report)
    ffprobe = Path(args.ffprobe)

    duration = ffprobe_duration(ffprobe, audio)
    cues = parse_srt(srt)
    issues = []

    if not cues:
        issues.append("No parseable SRT cues found.")

    previous_end = 0.0
    max_gap = 0.0
    max_overlap = 0.0
    empty_text_count = 0
    for cue in cues:
        if cue["start"] < -0.001:
            issues.append(f"Cue {cue['index']} starts before zero.")
        if cue["end"] <= cue["start"]:
            issues.append(f"Cue {cue['index']} has non-positive duration.")
        if cue["start"] < previous_end - 0.001:
            max_overlap = max(max_overlap, previous_end - cue["start"])
        else:
            max_gap = max(max_gap, cue["start"] - previous_end)
        if not cue["text"]:
            empty_text_count += 1
        previous_end = max(previous_end, cue["end"])

    if cues and cues[-1]["end"] > duration + 0.5:
        issues.append(
            f"Last SRT end {cues[-1]['end']:.3f}s exceeds audio duration {duration:.3f}s by more than 0.5s."
        )
    if empty_text_count:
        issues.append(f"{empty_text_count} cue(s) have empty text.")
    if max_overlap > 0.05:
        issues.append(f"Timeline has overlap up to {max_overlap:.3f}s.")

    timeline_pass = len(issues) == 0 and bool(cues)
    result = {
        "audio": str(audio),
        "srt": str(srt),
        "audio_duration_sec": round(duration, 3),
        "cue_count": len(cues),
        "first_start_sec": round(cues[0]["start"], 3) if cues else None,
        "last_end_sec": round(cues[-1]["end"], 3) if cues else None,
        "max_gap_sec": round(max_gap, 3),
        "max_overlap_sec": round(max_overlap, 3),
        "timeline_structural_pass": timeline_pass,
        "issues": issues,
        "cues": cues,
    }

    lines = [
        "# SRT 时间轴验证报告",
        "",
        f"- 音频：`{audio}`",
        f"- 字幕：`{srt}`",
        f"- 音频总时长：{duration:.3f}s",
        f"- SRT 段数：{len(cues)}",
        f"- 第一段开始：{cues[0]['start']:.3f}s" if cues else "- 第一段开始：无",
        f"- 最后一段结束：{cues[-1]['end']:.3f}s" if cues else "- 最后一段结束：无",
        f"- 最大空隙：{max_gap:.3f}s",
        f"- 最大重叠：{max_overlap:.3f}s",
        f"- 结构验证：{'PASS' if timeline_pass else 'FAIL'}",
        "",
        "## 判断",
        "",
        "这份报告只能证明 SRT 时间轴结构真实可用：存在非零起止时间、按顺序递增、没有明显越界，并且最后时间点贴近音频总时长。",
        "它不能单独证明识别文字 100% 准确；文字准确性仍需要人工听一遍或和口播稿比对。",
        "",
        "## SRT 片段",
        "",
    ]
    for cue in cues:
        lines.append(f"- {cue['index']}: {cue['start']:.3f}s -> {cue['end']:.3f}s | {cue['text']}")
    if issues:
        lines.extend(["", "## 问题", ""])
        lines.extend(f"- {issue}" for issue in issues)

    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    if args.json_report:
        Path(args.json_report).write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
