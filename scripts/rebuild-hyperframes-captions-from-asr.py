import argparse
import ctypes
import difflib
import json
import re
import sys
from pathlib import Path

from faster_whisper import WhisperModel

from portable_runtime import resolve_cache_directory


PUNCT_RE = re.compile(r"[，。！？；：、,.!?;:\s“”\"'（）()《》【】\[\]-]")


def to_simplified_chinese(text: str) -> str:
    """Normalize Traditional Chinese ASR output for alignment on Windows."""
    if sys.platform != "win32" or not text:
        return text
    try:
        mapper = ctypes.windll.kernel32.LCMapStringEx
        mapper.argtypes = [
            ctypes.c_wchar_p,
            ctypes.c_ulong,
            ctypes.c_wchar_p,
            ctypes.c_int,
            ctypes.c_wchar_p,
            ctypes.c_int,
            ctypes.c_void_p,
            ctypes.c_void_p,
            ctypes.c_longlong,
        ]
        mapper.restype = ctypes.c_int
        simplified_flag = 0x02000000  # LCMAP_SIMPLIFIED_CHINESE
        required = mapper("zh-CN", simplified_flag, text, len(text), None, 0, None, None, 0)
        if required <= 0:
            return text
        buffer = ctypes.create_unicode_buffer(required + 1)
        written = mapper(
            "zh-CN",
            simplified_flag,
            text,
            len(text),
            buffer,
            required + 1,
            None,
            None,
            0,
        )
        return buffer.value if written > 0 else text
    except (AttributeError, OSError):
        return text


def normalize(text: str) -> str:
    return PUNCT_RE.sub("", to_simplified_chinese(text)).lower()


def display_text(text: str) -> str:
    text = re.sub(r"\s+", " ", text.strip())
    text = re.sub(r"(?<=[\u4e00-\u9fff])([A-Za-z][A-Za-z0-9-]*)", r" \1", text)
    text = re.sub(r"([A-Za-z][A-Za-z0-9-]*)(?=[\u4e00-\u9fff])", r"\1 ", text)
    text = text.replace("API key", "API key")
    text = text.replace("API  key", "API key")
    return text.strip()


def split_script(text: str, max_chars: int = 36) -> list[str]:
    text = re.sub(r"\s*\n+\s*", "", text.strip())
    text = re.sub(r"[ \t]+", " ", text)
    chunks: list[str] = []
    current = ""
    hard_breaks = set("。！？；")
    soft_breaks = set("，：、")

    for char in text:
        current += char
        if char in hard_breaks or (char in soft_breaks and len(current) >= 14) or len(current) >= max_chars:
            chunks.append(current)
            current = ""
    if current:
        chunks.append(current)

    refined: list[str] = []
    for chunk in chunks:
        if len(chunk) <= max_chars:
            refined.append(chunk)
            continue
        piece = ""
        for char in chunk:
            piece += char
            if len(piece) >= max_chars:
                refined.append(piece)
                piece = ""
        if piece:
            refined.append(piece)
    merged: list[str] = []
    for item in refined:
        if not normalize(item):
            continue
        # Keep short grammatical tails such as “的模型” and “核优化” with the
        # preceding display cue. The draft-QA gate treats 1-3 character
        # continuations as unreadable fragments.
        if merged and len(normalize(item)) <= 3 and len(display_text(merged[-1] + item)) <= max_chars + 4:
            merged[-1] += item
        elif merged and normalize(merged[-1]).endswith("我免费") and normalize(item).startswith("我好心"):
            merged[-1] += item
        else:
            merged.append(item)
    return [display_text(item) for item in merged if normalize(item)]


def run_asr(
    audio: Path,
    model_name: str,
    model_dir: Path,
    device: str,
    compute_type: str,
) -> tuple[list[dict], list[dict]]:
    model = WhisperModel(
        model_name,
        device=device,
        compute_type=compute_type,
        download_root=str(model_dir),
        local_files_only=True,
    )
    segments, info = model.transcribe(
        str(audio),
        language="zh",
        beam_size=5,
        vad_filter=False,
        word_timestamps=True,
        condition_on_previous_text=True,
    )
    raw_segments = []
    char_timeline = []
    for seg in segments:
        words = []
        if seg.words:
            for word in seg.words:
                words.append(
                    {
                        "word": word.word,
                        "start": word.start,
                        "end": word.end,
                        "probability": word.probability,
                    }
                )
                word_norm = normalize(word.word)
                if not word_norm or word.start is None or word.end is None:
                    continue
                span = max(0.01, word.end - word.start)
                step = span / len(word_norm)
                for index, char in enumerate(word_norm):
                    char_timeline.append(
                        {
                            "char": char,
                            "start": word.start + index * step,
                            "end": word.start + (index + 1) * step,
                        }
                    )
        raw_segments.append(
            {
                "start": seg.start,
                "end": seg.end,
                "text": seg.text.strip(),
                "words": words,
            }
        )
    return raw_segments, char_timeline


