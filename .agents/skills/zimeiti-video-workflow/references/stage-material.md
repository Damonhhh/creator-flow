# Stage: Material

## When To Use

Use this stage after the spoken script is locked and before assembly, when the video needs screenshots, video clips, product footage, diagrams, Xiaohei illustrations, generated images, or source candidates. Start by checking whether external footage and existing internal assets cover the timed spoken beats. Material is a supply stage: finish the search, coverage audit, surplus still generation, still intake, and motion intake before Assembly. Enter generated media only for named gaps that would otherwise become repetitive cards, generic screenshots, or empty explanation beats.

## Read First

- `docs\failure-pattern-index.md` (Material: FP03, FP04, FP14, FP18, FP20, FP23, FP30); open matching details only when triggered.
- `docs\video-editing-skill-integration.md`.
- `references\stage-script-tts.md`.
- The installed search or media skill chosen for the source channel, when one exists.
- A production-director skill only for real shooting, interviews, courses, product demos, on-set sound, or color workflows.

## Inputs

- Locked script, audio/SRT, and orientation from `stage-script-tts.md`.
- Evidence list and source links.
- Brand or lane visual constraints.
- Existing project `assets\`, `draft\web-assets\`, and `draft\visual-plan\` folders.
- Any user-provided external-generation folders for still images, motion clips, or returned downloads.

## Actions

- Run `scripts\resolve-workflow-dependencies.ps1 -Stage Material` before external search. If Agent Reach is absent, show its user-scoped installation proposal and ask before running it. If the user declines, continue through an installed routed tool, browser research, or user-provided assets and mark the discovery route as degraded.
- Create or update `draft\web-assets\source-candidates.md` and `draft\visual-plan\material-beat-map.md`.
- Run Material in this order: `source search -> coverage audit -> still prompt pack -> user still handoff -> still intake -> motion decision -> motion intake -> material-ready`. Do not collapse these into one speculative visual plan.
- Build the beat map from the locked script and real audio/SRT timing when available. Give every complete spoken sentence or semantic unit a stable `LINE##` ID and one primary visual task: `prove`, `explain`, `analogize`, `transition`, or `close`.
- Treat “one spoken sentence, one visual task” as a coverage rule, not a forced cut rule. Two short consecutive sentences may share one task only when they describe the same visible subject/action and both map to the same task ID and time window. One task may use several layers or assets, but every sentence must be traceable to a primary task.
- Keep material roles separate from visual tasks. Continue tagging sources as `prove / explain / advance / texture`; map visual tasks as follows: `prove -> prove`, `explain/analogize -> explain`, `transition/close -> advance`. `texture` is an auxiliary layer and cannot be the only visual task for a spoken sentence.
- Use the Agent Reach skill as the default external-material discovery router. Build each search query from the spoken subject, the visual task, and the visible action/state needed on screen. Search the original/first-hand source first; use Agent Reach's search, video, social, or web route according to the platform.
- Check Agent Reach channel availability before promising a source. If the `agent-reach` wrapper is unavailable, call the routed tools that are actually installed, such as Exa through `mcporter`, GitHub CLI, or a supported platform CLI. Record unavailable channels and the fallback instead of inventing a result.
- For each accepted external candidate, record `LINE##`, spoken time, visual task, search query, Agent Reach route/command, source URL, matched subject/action, useful source timestamp or page region, rights/provenance risk, local path, and fallback. Topic relevance alone is not enough; the selected shot must visibly match the spoken sentence.
- Audit material coverage in this order: external first-hand/proof footage, existing internal reusable assets, generated stills, then external image-to-video. Record uncovered beats and the risk of falling back to cards before writing prompts. Fetch and locally inspect real candidates before declaring the gap.
- Audit screen-time repetition, not only file count. Record every primary asset's number of uses, cumulative primary seconds, longest continuous hold, and the semantic beats it serves. For a 60-90 second vertical video, the normal planning range is 12-18 distinct primary scenes, with a new shot or true state change about every 4-6 seconds. A crop, caption change, local zoom, or new label over the same base image does not count as a new scene.
- Create or update `draft\visual-plan\generated-motion-asset-plan.md` when the coverage audit finds gaps that need generated stills, Jimeng/Seedance clips, local MiniMax H3 clips, the third-party Grok-compatible route, or user-side asset generation. New projects use `generated-material-readiness-v1` and advance through `sourcing / prompt-pack-ready / awaiting-user-stills / stills-received / motion-planned / motion-ready / complete`. If generation is not needed, record both `Generation branch: not-needed` and `Material readiness: complete` as exemption evidence.
- When stills are required, write the complete copyable `draft\visual-plan\still-image-prompt-pack.md` before pausing. It must name the exact return directory `assets\generated\incoming\`, stable expected filenames such as `IMG01-hook.png`, the beat/task served, and an acceptance check. Tell the user the absolute return path in the handoff.
- Plan a surplus, not just the minimum. The default prompt count is minimum coverage plus `max(2, ceil(minimum * 20%))`; use the extra prompts as genuinely different alternatives for the hook and key mechanism scenes. A crop or cosmetic recolor is not an alternate.
- Pause at `awaiting-user-stills` after the prompt-pack handoff. Assembly remains blocked. When files return, inspect every image, record accept/reject decisions in `source-image-rename-map.md`, and copy accepted canonical files to `assets\generated\accepted\` before selecting motion routes.
- Inspect returned stills with a bounded visual-intake protocol. First collect filenames, dimensions, hashes, and file sizes without emitting binary data. Then generate labeled contact sheets with at most 12 stills per sheet, longest edge no greater than 2400 px, and JPEG quality around 80; inspect those sheets at normal/high detail. Open an original image only when the contact sheet leaves a named ambiguity, one image per tool call. If the source is larger than 4 MB, crop or resize the disputed region before inspection instead of returning the full original.
- Never batch multiple original-resolution images into one model tool result. Do not serialize `image_url`, data URLs, or base64 image payloads through `text(...)`, JSON, shell output, or another wrapper. Keep contact-sheet calls to at most three sheets and split the intake across turns when needed. The goal is to inspect every image while keeping each continuation request small enough to upload reliably.
- Decide motion only from accepted stills. Use HyperFrames for deterministic zoom, mask, route, highlight, parallax, and sequential reveal; use Jimeng, local MiniMax H3, or the third-party Grok-compatible route only for a named natural or generative state change. Do not animate every still.
- Create a motion prompt pack only after still intake. A pre-intake exception is allowed only for a named source-image-free generation route with an explicit reason; Jimeng/Grok image-to-video is not such an exception.
- Create or update `draft\production-carryover.md`; translate previous production learnings into concrete actions for this video without naming old cases.
- When the Yufengshu branch triggers, write `draft\production-director-plan.md` and map every shot responsibility into this stage's existing visual-task and material-role vocabulary. `情绪` is auxiliary `texture`; `补充` cannot independently cover a spoken line.
- Tag every planned asset as `prove`, `explain`, `advance`, or `texture`.
- Build `draft\visual-plan\material-beat-map.md` against the spoken beats.
- Assign a motion job to every core noun or abstract concept: enter, split, route, compress, connect, verify, fail, resolve, compare, highlight, or transform.
- For new standard projects, write that action inside the beat map's Motion column as `motion job: <action>; subject: <visible object>; change: <from state -> to state>; fallback: <fallback plan>`.
- For high-density account/case teardown videos, plan visual rhythm explicitly: click/browse paths, user filtering, paid-entry movement, split-screen swaps, quick switching, or short visual resets between major arguments.
- For technical explainers, turn invisible mechanisms into visible process simulation: character/state changes, encoded/decoded flows, before/after lanes, dynamic charts, or step highlights. Do not leave a core mechanism as only a term card.
- For an ordinary-user AI micro-example, map the promised task as visible states: raw input, exact instruction, returned structure, and human acceptance. Prefer a real or clearly labeled simulated workflow over symbolic gears or generic icons; symbolic motion is `texture`, not the primary `explain` layer.
- When a company, model, protocol, or tool is named, plan an entity anchor: official/source screenshot, approved logo asset, product UI, repository page, or a neutral text badge fallback with provenance. Entity anchors support recognition; they do not replace proof.
- Mark one or two key technical terms and the final thesis as visual anchors in the beat map, so Assembly knows which words need emphasis, zoom, highlight, or full-screen closing treatment.
- Use real product/event/source imagery for proof beats; use generated or illustrated assets for explanation only when they serve the idea.
- Subtitles follow only the final narration and verified SRT/ASR timing. They do not count as a visual task and must not carry source notes, proof labels, visual instructions, or extra explanation that the speaker did not say. Put those items in separate visual layers.
- Record external tool outputs with provenance and whether they are raw material, rough cut, evidence, texture, or final candidate.
- Use external editing tools only for a named HyperFrames shortfall from `docs\video-editing-skill-integration.md`: raw footage understanding, rough cutting, reference/style analysis, real-footage sourcing, natural montage, transition generation, provider testing, or editing-skill extraction.
- Give every generated still a stable ID such as `IMG01-hook-name`, a target beat, a material role, and `pending-after-intake` before it returns. After visual intake, replace that status with `motion-required`, `local-motion`, `static-support`, or `reject` and name the owner.
- Give every motion clip a stable ID such as `MOV01-hook-name`, its source still ID/path, target duration, visible action, end-state, and fallback. Mark which clips must be generated in Jimeng/Seedance or local MiniMax H3 and which should be animated locally in HyperFrames.
- Keep each Jimeng/Seedance clip within 10 seconds. Default to 4-6 seconds and one visible action. If a beat needs more than 10 seconds, split it into multiple shots or use a short generated clip followed by a local motion/tail-frame handoff.
- A configured third-party motion provider may replace the default route for a named `MOV##` experiment. Record the provider, expected cost, duration/action/end-state/fallback contract and request metadata. Ask for permission before installing a client, downloading a model or starting a billable generation request.
- For returned user-generated stills and motion clips, write rename/intake evidence before assembly. Typical files are `draft\visual-plan\source-image-rename-map.md`, `draft\visual-plan\source-motion-rename-map.md`, and `draft\visual-plan\motion-video-intake.md`.
- Keep raw generated stills, raw motion clips, cache copies, and source backgrounds out of `publish\`. Only final video, final subtitles, final covers, publishing copy, QA, and manifests belong in the publish package.

## Hard Gates

- Pexels-style texture alone cannot pretend to be proof.
- Every `LINE##` spoken sentence or semantic unit needs one primary visual task: `prove`, `explain`, `analogize`, `transition`, or `close`. Unmapped narration blocks Material completion.
- Two sentences may share a visual task only when the beat map names the shared task ID, continuous time window, and same visible subject/action. Do not reuse a generic shot merely because both sentences mention the same topic.
- Subtitles are not material coverage. A sentence with only subtitles and a generic background is still missing its visual task.
- A mainline video must have `source-candidates.md` and `material-beat-map.md` unless the workflow explicitly exempts it.
- A mainline video must have `draft\production-carryover.md` filled with this video's hook take-away, first proof, abstract-noun motion, invisible-mechanism process visuals, key-term/entity anchors, visual rhythm, closing thesis, and publish-package closure actions. Keep the 8 template marker lines verbatim and fill each with this video's concrete action; TODO/TBD or other placeholders block material QA.
- `test-video-material-mix.ps1` blocks abstract core terms or explain beats that only declare labels/cards and do not declare a semantic motion job.
- `test-video-material-mix.ps1` treats projects with `draft\orientation-decision.json` as strict mode: explain or abstract beats must include a `motion job:` statement in the Motion column.
- `motion-job-v1.1` beat maps require explain or abstract beats to include `motion job`, `subject`, `change`, and `fallback` fields.
- `test-video-material-mix.ps1` rejects untouched TODO/TBD placeholder rows from the generated beat-map template.
- Static screenshots held longer than about 4 seconds need staged beats, zoom, highlight, or a second layer.
- A base asset should serve one continuous semantic beat. Reusing it later as a different semantic beat is blocked unless the beat map marks an intentional callback, keeps the callback normally under 2.5 seconds, and explains why recognition is more valuable than a fresh shot. For 60-90 second videos, cumulative primary use above about 8 seconds needs an explicit exception; repeated captions or local motion do not justify the exception.
- Dense teardown scenes cannot rely only on static multi-card boards for mechanisms such as screening, layering, entering, subscribing, or returning. Show a path or state change.
- Technical mechanism scenes cannot rely only on static labels. The beat map must show what changes on screen, what entity anchors appear, and which key phrase is visually emphasized.
- If Script TTS promises a concrete AI work example, Material cannot reduce it to a task-name list, gears, icons, or generic office B-roll. The primary explain layer must show the input, instruction, output, and acceptance state or return to Script TTS to narrow the promise.
- Unreadable screenshots cannot be used as proof cards.
- Every imported external asset needs source, license/provenance, path, dimensions, and next action.
- External sourcing for a standard project must show Agent Reach routing evidence in `source-candidates.md`: the line/time served, query, route or command, source URL, useful timestamp/region, semantic alignment note, and fallback. If a channel is unavailable, record the failed preflight and next route.
- External tool branches must name the shortfall they solve and the artifact they return. If the issue is only plain motion graphics, charts, key-term emphasis, entity badges, or closing thesis cards, solve it in HyperFrames instead.
- A prompt list alone is not a material plan. Generated stills and motion clips need beat mapping, IDs, provenance, local paths, and acceptance checks.
- A required generated-media branch cannot enter Assembly while `Material readiness` is `sourcing`, `prompt-pack-ready`, `awaiting-user-stills`, `stills-received`, `motion-planned`, or `motion-ready`. Only `complete` passes Material QA.
- A still prompt pack is incomplete unless it states the exact return folder, exact `IMG##-slug.ext` filenames, minimum count, surplus count, beat/task mapping, prompt text, and per-image acceptance check.
- A required plan that only covers the minimum image count is under-supplied. Add at least `max(2, ceil(minimum * 20%))` alternate prompts and assign them to the highest-risk scenes.
- Motion-provider decisions made before still inspection are blocked unless the plan records a valid source-image-free exception. Returned images may change which composition is worth animating.
- `motion-required` without a provider choice is blocked. HyperFrames owns deterministic `local-motion`; generative motion must name Jimeng/Seedance, local MiniMax H3, or the third-party Grok-compatible route.
- Do not write generated-media prompts before the spoken script is locked and the timed material coverage audit is filled. The generation branch needs a named uncovered beat and a cardification risk or a visible mechanism that existing material cannot express.
- Generated stills must be usable scene material, not poster designs with large AI-generated typography. Text, labels, and UI overlays belong to HyperFrames unless the source is real and readable.
- Image-generation cache outputs must be copied into the project only after visual inspection. Do not assume "newest file in the generated image cache" is the right asset.
- Still intake is blocked if the inspection method batches original-resolution images or returns base64/data URLs as text. Re-run intake through labeled contact sheets and single-image exception checks before continuing.
- Jimeng/Seedance motion prompts must request a stable final tail frame or explicit end-state. Do not rely on browser/video defaults that may rebound to the first frame.
- Jimeng/Seedance prompts longer than 10 seconds block Material completion.
- A third-party clip without provider provenance, request metadata, cost acknowledgement and a durable submission ledger blocks formal intake. An ambiguous submission must not be repeated until the user approves the possible duplicate charge.
- If a raw generated asset or extra MP4 appears in `publish\`, stop and return to material/publish hygiene before wrap-up sync.

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\new-video-source-candidates.ps1 -VideoDir <video-dir>
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\resolve-workflow-dependencies.ps1 -Stage Material
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-video-material-mix.ps1 -VideoDir <video-dir>
ffprobe -hide_banner <media-path>
```

