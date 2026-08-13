# Zimeiti Video Production Pipeline

This file is the daily execution view for `zimeiti-video-workflow`. `SKILL.md` remains the router, this file maps the 10-step production line to the six stage references, and each `stage-*.md` owns the detailed rules.

## 10 Steps To 6 Stages

| Pipeline Step | Stage | Reference |
| --- | --- | --- |
| 选题 | Topic | `stage-topic.md` |
| 评分 | Topic | `stage-topic.md` |
| 脚本 | Script TTS | `stage-script-tts.md` |
| 素材 | Material | `stage-material.md` |
| visual plan | Material | `stage-material.md` |
| 组装 | Assembly | `stage-assembly.md` |
| 渲染 | Assembly | `stage-assembly.md` |
| QA | QA | `stage-qa.md` |
| 发布包 | Publish Wrap Up | `stage-publish-wrap-up.md` |
| 收尾 | Publish Wrap Up | `stage-publish-wrap-up.md` |

## Execution Rules

- Start with the smallest current stage. Do not read every stage by default.
- Use `docs\failure-pattern-index.md` for routing. Open matching sections in `docs\failure-patterns.md` only when triggered.
- Automated QA and human visual review are separate gates. A script pass is not a visual pass.
- A late failure returns to the owning stage instead of being patched in the current stage.
- Completion requires evidence: a file, command output, or an explicit human review record.
- Previous video learnings must enter the current project through `draft\production-carryover.md`. Keep it action-level: hook take-away, early proof, abstract-noun motion, invisible-mechanism process visuals, key-term/entity anchors, visual breathing, closing thesis, and publish-package closure. Do not paste old case names or old failure stories.
- Material follows a supply-first pause/resume contract: source real assets, audit coverage, prepare surplus still prompts for gaps, wait for user returns, inspect stills, then choose local or external motion. Assembly cannot start with `Material readiness` earlier than `complete`.
- JXFS experience capture sits outside this 10-step production line. It may record a problem, correction, external suggestion, or post-publish result at any time, but it cannot advance a stage or change workflow rules without a separate promotion review.
- Yufengshu is a conditional production-director branch inside the current owner stage, not a seventh stage. It may contribute `draft\production-director-plan.md` or `review\yufengshu-audit-vNN.md`, but the stage owner, project state, QA decision, and wrap-up remain here.

## Stage Selection Contract

- If `<video-dir>\project-state.json` exists, use its `currentStage`, `stageStatus`, `nextAction`, and `blockers` before reading historical status notes.
- A missing state file is a legacy condition. Infer the stage from concrete artifacts, then write the state with `scripts\update-video-project-state.ps1`.
- Automated QA PASS advances only to `QA / awaiting_human_review`.
- Only a render-bound `review\human-visual-review-vNN.md` PASS can advance to `ready_for_wrap_up`.

## Pipeline Contract

| Step | Input | Output | Mandatory Check | Human Review | Completion Evidence | Failure Returns To |
| --- | --- | --- | --- | --- | --- | --- |
| 选题 | User idea, daily signal, source lead | Candidate angle and viewer question | Topic rubric when applicable | Is the viewer benefit clear in one sentence? | Topic decision note or report with evidence list | Topic |
| 评分 | Candidate angle | Approved/rejected score and risk note | `run-mainline-topic-decision.ps1 -Write` when used | Does the angle avoid repeating an old conclusion? | Calibration score, hard-gate decision, failure-risk note | Topic |
| 脚本 | Approved topic, deliverable, evidence | `draft\录音稿.txt`, title/opening, duration target | Style/humanize pass; orientation decision check when project exists | Does the hook promise something the viewer can take away? | Locked script, removed-production-language note, `draft\orientation-decision.json` | Script TTS |
| 素材 | Locked script, evidence, orientation | Production carryover, Agent Reach source candidates, sentence-level timed map, fetched local assets, coverage audit | `new-video-source-candidates.ps1`, `test-video-material-mix.ps1` | Does every spoken sentence have a visual task, and which tasks remain uncovered after external/internal checks? | `production-carryover.md`, `source-candidates.md/json`, `material-beat-map.md`, Agent Reach route/query/timestamp evidence, `project-state.json` Material result | Material |
| visual plan | `LINE##` sentence map, fetched assets, internal inventory, named gaps | Surplus still prompt pack, exact user return path, still intake, post-intake HyperFrames/Jimeng/Grok decisions, motion intake | visual-task-v1; motion-job-v1.1; generated-material-readiness-v1; generated clips <=10s | Are there enough distinct usable options for risky beats, and was motion chosen from accepted images instead of assumed in advance? | `generated-motion-asset-plan.md` at `complete`; still prompt pack and `source-image-rename-map.md` when required; motion pack/intake when external motion is required | Material |
| 组装 | Script, audio/SRT, assets, visual plan | HyperFrames composition | `npm run check`; orientation check; `test-video-visual-task-coverage.ps1` for visual-task-v1 | Does every VT## visibly serve its LINE## instead of leaving meaning to subtitles? | Updated composition files, caption data, `visual-task-coverage.json`, assembly notes | Assembly |
| 渲染 | Composition and audio/captions | Render candidate | Project render command | Does the render candidate match intended frame and timing? | Render path, command output or status note | Assembly |
| QA | Render candidate and project evidence | Pass/fail decision | `run-video-draft-qa.ps1`, material check if needed | Frame inspection, subtitle timing, proof readability | `review\draft-qa-report.md`, `review\human-visual-review-vNN.md`, blocker list | Owning failed stage |
| 发布包 | QA-approved render, cover/copy inputs | Project `publish\` package | `invoke-video-wrap-up.ps1` when formal wrap-up is requested | Actual cover clickability and copy sincerity | Publish package, cover files, publish manifests, publish-copy review evidence | Publish Wrap Up or earlier owner |
| 收尾 | Publish package and sync targets | Waiting-publish/collection sync and status | Wrap-up script and sync manifest checks | Are exact final paths and skipped actions clear? | `收尾状态.md`, sync manifest, final response paths, cleanup/archive status | Publish Wrap Up |

## Evidence Minimums

- Topic/Script/Material may complete with one strong file evidence plus any required command result; Material also needs filled `draft\production-carryover.md`.
- Material assesses generated media only after the script is locked and fetched external/internal coverage is mapped to timed beats. Record `Generation branch: not-needed` plus `Material readiness: complete` as the exemption, or `required` with gap evidence. A required plan prepares minimum coverage plus `max(2, ceil(minimum * 20%))` alternate still prompts, pauses at the exact user-return folder, inspects and accepts `IMG##` files, then chooses HyperFrames/Jimeng/Grok per image. Only `Material readiness: complete` plus Material QA PASS can enter Assembly.
- Material uses `visual-task-v1`: every complete spoken sentence or semantic unit has a `LINE##` ID and one primary task from `prove / explain / analogize / transition / close`. Agent Reach discovery evidence must connect the query and selected source timestamp/region to that line. Subtitles follow narration only and never count as visual coverage.
- Assembly needs both build/render evidence and a note for manual visual inspection targets.
- `visual-task-v1` Assembly also needs `hyperframes-app\visual-task-coverage.json` covering every planned `VT##` and `LINE##`.
- QA needs automated QA evidence and a current-render `review\human-visual-review-vNN.md` validated by `test-video-human-visual-review.ps1`.
- Publish Wrap Up needs package paths, actual cover files, manifest/sync evidence, and cleanup/archive status.
