# Stage: Publish Wrap Up

## When To Use

Use this stage when producing covers, publishing copy, final package files, sync manifests, or when the user says `收尾`, `停在这版`, `可以发`, or `准备发布`.

## Read First

- `docs\failure-pattern-index.md` (Publish Wrap Up: FP05-FP07, FP12, FP22); open matching details only when triggered.
- Use the cover-system document routed by the active wrap-up Skill for the current package.
- `references\publish-copy-contract.md`.
- `.agents\skills\zimeiti-video-wrap-up\SKILL.md`.
- The active project's writing-style file and a final human-readable editing pass for public copy.

## Inputs

- QA-approved final render.
- QA report and frame-inspection evidence.
- Final script or transcript used by the approved render.
- Final subtitles when present.
- Cover source assets, title, body copy, tags, first comment, and collection name.

## Actions

- Verify or create vertical and horizontal covers through the cover system.
- Write or verify `review\cover-qa-vNN.md` for the final cover set. This record must name the cover system checks, thumbnail check, visual pass/fail decision, and rejected alternatives when relevant.
- Build `draft\publish-copy\publish-copy-plan.json` from the final script/render: viewer brief, at least 8 title candidates across at least 4 angles, scored selection, body continuation, and a substantive first-comment question.
- Write the final title, body, first comment, tags, and package from the selected promise. Run the project style layer and `humanize-writing` after the content decision, not instead of it.
- Perform a separate final-copy review and write `review\publish-copy-scorecard-vNN.json` with the exact final script/render paths and SHA-256 values under `sourceBinding`.
- Run `scripts\test-video-publish-copy.ps1` before formal wrap-up.
- Ensure final MP4, subtitles, covers, title/body/tags/comment, QA proof, and manifests are package-ready before formal wrap-up.
- Invoke the project wrap-up script or `zimeiti-video-wrap-up` skill.
- Verify project `publish\`, waiting-publish, collection, and platform sync paths.

## Hard Gates

- 收尾不是补课：final MP4, QA, subtitles, covers, and copy should already be ready or explicitly repaired here.
- A formal public package must satisfy `publish-copy-v1`: complete viewer brief, diverse title matrix, selected title traceability, body/comment continuation, and a fresh independent scorecard. Plan and scorecard hashes must match the actual script/render; the render must also match `latest-render.json` and `qa-stamp.json`. A skill name or handwritten `PASS` marker is not completion evidence.
- The selected title must be the first visible title in `publish\标题.md`, score at least 24/30, and keep both factual fidelity and script payoff at 4/5 or above.
- A title may be declarative, but a topic summary with no audience stake, unresolved question, or promised takeaway fails. The body cannot merely restate that summary, and the first comment cannot be only `你怎么看`.
- A production-director “发布前审片” record is advisory input only. It cannot replace cover QA, publish-copy review, automated QA, SHA-bound human visual review, package manifests, sync, or `zimeiti-video-wrap-up`.
- A random screenshot is not a cover system output.
- Cover visual QA must inspect the actual PNG at phone-feed thumbnail size.
- A cover drawn only by local scripts with grids, panels, abstract icons, or generic tech shapes is not acceptable even when dimensions pass.
- Do not reuse yesterday's hero image or repeat the same hero metaphor, corridor/gate/door shape, red-X signal, focal composition, or color-emotion package unless the series asset was explicitly approved for reuse. Ask: would the viewer feel this is yesterday's cover with changed text?
- `publish\` must not become a staging folder. Extra source MP4s, old source backgrounds, thumbnails, or temporary cover files can leak into waiting-publish sync and must be kept out of the synced package.
- Formal wrap-up requires the latest `review\cover-qa-vNN.md` to PASS; dimensions alone are not visual QA.
- Formal wrap-up requires `review\human-visual-review-vNN.md` to PASS `test-video-human-visual-review.ps1` for the exact final render SHA256.
- Missing publish package files, manifest, QA proof, or sync targets block completion.
- Do not paste cookies, tokens, or account secrets into packages or chat.
- A-share Xiaohongshu workflows stop at publish-ready assets unless explicitly told otherwise.
- 视频号上传前必须把标题和短标题里的标点符号去掉；正文可以保留正常标点。不要把带 `？`、`！`、`：`、`，`、`、`、引号、书名号等符号的标题直接传给视频号。

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-video-wrap-up.ps1 -VideoDir <video-dir> -Collection <collection-name>
```

Platform-specific metadata preparation and upload are optional adapter steps, not part of the core workflow. Before using an adapter, explain which tool or account authorization is needed and why. Install, download, sign in, or upload only after the user explicitly agrees.

## Outputs

- `publish\` package with final MP4, subtitles when present, covers, and publishing copy.
- `publish\publish-manifest.json`
- `publish\sync-manifest.json`
- `收尾状态.md` or equivalent wrap-up status.
- Synced files in `videos\00-最终输出\03-待发布\...`, collection, and platform folders when required.

## Completion Evidence

- Project `publish\` folder contains final MP4 reference, subtitles when present, actual cover image files, title/body/tags/comment, and platform notes.
- `publish\publish-manifest.json` and `publish\sync-manifest.json` exist or the blocker is recorded.
- Latest `review\cover-qa-vNN.md` exists, is PASS, and records actual PNG + thumbnail inspection.
- Latest `review\human-visual-review-vNN.md` exists, is PASS, cites opened frame evidence, and matches the final render SHA256.
- `draft\publish-copy\publish-copy-plan.json` and the latest `review\publish-copy-scorecard-vNN.json` pass `test-video-publish-copy.ps1` against the exact final script, render, title/body/comment/tag/package files, plus the current render and QA manifests.
- Actual vertical and horizontal cover files were opened or checked at platform thumbnail size.
- Waiting-publish or collection sync paths are verified, or skipped platform actions are named explicitly.
- Cleanup/archive status is recorded. If cleanup is deferred, state whether it is `pending-preview`, `pending-manual-confirmation`, or `blocked`.

## Failure Patterns

- Render success or QA pass is mistaken for delivery completion.
- Cover files exist only as notes, not actual checked PNGs.
- Publish copy leaks internal production rules.
- Final files are present in the project but not synced to waiting-publish or collection paths.

## Handoff

Final response must state exact final/review path, QA report path, publish package path, sync status, commands run, and any platform action deliberately skipped.