Use `-Force` only to refresh source-candidate markdown/json. Use `-ForceBeatMap` only when deliberately replacing an existing filled beat map.
Use `test-video-material-mix.ps1 -NoStateUpdate` only for regression/audit checks where the current project stage must remain untouched. Omit it during active production so PASS/FAIL updates `project-state.json`.

## Outputs

- `draft\web-assets\source-candidates.md`
- `draft\web-assets\source-candidates.json`
- `draft\production-carryover.md`
- `draft\visual-plan\material-beat-map.md`
- `draft\visual-plan\generated-motion-asset-plan.md` with the coverage decision when the generation branch is assessed; a `not-needed` decision may stop after the coverage audit.
- `draft\visual-plan\still-image-prompt-pack.md` with an exact return path, stable filenames, and surplus alternatives when still generation is required.
- Copyable motion-video prompt pack only after accepted still intake when external motion is required.
- `assets\generated\incoming\` for user returns and `assets\generated\accepted\` for inspected canonical stills.
- `draft\visual-plan\source-image-rename-map.md`, `draft\visual-plan\source-motion-rename-map.md`, or `draft\visual-plan\motion-video-intake.md` when returned assets are imported.
- Sibling generation and submission metadata for third-party provider experiments; retain it as provenance and billing-safety evidence, and keep it out of `publish\`.
- Optional `draft\visual-plan\xiaohei-illustration-plan.md`
- Optional `draft\production-director-plan.md` when the Yufengshu branch is triggered.
- Optional `draft\external-tool-handoff.md`
- Asset files copied or generated into the project folder.

## Completion Evidence

- Filled `draft\production-carryover.md` with no TODO/TBD placeholders.
- `draft\web-assets\source-candidates.md` and, for standard projects, `source-candidates.json`.
- `draft\visual-plan\material-beat-map.md` with each beat assigned a material role and fallback.
- A screen-time repetition budget listing distinct primary-scene count, distinct motion-source count, per-asset use count, cumulative seconds, longest hold, and any intentional callback exception.
- Every spoken `LINE##` maps to one primary visual task, exact time window, material path/candidate, and fallback; shared tasks are explicitly named.
- Agent Reach search evidence records the actual available route and why the chosen shot matches the spoken subject/action, including a useful timestamp or page region when available.
- Subtitle planning points only to final narration/SRT; non-spoken proof labels and explanatory text are assigned to separate visual layers.
- `draft\visual-plan\generated-motion-asset-plan.md` records `not-needed` or `required` and a valid `Material readiness` state. A required branch includes uncovered beats, external/internal coverage evidence, cardification risk, minimum/surplus counts, and post-intake motion decisions.
- The still prompt pack has stable `IMG##` IDs, exact filenames, complete prompts, acceptance checks, and at least the required surplus. The user handoff names the absolute return folder.
- Prompt packs and intake records preserve stable `IMG##` / `MOV##` IDs and distinguish external motion from HyperFrames local animation.
- Every Jimeng/Seedance prompt is 10 seconds or shorter, defaults to one 4-6 second visible action, and includes a stable end-state plus fallback.
- Returned generated assets are renamed into project `assets\` folders with provenance and dimensions/duration recorded.
- Required generated branches reach `Material readiness: complete`; every earlier readiness state leaves `project-state.json` at `Material / blocked` with the exact user or production next action.
- `test-video-material-mix.ps1` result or explicit exemption note.
- `project-state.json` records `Material / complete` after material QA PASS, or `Material / blocked` with exact issues after FAIL.
- `motion-job-v1.1` fields for explain or abstract beats: action, subject, change, fallback.
- For technical explainers, at least one mechanism beat has a visible process simulation, and key term / entity / closing thesis anchors are assigned or explicitly exempted.
- For ordinary-audience action advice, the promised micro-example has an explicit input/instruction/output/acceptance map, or the project records that this episode is thesis-only and routes the example to a named follow-up.
- Local asset paths and provenance for every imported external asset.
- Motion clip intake includes `ffprobe` result or an explicit blocker. Tail-frame or end-state risk is recorded for assembly.
- Third-party motion intake confirms one approved submission per `MOV##`, a matching submission ledger, request-ID reuse for resumes, and an explicit approval reason for any additional billable attempt.
- When Yufengshu is triggered, `draft\production-director-plan.md` names shooting/audio/color constraints and maps each accepted shot duty into the existing beat map; the branch does not update project state.

