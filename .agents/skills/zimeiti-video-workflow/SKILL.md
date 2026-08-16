---
name: zimeiti-video-workflow
description: Use as CreatorFlow's core skill for video production stage routing, HyperFrames assembly, external editing-tool choice, QA, and wrap-up.
---

# CreatorFlow Video Workflow

## Purpose

This is CreatorFlow's project-level router. Use it whenever the task involves topic planning, scripting, TTS/subtitles, materials, assembly, QA, publishing packages, wrap-up, or choosing between HyperFrames and another compatible renderer.

This skill decides the production stage and the smallest reference slice needed for that stage. `references\pipeline.md` is the execution map.

## Read Order

Before real video work, read:

1. `AGENTS.md` when the host project provides one.
2. `docs\video-workflow-current-state.md` when changing the workflow itself.
3. `references\pipeline.md`.
4. `docs\failure-pattern-index.md`; open only matching sections from `docs\failure-patterns.md`.
5. The matching `references\stage-*.md` file.

For external editing tools, also read:

1. `docs\video-editing-skill-integration.md`

For scripts, titles, captions, covers, publishing copy, or other reader-facing text, also read:

1. The active project's `writing-style.md` and `account-profile.md`.
2. A final human-readable editing pass that removes formulaic AI phrasing without changing facts or locked wording.

## Stage Router

When a video project already exists, read `project-state.json` first when present. It is the machine-readable current-stage authority; `status.md` is supporting context. Then choose the smallest current stage and read that reference file completely before acting.

| Stage | Use When | Reference |
| --- | --- | --- |
| Topic | choosing, scoring, reframing, or rejecting a topic | `references\stage-topic.md` |
| Script TTS | writing spoken narration, public copy, TTS, SRT, or orientation decision | `references\stage-script-tts.md` |
| Material | sourcing proof/texture/explain assets, beat maps, motion jobs, tool handoffs | `references\stage-material.md` |
| Assembly | HyperFrames composition, captions, timeline, animation, render candidate | `references\stage-assembly.md` |
| QA | draft QA, frame inspection, subtitle/evidence/readability checks | `references\stage-qa.md` |
| Publish Wrap Up | covers, publish copy, final package, sync, `收尾`, `可以发`, `准备发布` | `references\stage-publish-wrap-up.md` |

If a late-stage failure clearly belongs to an earlier owner, return to that stage instead of patching symptoms.

For the full `选题 -> 评分 -> 脚本 -> 素材 -> visual plan -> 组装 -> 渲染 -> QA -> 发布包 -> 收尾` mapping, use `references\pipeline.md`.

## Production Director Branch

`yufengshu` is a conditional production-director branch, never a second router or stage. Use it only when the project involves real shooting, interviews, courses, product demos, on-set or multitrack sound, J/L-cuts, iPhone Log/RAW, LUT/color management, or an explicit directing/audio/color audit.

Do not invoke it for a pure HyperFrames faceless explainer, ordinary script polish, routine material search, standard draft QA, covers, publishing copy, or wrap-up. When triggered, it may write only:

- `draft\production-director-plan.md` for plan/shoot/edit;
- `review\yufengshu-audit-vNN.md` for audit.

It never updates `project-state.json`. Every finding must name the owning return stage, and all labels must map into the project's existing visual-task and material-role vocabulary.

## External Tool Router

Default formal production uses HyperFrames and project scripts. External editing tools are sandbox helpers until their outputs are imported into a `zimeiti` video project and pass project QA.

- Use OpenMontage for provider/capability preflight, sourcing experiments, Remotion/HyperFrames comparisons, or reusable video-tooling patterns.
- Use OpenStoryline for natural-language rough cuts, ASR-based speech edits, subtitle imitation, style imitation, transition-heavy recuts, or user-provided editing sessions.
- Use OpenCut only when the user asks for manual timeline editor exploration, UI/editor comparison, or future MCP/plugin/headless research.

Any external output entering a project needs `draft\external-tool-handoff.md` or an entry in `draft\visual-plan\material-beat-map.md` with tool, source, input, output, provenance, dimensions/duration when relevant, role, and next action.

## Missing Dependency Recovery

Treat repository scripts and contracts as part of this skill package; do not ask the user to download files that the repository itself should contain. For an external command, model, renderer, TTS/ASR system, provider adapter, or uploader that is not available:

1. Stop the affected route without pretending it passed.
2. Tell the user exactly what is missing, what it enables, the official source, the proposed command, and any third-party code or credential risk.
3. Offer an existing supported fallback when one exists, such as `existing-audio`, a verified SRT, static/local motion, or another renderer.
4. Ask for explicit consent before downloading, installing, signing in, or configuring credentials.
5. After consent, perform only the approved setup, rerun capability detection, and record the result. Without consent, preserve the project and report the blocked stage.

At the start of `ScriptTTS`, `Material`, and `Assembly`, run `scripts\resolve-workflow-dependencies.ps1` for that stage. Its default mode only detects and proposes; it never downloads. Show the returned purpose, official source, command, scope, risk, remaining work, and fallback. After the user approves one exact action, rerun with that single `-AcceptAction`, then rely on the script's post-action recheck. Never infer approval for a second action, a model download, a login, or credential setup.

Use `scripts\test-workflow-capabilities.ps1` for the broad Core/Full report. `scripts\initialize-video-renderer.ps1` remains the Assembly implementation behind the resolver. Agent Reach is preferred for Material discovery but is not a global hard dependency; missing Agent Reach degrades Material to installed routed tools, browser research, or user-provided assets. `existing-audio` similarly keeps Script TTS usable without installing IndexTTS.

## Hard Gates

- `run-video-draft-qa.ps1` is mandatory before first draft delivery.
- Script PASS is not enough; inspect representative frames by eye and save the accepted result as `review\human-visual-review-vNN.md` bound to the current render SHA256.
- Captions must come from final audio/SRT timing, not hand-written fake timelines.
- Mainline videos need `draft\web-assets\source-candidates.md` and `draft\visual-plan\material-beat-map.md` unless explicitly exempted.
- `visual-task-v1` projects need `hyperframes-app\visual-task-coverage.json` to cover every planned `VT##` before draft QA.
- Formal wrap-up must use `scripts\invoke-video-wrap-up.ps1` or `zimeiti-video-wrap-up`.
- Never copy secrets, cookies, auth headers, or API keys into docs, prompts, publish packages, or chat.

## Key Commands

Video draft QA:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-video-draft-qa.ps1 -VideoDir .\videos\YYYY-MM-DD-short-name
```

Material mix check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-video-material-mix.ps1 -VideoDir <video-dir>
```

Orientation decision check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-video-orientation-decision.ps1 -VideoDir <video-dir>
```

HyperFrames project check:

```powershell
cd <video-dir>\hyperframes-app
npm run check
```

Renderer setup proposal (no download):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\initialize-video-renderer.ps1 -ProjectDir <video-dir>
```

Stage dependency proposal (no download):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\resolve-workflow-dependencies.ps1 -Stage Material
```

Video wrap-up:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-video-wrap-up.ps1 -VideoDir <video-dir> -Collection <collection-name>
```

Human visual review validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-video-human-visual-review.ps1 -VideoDir <video-dir> -VideoPath <render.mp4>
```

## Completion Standard

When using this router, report:

- selected stage and branch;
- exact files changed or produced;
- exact source and output paths;
- commands run and whether they passed;
- QA or validation result;
- completion evidence used for the current stage;
- any skipped stage, test, render, or tool branch and why.
