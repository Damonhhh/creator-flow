import argparse
import json
import os
import sys
from pathlib import Path

from portable_runtime import resolve_required_directory


def read_text(path: Path) -> str:
    text = path.read_text(encoding="utf-8-sig")
    lines = [line.strip() for line in text.splitlines()]
    return "\n".join(line for line in lines if line)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate one continuous IndexTTS-2 narration file.")
    parser.add_argument("--repo")
    parser.add_argument("--reference-audio", required=True)
    parser.add_argument("--text-file", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--emotion-audio")
    parser.add_argument("--emotion-alpha", type=float, default=0.75)
    parser.add_argument("--fp16", action="store_true")
    parser.add_argument("--max-text-tokens-per-segment", type=int, default=120)
    parser.add_argument("--max-mel-tokens", type=int, default=1500)
    parser.add_argument("--interval-ms", type=int, default=280)
    parser.add_argument("--top-p", type=float, default=0.82)
    parser.add_argument("--top-k", type=int, default=30)
    parser.add_argument("--temperature", type=float, default=0.78)
    args = parser.parse_args()

    try:
        repo = resolve_required_directory(args.repo, "INDEXTTS_REPO", "IndexTTS repository")
    except (ValueError, FileNotFoundError) as exc:
        parser.error(str(exc))
    sys.path.insert(0, str(repo))
    sys.path.insert(0, str(repo / "indextts"))
    os.chdir(repo)

    from indextts.infer_v2 import IndexTTS2

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    text = read_text(Path(args.text_file))
    if not text:
        raise SystemExit("No text found.")

    tts = IndexTTS2(
        model_dir=str(repo / "checkpoints"),
        cfg_path=str(repo / "checkpoints" / "config.yaml"),
        use_fp16=args.fp16,
        use_deepspeed=False,
        use_cuda_kernel=False,
    )

    result = tts.infer(
        spk_audio_prompt=args.reference_audio,
        text=text,
        output_path=str(output),
        emo_audio_prompt=args.emotion_audio,
        emo_alpha=args.emotion_alpha,
        emo_vector=None,
        use_emo_text=False,
        emo_text=None,
        use_random=False,
        interval_silence=args.interval_ms,
        verbose=False,
        max_text_tokens_per_segment=args.max_text_tokens_per_segment,
        do_sample=True,
        top_p=args.top_p,
        top_k=args.top_k,
        temperature=args.temperature,
        length_penalty=0.0,
        num_beams=3,
        repetition_penalty=10.0,
        max_mel_tokens=args.max_mel_tokens,
    )
    if result is None or not output.exists():
        raise RuntimeError(f"IndexTTS-2 did not generate output: {output}")

    summary = {
        "output": str(output),
        "text_file": str(Path(args.text_file)),
        "reference_audio": str(Path(args.reference_audio)),
        "emotion_audio": str(Path(args.emotion_audio)) if args.emotion_audio else None,
        "emotion_alpha": args.emotion_alpha,
        "max_text_tokens_per_segment": args.max_text_tokens_per_segment,
        "interval_ms": args.interval_ms,
    }
    summary_path = output.with_name(output.stem + "-generation.json")
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2), flush=True)


if __name__ == "__main__":
    main()