## Failure Patterns

- Decorative stock footage replacing evidence.
- Agent Reach searches only the topic name, returning vaguely related B-roll that does not match the sentence's visible subject or action.
- Several narration sentences ride over the same generic background while subtitles do all the explanatory work.
- Source screenshots are cropped, unreadable, or held too long.
- Abstract terms become static text cards instead of motion jobs.
- Technical terms and company names appear only in subtitles/cards, with no process visualization or entity anchor.
- Scene order ignores the spoken workflow order.
- Generated image prompts are not tied to spoken beats or material roles.
- Generated prompts are written before checking external footage and internal reusable assets, so generation replaces sourcing instead of filling a known timeline gap.
- Motion-generation tasks are not marked, so the user returns stills without knowing which ones needed video.
- Returned generated assets keep random names, making assembly and QA unable to trace them.
- Raw prompt/source assets leak into `publish\` and get synced as stale thumbnails or extra deliverables.
- A 502 or missing request ID is treated as proof of failure and the same MOV is blindly POSTed again, even though the intermediary may already have accepted and billed the first request.
- Returned stills are opened in large original-resolution batches, creating tens of megabytes of tool output; the next Codex continuation request then fails with `408 Request body read timed out` before Material intake can finish.

## Handoff

Send `stage-assembly.md` the `LINE## -> visual task -> asset` map, Agent Reach source evidence, local asset paths, motion jobs, orientation, captions/audio paths, and any known fallback needs. Captions remain narration-only; separate proof labels and visual overlays travel with the visual task.
