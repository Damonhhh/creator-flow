# Stage: Script TTS

## When To Use

Use this stage when writing the spoken script, polishing titles or openings, preparing direct-read narration, generating cloned voice, or validating audio/SRT inputs before video assembly.

## Read First

- `docs\failure-pattern-index.md` (Script TTS: FP01, FP08, FP10, FP16, FP17, FP28-FP30); open matching details only when triggered.
- The active project's `account-profile.md` and `writing-style.md`.
- A final human-readable editing pass for public-facing text.

## Inputs

- Approved topic decision from `stage-topic.md`.
- Viewer-facing deliverable and evidence list.
- Required platform, account lane, and target duration.
- Existing draft script, outline, or daily topic report.

## Actions

- Run `scripts\resolve-workflow-dependencies.ps1 -Stage ScriptTTS -TtsConfigPath <local-config>` before generating narration. In its default mode it only reports readiness and fallbacks.
- Keep `existing-audio` as a complete supported route. When IndexTTS2 is selected, treat source, Python runtime, model checkpoints, and private reference audio as separate gates. Ask for approval for only the next proposed action; cloning source does not authorize package or model downloads.
- Write `录音稿.txt` as spoken narration only.
- Remove production notes, internal labels, scoring fields, and visual instructions from viewer-facing copy.
- Keep concrete source deliverables, names, numbers, and examples when they help the viewer.
- For high-interest case teardown scripts, open with the viewer's strongest real curiosity before naming the mechanism: object + result, contradiction, evidence boundary, action mechanism, viewer takeaway.
- For dense long-form videos, add a brief viewing guide immediately after the first hook has landed and before the main explanation expands, normally inside the first 10-20 seconds: say the video is long/dense when true, name how to use it, and give a concrete reason to like/favorite it so the viewer can find the checklist or route later.
- When the topic's real pull is attraction, money, growth, risk, or contradiction, do not sand it down. Keep the hook strong, then put platform safety and evidence limits in the next layer.
- Do not lead with abstract nouns such as `三层路径`, `角色付费系统`, `飞轮`, `可调用资产`, or `四个文件夹` unless the same sentence turns them into visible actions.
- When the viewer-facing deliverable tells ordinary users to hand AI a real task, lock one minimal example when the episode promises actionability: raw input, the instruction given to AI, the returned format, and the human acceptance check. A list such as `初稿 / 整理 / 检索` names categories but does not by itself teach the first move.
- Run the project style layer and `humanize-writing` before finalizing public text.
- After final text or real audio exists, decide orientation: longer than 90 seconds defaults to 1920x1080; 90 seconds or shorter defaults to 1080x1920 unless the project says otherwise.
- Record the decision in `draft\orientation-decision.json` with `durationSec`, `orientation`, `width`, `height`, `source`, and optional `exception` + `reason`.
- Generate or verify audio and SRT when narration is part of this pass.

## Hard Gates

- `录音稿.txt` must not contain planning fields such as `收获类型`, `画面里我会放`, `岗位影响`, `素材规则`, or internal QA language.
- If the script changes after audio or SRT generation, the old audio/SRT are obsolete.
- Fake evenly spaced subtitles are not acceptable as real timing.
- Production notes may exist in planning files, never in narration, captions, covers, or publish copy.
- Orientation must be recorded before assembly.
- `test-video-orientation-decision.ps1` must pass before assembly or draft QA.
- Follow the selected narration route. `existing-audio` accepts user-provided narration; a configured TTS adapter may generate narration; IndexTTS is required only when that route is explicitly selected.
- Do not reach a target duration by stretching TTS inter-segment silence. Use the largest stable text segment first and keep joins short; run `test-narration-pacing.ps1` and fail any pause above 0.9s unless a deliberate pause is documented.
- Dense videos longer than 20 minutes need a viewer-facing guide inside the opening section, normally immediately after the first hook and within 10-20 seconds. Do not delay it until 40 seconds or later unless the hook itself genuinely needs that long. Keep it to one short spoken sentence, tie the like/favorite ask to a concrete use case, and do not create a separate front bumper or replace the first screen unless the user explicitly asks for one.
- Reference audio must come from `config\tts.local.json` or an explicit command parameter. Keep the audio, hash, and voice identity out of Git.
- If the selected route lacks a required external tool, model, adapter, or reference file, stop and explain what is missing, what it is used for, where it can be obtained, and whether the download may execute third-party code. Ask the user before downloading, installing, or configuring it.
- Local timing stubs are invalid for review or final delivery. If a timing stub is used during exploration, mark it obsolete and return to this stage before assembly or QA.
- If the topic decision promises a concrete workflow or “一看就会”的 action, the script must either include one minimal input-to-acceptance example or explicitly narrow this episode to a thesis and name the follow-up example. Do not silently replace the promised example with task labels.

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-mainline-topic-decision.ps1 -Write
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\resolve-workflow-dependencies.ps1 -Stage ScriptTTS -TtsConfigPath .\config\tts.local.json
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-video-orientation-decision.ps1 -VideoDir <video-dir>
python .\scripts\verify-srt-timeline.py --audio <audio-path> --srt <srt-path>
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-narration-pacing.ps1 -AudioPath <audio-path> -ReportPath <review-report.md>
```

Use the current project TTS adapter only after confirming its expected input/output paths. In `existing-audio` mode, verify the supplied audio and matching SRT instead of running a TTS download or generation step.

## Outputs

- `draft\录音稿.txt`
- Audio file when generated.
- Same-content SRT or timeline package when generated.
- `draft\orientation-decision.json` and duration proof.
- Notes on locked phrases and removed production language.

## Completion Evidence

- `draft\录音稿.txt` exists and contains only viewer-facing narration.
- Style/humanize pass or explicit note explaining why it was not needed.
- `draft\orientation-decision.json` exists for standard video projects, with duration and dimensions.
- Final audio/SRT paths or a clear statement that audio/SRT is not part of this pass.
- Reference audio proof for generated narration: local config or explicit `-ReferenceAudio`, plus SHA256 when the project requires identity binding.
- If script changed after audio/SRT, evidence that audio/SRT was regenerated or marked obsolete.

## Failure Patterns

- Good planning language accidentally becomes narration.
- Captions or SRT no longer match the final audio.
- Abstract account thesis replaces the promised viewer deliverable.
- High-interest cases get weakened into abstract methodology. If the audience first cares about who/what + result + why it worked, start with the concrete hook, then prove and explain.
- Long-form dense scripts start like short clips and never tell the viewer how to use the episode or why it is worth saving.
- Ordinary-audience AI advice says “接一段任务” but never shows what the viewer should paste, ask for, receive, or verify.

## Handoff

Send `stage-material.md` the locked script, final audio/SRT paths, duration, orientation, evidence list, and any lines requiring specific proof or visual emphasis.