def align_script_to_asr(script_norm: str, char_timeline: list[dict]) -> list[tuple[float, float] | None]:
    asr_norm = "".join(item["char"] for item in char_timeline)
    mapping: list[tuple[float, float] | None] = [None] * len(script_norm)
    matcher = difflib.SequenceMatcher(None, script_norm, asr_norm, autojunk=False)

    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag != "equal":
            continue
        for offset in range(i2 - i1):
            source_index = i1 + offset
            target_index = j1 + offset
            if 0 <= target_index < len(char_timeline):
                mapping[source_index] = (char_timeline[target_index]["start"], char_timeline[target_index]["end"])

    known = [idx for idx, value in enumerate(mapping) if value is not None]
    if not known:
        raise RuntimeError("ASR alignment failed: no equal character blocks found.")

    first_known = known[0]
    for idx in range(0, first_known):
        mapping[idx] = mapping[first_known]

    last_known = first_known
    for idx in range(first_known + 1, len(mapping)):
        if mapping[idx] is not None:
            last_known = idx
            continue
        next_known = next((candidate for candidate in known if candidate > idx), None)
        if next_known is None:
            mapping[idx] = mapping[last_known]
            continue
        left = mapping[last_known]
        right = mapping[next_known]
        assert left is not None and right is not None
        ratio = (idx - last_known) / max(1, next_known - last_known)
        start = left[1] + (right[0] - left[1]) * ratio
        mapping[idx] = (start, start + 0.04)
    return mapping


def build_captions(chunks: list[str], mapping: list[tuple[float, float] | None], audio_duration: float) -> list[dict]:
    captions = []
    cursor = 0
    for chunk in chunks:
        norm = normalize(chunk)
        start_index = cursor
        end_index = cursor + len(norm) - 1
        cursor += len(norm)
        times = [item for item in mapping[start_index : end_index + 1] if item is not None]
        if not times:
            continue
        start = max(0.0, min(item[0] for item in times) - 0.06)
        end = min(audio_duration, max(item[1] for item in times) + 0.16)
        captions.append({"start": start, "end": end, "text": chunk})

    for index, caption in enumerate(captions):
        if index > 0 and caption["start"] < captions[index - 1]["end"]:
            midpoint = (caption["start"] + captions[index - 1]["end"]) / 2
            captions[index - 1]["end"] = max(captions[index - 1]["start"] + 0.18, midpoint - 0.02)
            caption["start"] = min(caption["end"] - 0.18, midpoint + 0.02)
        if caption["end"] - caption["start"] < 0.45:
            caption["end"] = min(audio_duration, caption["start"] + 0.45)
    return captions


def format_srt_time(value: float) -> str:
    value = max(0.0, value)
    hours = int(value // 3600)
    minutes = int((value % 3600) // 60)
    seconds = int(value % 60)
    millis = int(round((value - int(value)) * 1000))
    if millis == 1000:
        seconds += 1
        millis = 0
    return f"{hours:02}:{minutes:02}:{seconds:02},{millis:03}"


def write_srt(path: Path, captions: list[dict]) -> None:
    lines = []
    for index, cue in enumerate(captions, 1):
        lines.extend(
            [
                str(index),
                f"{format_srt_time(cue['start'])} --> {format_srt_time(cue['end'])}",
                cue["text"],
                "",
            ]
        )
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", required=True)
    parser.add_argument("--script", required=True)
    parser.add_argument("--output-js", required=True)
    parser.add_argument("--output-srt", required=True)
    parser.add_argument("--report-json", required=True)
    parser.add_argument("--model", default="small")
    parser.add_argument("--model-dir")
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--compute-type", default="int8")
    parser.add_argument("--audio-duration", type=float, required=True)
    args = parser.parse_args()

    audio = Path(args.audio)
    script_path = Path(args.script)
    output_js = Path(args.output_js)
    output_srt = Path(args.output_srt)
    report_json = Path(args.report_json)

    script_text = script_path.read_text(encoding="utf-8")
    chunks = split_script(script_text)
    script_norm = "".join(normalize(chunk) for chunk in chunks)
    model_dir = resolve_cache_directory(
        args.model_dir,
        "HF_HOME",
        Path.home() / ".cache" / "huggingface" / "hub",
    )
    raw_segments, char_timeline = run_asr(
        audio,
        args.model,
        model_dir,
        args.device,
        args.compute_type,
    )
    mapping = align_script_to_asr(script_norm, char_timeline)
    captions = build_captions(chunks, mapping, args.audio_duration)

    output_js.write_text(
        "window.CAPTIONS = " + json.dumps(captions, ensure_ascii=False, indent=2) + ";\n",
        encoding="utf-8",
    )
    write_srt(output_srt, captions)
    report_json.write_text(
        json.dumps(
            {
                "audio": str(audio),
                "script": str(script_path),
                "model": args.model,
                "device": args.device,
                "compute_type": args.compute_type,
                "captions": len(captions),
                "script_norm_chars": len(script_norm),
                "asr_norm_chars": len(char_timeline),
                "raw_segments": raw_segments,
                "captions_preview": captions[:12],
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
