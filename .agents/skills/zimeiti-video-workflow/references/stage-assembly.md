# Stage: Assembly

## When To Use

Use this stage when building or revising the HyperFrames composition, captions, timeline, motion, media placement, or render candidate.

## Read First

- `docs\failure-pattern-index.md` (Assembly: FP01, FP02, FP04, FP10, FP11, FP13-FP15, FP18-FP21, FP23-FP28, FP32); open matching details only when triggered.
- `references\stage-material.md`
- Relevant HyperFrames skill when editing a HyperFrames app.
- `references\visual-task-coverage-contract.md` when the Material map declares `visual-task-v1`.

## Inputs

- Final script, audio, and verified SRT or segment data.
- Orientation decision and target dimensions, preferably `draft\orientation-decision.json`.
- `source-candidates.md`, `material-beat-map.md`, and local asset paths.
- Optional `draft\production-director-plan.md` when real shooting, sound design, or color constraints were approved in Material.
- Any external-tool handoff accepted into the project.

## Actions

- Build or update the composition using the recorded orientation.
- If the project has no renderer app, run `scripts\initialize-video-renderer.ps1` without `-AcceptDownload` first. Present its missing items, purpose, source, and proposed command; only rerun with `-AcceptDownload` after the user agrees. A custom renderer may be used when it satisfies the same project and QA contracts.
- If `draft\production-director-plan.md` exists, implement only the constraints owned by Assembly: accepted shot order, J/L-cut intent, track hierarchy, color/input notes, and export requirements. Return missing shots or unsupported source assumptions to Material instead of improvising around them.
- Run or rely on `test-video-orientation-decision.ps1` before changing the HyperFrames canvas.
- Rebuild captions from verified SRT/ASR data; do not hand-write a fake timing track.
- Keep captions narration-only. Source notes, proof labels, step names, visual explanations, and emphasis copy that the speaker did not say must be separate visual layers, not extra caption cues.
- Implement the `LINE## -> visual task -> asset` map. Each spoken sentence or semantic unit must be visibly served by its planned `prove`, `explain`, `analogize`, `transition`, or `close` task; subtitles and ambient backgrounds do not satisfy this requirement.
- Register every implemented `VT##` in `hyperframes-app\visual-task-coverage.json`, including covered `LINE##` IDs, actual timing, implementation description, and owning element or asset.
- Make the first visible 0-3 seconds carry a focal claim, proof, or motion.
- Keep the first visible 0-3 seconds low-density: one focal hook/thesis plus at most one support layer. Do not put multi-card explainers, checklists, process rows, disclaimers, and proof panels on screen at the same time; delay validation details until after the hook lands.
- Implement material motion jobs instead of leaving abstract nouns as static cards.
- Implement `motion-job-v1.1` fields literally: action, visible subject, state change, and fallback should all be visible in the plan or assembly notes.
- For technical explainers, implement the mechanism as an animated process, not a still lecture card: moving characters, state chips, connected nodes, dynamic chart bars, code/encoding lanes, or highlight sweeps are all acceptable HyperFrames treatments.
- Give key technical terms a visible emphasis moment through scale, glow, underline, focus ring, contrast, or short kinetic type. This emphasis should guide attention, not become a decorative text storm.
- If the script ends on a strong thesis, build a closing thesis beat: one full-screen sentence or compact phrase, strong hierarchy, short hold, and optional prepared/licensed audio hit. If no sound cue is ready, visual emphasis is enough.
- Keep evidence readable with contain framing, zoomed detail, or staged proof beats.
- For long-form videos, avoid a mono-grammar dashboard shell. Assign visible material to closed visual roles such as proof, mechanism, texture reset, and judgment; vary layout/scale by role while keeping typography, palette, captions, and badge language consistent.
- Treat a long-form viewing guide as narration by default. Keep the existing visual sequence moving underneath it and add only the normal subtitle treatment. Use a separate front bumper only when explicitly requested.
- Remove production labels, source-planning notes, and QA terms from visible UI.
- In rendered video compositions, do not lazy-load foreground `<img>` media. Use eager/synchronous image loading or equivalent preloading so evidence and generated stills do not appear late and create blank foreground windows.
- When using short motion clips, make the post-clip state explicit: freeze on the tail frame, hand off to another clip, or cover with a deliberate still. Do not let ended videos rebound to their first frame or disappear into an empty frame before the spoken beat ends.
- When a motion-required scene starts before its first Jimeng/Seedance clip, cover the pre-motion window with a deliberate visible still or other foreground asset, then fade it down before the motion starts. Do not let the main visual frame sit on only dark background, dots, route lines, or an empty frame while waiting for the clip.
- When using Jimeng, Seedance, or other returned motion clips, register them as real HyperFrames media elements. Runtime-created videos are not enough unless the render/inspect log proves they entered the timeline.
- Keep real media elements in the host root composition. Do not put `<video>` or `<audio>` assets inside HyperFrames sub-compositions just to reduce file size; current HyperFrames lint treats media in sub-compositions as non-seeked and render-risk/blank. Use sub-compositions only for non-media graphic structure, or keep media as direct root children with global timing.
- For `motion-required` Jimeng/Seedance clips, registration is not enough. The motion clip must be visible as the primary scene asset or a clear foreground evidence layer; static cards, fallback stills, board bodies, captions, or vignettes must not cover the motion.

## Hard Gates

