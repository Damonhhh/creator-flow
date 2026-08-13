# Stage: QA

## When To Use

Use this stage before first draft delivery, after any render revision, and before declaring a video ready for wrap-up or publishing.

## Read First

- `docs\failure-pattern-index.md` (QA: FP01, FP02, FP08, FP11-FP15, FP18, FP19, FP21-FP32); open matching details only when triggered.
- `references\stage-assembly.md`.
- The review standard in the host project's `AGENTS.md`, when present.

## Inputs

- Render candidate path.
- Video project directory.
- Script, audio, SRT, and caption data.
- Source candidates, material beat map, and assembly notes.
- Production carryover note showing how prior learnings entered this video.
- Optional `review\yufengshu-audit-vNN.md` as directing/audio/color review input; it is not the project QA decision.

## Actions

- Run the project draft QA script.
- Inspect the first visible frame, near 0.03s, around 3s, and several later proof/caption frames by eye.
- Inspect every scene at its full-entry or midpoint peak, not only at scene boundaries. Titles, chips, labels, proof cards, and captions often collide only after all entrance animations have completed.
- Check subtitle readability, timing drift, and whether captions match the final audio/script.
- Check that `draft\production-carryover.md` has no placeholders and that its concrete actions are visible in script, material plan, assembly, or publish handoff.
- Scan evidence cards, screenshots, and source boards for real readability.
- Compare `material-beat-map.md` with `visual-task-coverage.json` and sampled render frames. Confirm each planned `VT##` is present and that no narration section relies on subtitles plus generic texture alone.
- Look for blank media slots, missing CSS background media, static-card overholds, transition artifacts, production-label leakage, and audio problems.
- For high-density teardown videos, check whether mechanisms are visible as actions rather than static lecture cards, and whether major arguments have brief breathing points or visual resets.
- For technical explainers, check whether the viewer can see the mechanism happen: a state changes, a path connects, a term is highlighted, or an entity anchor appears when a company/tool/protocol is named.
- When the video promises ordinary viewers a concrete AI action, check whether they can identify what to paste, what to ask AI to return, and what the human must verify. Task names, gears, icons, captions, or a generic workflow diagram do not satisfy that promise alone.
- Check the final thesis beat when the script has a strong closing view. It should read as a deliberate ending, not a leftover summary slide.
- Record pass/fail with exact blocker paths and timestamps when possible.
- When Yufengshu audit is triggered, require every P0/P1/P2 finding to name its owner stage and evidence timestamp. Reconcile those findings into the normal QA blocker list; do not accept a Yufengshu report as automated QA or human-visual-review evidence.
- Save the accepted review as `review\human-visual-review-vNN.md`, keep the required marker names from `human-visual-review-pending.md`, and bind it to the candidate SHA256.

## Hard Gates

- A script PASS is not enough; representative frames must be inspected.
- Formal QA completion requires `test-video-human-visual-review.ps1` to pass for the exact render candidate.
- Repeated user-reported failures are hard gates, not taste notes.
- Inspect every transition at normal speed and with before/middle/after frames. Repeated bright flashes, exposed black frames, distracting ghosting, or subtitle double-images return to Assembly; a single boundary screenshot is not sufficient evidence.
- A scene-boundary sample cannot prove layout safety. Any overlap or occlusion at the scene midpoint/full-entry peak returns to Assembly even when the opening and boundary frames look clean.
- `run-video-draft-qa.ps1` blocks production-note leakage in `draft\录音稿.txt`, `hyperframes-app\captions-data.js`, and `hyperframes-app\index.html`.
- `run-video-draft-qa.ps1` blocks empty media `src`, missing local `video` / `img` assets, and timeline video clips whose source duration cannot cover the beat without handoff or explicit intentional still fallback.
- `run-video-draft-qa.ps1` blocks missing local media referenced by inline styles, `<style>` blocks, or local CSS background `url(...)` declarations.
- `run-video-draft-qa.ps1` blocks HDR/HLG/BT.2020 timeline video metadata and reports codec/keyframe preprocessing risks under `Warnings`.
- If subtitles are missing, stale, fake, unreadable, or desynced, return to assembly or script/TTS.
- If proof cannot be understood in under 2 seconds, rebuild the scene.
- If a key technical point is only spoken/subtitled and never visually anchored, return to Material or Assembly.
- If the topic/script promised a concrete workflow but the render only shows task labels or symbolic motion, return to Script TTS or Material even when visual-task coverage is technically complete.
- If carryover actions are only written in a note but not visible in the render or publish handoff, return to the owning stage.
- If final sync paths or required publish artifacts are missing, do not call it ready.

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-video-draft-qa.ps1 -VideoDir <video-dir>
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-video-material-mix.ps1 -VideoDir <video-dir>
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-video-visual-task-coverage.ps1 -VideoDir <video-dir>
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-video-human-visual-review.ps1 -VideoDir <video-dir> -VideoPath <render.mp4>
```

## Outputs

- `review\draft-qa-report.md`
- `review\human-visual-review-pending.md` after automated QA.
- `review\human-visual-review-vNN.md` after actual frame inspection.
- Capped frame evidence under `review\qa-frames-current\`, plus optional contact sheets.
- Pass/fail decision and blocker list.
- Exact return stage for each failure.
- Optional `review\yufengshu-audit-vNN.md` with severity, timestamp/shot, cause, correction, and owner stage.

## Completion Evidence

- Automated QA: `review\draft-qa-report.md` from `run-video-draft-qa.ps1`, including `Issues` and `Warnings`.
- Human Visual Review: `review\human-visual-review-vNN.md` contains PASS, current render SHA256, required visual checks, and paths to image evidence actually opened.
- Visual Task Review: `visual-task-v1` projects have a passing `hyperframes-app\visual-task-coverage.json`, and the human review records `Visual-task coverage` against actual render frames.
- Carryover Review: `draft\production-carryover.md` is filled and at least one visible/rendered or publish-package evidence item corresponds to each active rule.
- Subtitle/audio evidence when narration is present: SRT/ASR alignment report or manual timing note.
- Pass/fail decision with exact owning return stage for every blocker.
- QA is not complete if either automated QA or validated human visual review is missing. Automated PASS alone leaves `project-state.json` at `awaiting_human_review`.
- A Yufengshu audit may add blockers but cannot produce QA PASS, advance `project-state.json`, or replace the SHA-bound human review.

## Failure Patterns

- Tool QA passes while the actual frame is blank, cropped, or temporary-looking.
- Captions disappear under text-heavy scenes without an intentional plan.
- Evidence boards are visible but unreadable.
- Dense analysis is correct but feels like static图文: no click path, browse path, split-screen movement, quick switch, or breathing point between major claims.
- Technical explanation is accurate but visually inert: no state change, no highlighted key term, no entity anchor, and no closing thesis beat.
- The advice sounds actionable but the viewer never sees one complete input → instruction → output → acceptance example.
- A video card passes file checks but depends on an unmarked freeze frame, HLG/HDR source, or sparse keyframes.
- Wrap-up is attempted before QA and assets are package-ready.

## Handoff

If QA fails, return to the owning stage with exact blocker notes. If QA passes and the user says `收尾`, `可以发`, `准备发布`, or equivalent, send `stage-publish-wrap-up.md` the approved render, QA report, subtitle path, and cover/publish status.
