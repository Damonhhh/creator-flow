import argparse
import json
import os
import re
import sys
from pathlib import Path

import torch
import torchaudio

from portable_runtime import resolve_required_directory


PUNCTUATION_PATTERN = r"([。！？；，、,.!?;:])"


def srt_time(seconds: float) -> str:
    ms_total = int(round(seconds * 1000))
    h, rem = divmod(ms_total, 3600_000)
    m, rem = divmod(rem, 60_000)
    s, ms = divmod(rem, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def normalize_line(line: str) -> str:
    return re.sub(r"\s+", " ", line.strip())


def split_hard_wrap(text: str, max_chars: int) -> list[str]:
    if len(text) <= max_chars:
        return [text]

    chunks: list[str] = []
    current = text
    while len(current) > max_chars:
        split_at = current.rfind(" ", 0, max_chars + 1)
        if split_at <= 0:
            split_at = max_chars
        chunks.append(current[:split_at].strip())
        current = current[split_at:].strip()
    if current:
        chunks.append(current)
    return chunks


def split_long_line(line: str, max_chars: int) -> list[str]:
    if max_chars <= 0 or len(line) <= max_chars:
        return [line]

    chunks: list[str] = []
    current = ""
    parts = re.split(PUNCTUATION_PATTERN, line)
    for index in range(0, len(parts), 2):
        piece = parts[index]
        punctuation = parts[index + 1] if index + 1 < len(parts) else ""
        unit = normalize_line(piece + punctuation)
        if not unit:
            continue
        if current and len(current) + len(unit) > max_chars:
            chunks.extend(split_hard_wrap(current, max_chars))
            current = unit
        else:
            current = normalize_line(current + unit)
    if current:
        chunks.extend(split_hard_wrap(current, max_chars))
    return chunks


def load_lines(path: Path, max_chars: int) -> list[str]:
    raw = path.read_text(encoding="utf-8-sig")
    lines = []
    for line in raw.splitlines():
        line = normalize_line(line)
        if line:
            lines.extend(split_long_line(line, max_chars))
    return lines


def main() -> None:
    parser = argparse.ArgumentParser(description="Batch-generate IndexTTS-2 narration from narration chunks.")
    parser.add_argument("--repo")
    parser.add_argument("--reference-audio", required=True)
    parser.add_argument("--lines-file", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--fp16", action="store_true")
    parser.add_argument("--max-text-tokens-per-segment", type=int, default=90)
    parser.add_argument("--max-chars-per-line", type=int, default=0)
    parser.add_argument("--max-mel-tokens", type=int, default=1500)
    parser.add_argument("--interval-ms", type=int, default=0)
    parser.add_argument("--inner-interval-ms", type=int, default=80)
    parser.add_argument("--num-beams", type=int, default=1)
    parser.add_argument("--top-p", type=float, default=0.82)
    parser.add_argument("--top-k", type=int, default=30)
    parser.add_argument("--temperature", type=float, default=0.76)
    args = parser.parse_args()

    try:
        repo = resolve_required_directory(args.repo, "INDEXTTS_REPO", "IndexTTS repository")
    except (ValueError, FileNotFoundError) as exc:
        parser.error(str(exc))
    sys.path.insert(0, str(repo))
    sys.path.insert(0, str(repo / "indextts"))
    os.chdir(repo)

    from indextts.infer_v2 import IndexTTS2

    reference = Path(args.reference_audio)
    lines_file = Path(args.lines_file)
    out_dir = Path(args.out_dir)
    segments_dir = out_dir / "segments"
    out_dir.mkdir(parents=True, exist_ok=True)
    segments_dir.mkdir(parents=True, exist_ok=True)

    lines = load_lines(lines_file, args.max_chars_per_line)
    if not lines:
        raise SystemExit("No lines found.")

    print(
        json.dumps(
            {
                "event": "batch_start",
                "line_count": len(lines),
                "fp16": args.fp16,
                "max_chars_per_line": args.max_chars_per_line,
                "num_beams": args.num_beams,
            },
            ensure_ascii=False,
        ),
        flush=True,
    )

    tts = IndexTTS2(
        model_dir=str(repo / "checkpoints"),
        cfg_path=str(repo / "checkpoints" / "config.yaml"),
        use_fp16=args.fp16,
        use_deepspeed=False,
        use_cuda_kernel=False,
    )

    meta = []
    wavs = []
    cursor = 0.0
    silence_samples = int(22050 * args.interval_ms / 1000)
    silence = torch.zeros((1, silence_samples), dtype=torch.float32)

    for index, line in enumerate(lines, start=1):
        segment_path = segments_dir / f"{args.name}-seg-{index:02d}.wav"
        print(f"[{index}/{len(lines)}] {line}", flush=True)
        result = tts.infer(
            spk_audio_prompt=str(reference),
            text=line,
            output_path=str(segment_path),
            emo_audio_prompt=None,
            emo_alpha=1.0,
            emo_vector=None,
            use_emo_text=False,
            emo_text=None,
            use_random=False,
            verbose=False,
            max_text_tokens_per_segment=args.max_text_tokens_per_segment,
            interval_silence=args.inner_interval_ms,
            do_sample=True,
            top_p=args.top_p,
            top_k=args.top_k,
            temperature=args.temperature,
            length_penalty=0.0,
            num_beams=args.num_beams,
            repetition_penalty=10.0,
            max_mel_tokens=args.max_mel_tokens,
        )
        if result is None or not segment_path.exists():
            raise RuntimeError(f"Segment {index} did not generate: {line}")

        wav, sr = torchaudio.load(segment_path)
        if sr != 22050:
            wav = torchaudio.functional.resample(wav, sr, 22050)
            sr = 22050
        duration = wav.shape[-1] / sr
        start = cursor
        end = cursor + duration
        meta.append(
            {
                "index": index,
                "text": line,
                "path": str(segment_path),
                "duration": round(duration, 3),
                "start": round(start, 3),
                "end": round(end, 3),
            }
        )
        wavs.append(wav)
        if index != len(lines) and silence_samples > 0:
            wavs.append(silence)
            cursor = end + args.interval_ms / 1000
        else:
            cursor = end

    full_wav = torch.cat(wavs, dim=1)
    final_wav = out_dir / f"{args.name}.wav"
    torchaudio.save(final_wav, full_wav, 22050)

    srt_lines = []
    for item in meta:
        srt_lines.append(str(item["index"]))
        srt_lines.append(f"{srt_time(item['start'])} --> {srt_time(item['end'])}")
        srt_lines.append(item["text"])
        srt_lines.append("")
    srt_path = out_dir / f"{args.name}.srt"
    srt_path.write_text("\n".join(srt_lines), encoding="utf-8")

    meta_path = out_dir / f"{args.name}-segments.json"
    summary = {
        "final_wav": str(final_wav),
        "srt": str(srt_path),
        "lines_file": str(lines_file),
        "reference_audio": str(reference),
        "duration": round(full_wav.shape[-1] / 22050, 3),
        "segment_count": len(meta),
        "segments": meta,
    }
    meta_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2), flush=True)


if __name__ == "__main__":
    main()