- Caption timing must follow the real audio or verified SRT.
- Caption text must follow the spoken narration. Extra explanatory or production text in the caption track blocks assembly.
- A spoken line with only captions over a generic background is an uncovered visual task and returns to Material.
- A `visual-task-v1` project cannot enter draft QA until `test-video-visual-task-coverage.ps1` passes.
- If audio/SRT changes, rebuild captions before rendering again.
- Missing or contradictory orientation decision blocks assembly.
- A triggered Yufengshu plan cannot create a parallel timeline, label system, QA verdict, or delivery state; its constraints must be traceable in the existing assembly notes and project files.
- No blank media cards, empty slots, temporary labels, or unreadable proof boards.
- Every `video` / `img` media element must resolve to a real source; short clips need a visible handoff or an explicit intentional still fallback marker such as `data-intentional-still-fallback="true"` or `data-fallback="intentional-still"`.
- Short motion clips must not rely on browser default video-end behavior. If the spoken beat continues after the active window, use a tail-frame overlay, tail-frame clone pad, or another explicit end-state; verify at `videoEnd + 0.1s` and at least one later frame before the next scene or next motion clip.
- Motion-required scenes need visual coverage from scene start to scene end. For each scene, the main visual frame must be covered by at least one of: deliberate pre-motion still, active motion clip, tail-frame/end-state, next motion handoff, or explicitly approved static-support. Verify pre-motion windows, between-motion windows, and post-motion windows; a dark frame with only ambient dots/lines is a failed assembly.
- If external motion clips are used, the assembly review must name the `MOV##` clips and include render/inspect evidence such as `videoCount`. A project with expected motion clips and `videoCount:0` is a failed assembly, even if still images appear on screen.
- If external motion clips are marked `motion-required`, the assembly review must include visual-use evidence: at least three sampled frames or a contact sheet showing the motion clips are not buried behind static cards or proof boards. `videoCount > 0` without visible-use evidence is not a pass.
- Video sources should be HyperFrames-friendly before assembly: H.264, 30fps, yuv420p, SDR BT.709, with dense keyframes. Re-encode HLG/HDR/BT.2020, odd codec, or sparse-keyframe clips before render.
- CSS and inline background `url(...)` references must resolve to real local files before render.
- Opening frame cannot look like a raw shrunken webpage under a title.
- Long static cards need motion, highlight, zoom, intercut footage, or a second layer.
- Default to clean cuts. Use a transition only at a real chapter change or natural pause; prefer a 0.10-0.20 second dissolve. Do not use repeated full-screen bright, white, or amber overlays as routine transitions. If the active runtime cannot produce a clean result, switch to the approved editing toolchain instead of simulating the transition with more overlays.
- Long-form visual variety must reduce PPT fatigue without adding chaos: no new ad hoc styles per shot; use a small closed grammar system and verify role switching with a contact sheet.
- A long-form viewing guide must not become another explainer card or interrupt the hook. It should appear naturally inside the opening section after the hook lands, use the normal subtitle treatment, and preserve the established visual sequence.
- A technical mechanism section must show at least one visible state change or process path; a sequence of static term cards is a return-to-material failure.
- Closing thesis cards must not look like internal summary slides. They need one audience-facing sentence, clear focal hierarchy, and subtitle-safe placement.
- Scene order must match words such as first, second, then, finally.

## Commands

```powershell
cd <video-dir>\hyperframes-app
npm run check
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\initialize-video-renderer.ps1 -ProjectDir <video-dir>
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-video-orientation-decision.ps1 -VideoDir <video-dir>
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-video-visual-task-coverage.ps1 -VideoDir <video-dir>
python .\scripts\rebuild-hyperframes-captions-from-asr.py --video-dir <video-dir>
```

Use the render command already established in the project's `hyperframes-app` or status notes. Do not add `-AcceptDownload` until the user has approved the proposed external download.

## Outputs

- Updated `hyperframes-app\` composition files.
- `hyperframes-app\visual-task-coverage.json` for `visual-task-v1` projects.
- Caption data generated from verified timing.
- Render candidate in `review\`, `renders\`, or the project-specific output folder.
- Notes on any assembly fallback or blocked asset.

## Completion Evidence

- Updated composition files under `hyperframes-app\` or the active assembly surface.
- Caption data rebuilt from verified SRT/ASR timing when captions are present.
- `npm run check` or equivalent project check result.
- `test-video-visual-task-coverage.ps1` PASS or `not-applicable` result.
- Render candidate path or explicit blocker explaining why render did not run.
- Assembly note listing any intentional still fallback, unresolved asset, registered external motion clips, render/inspect `videoCount`, or beats that need manual QA inspection.

## Failure Patterns

- Script changes leave stale captions behind.
- Captions contain proof notes or explanations the speaker never said, while the planned visual task is missing.
- First frame has no readable center of attention.
- Evidence is visually present but not understandable.
- Motion jobs were planned but not implemented.
- Background media is referenced in CSS but not present on disk.
- A short foreground video relies on silent browser freeze instead of an explicit fallback marker.
- A motion clip ends by jumping back to its first frame instead of freezing on its tail frame.
- A motion clip ends and leaves the main visual area empty before the spoken beat or scene ends.
- A scene waits several seconds for its first motion clip and leaves the main visual area as only dark background, ambient dots, or route lines.
- Multiple motion clips are individually valid, but the gap before the first clip, between clips, or after the last clip is not covered by a deliberate visible asset.
- Jimeng/Seedance files exist in the project, but the render/inspect log shows they were not registered into the HyperFrames timeline.
- HyperFrames media assets were moved into sub-compositions for organization; lint reports `media_in_subcomposition`, and renders can go blank because the runtime only seeks host-root media.
- Jimeng/Seedance clips are registered, but CSS layering or large cards push them into the background so the viewer cannot see the motion as a real asset.
- A dense long-form video jumps straight into the body without a viewing contract, or adds a like/favorite ask that is disconnected from the viewer's use case.

## Handoff

Send `stage-qa.md` the render path, project directory, QA-relevant reports, caption/audio paths, and a short list of beats that need manual visual inspection.
