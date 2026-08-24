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
- Topic selection begins with `topic-from-signal.md`, not with title generation or Rubric scoring. It must read the matching account-level topic profile and latest calibration snapshot, then classify each candidate as `reuse / repair / explore`. Historical performance is decision evidence, not another weighted score and not a veto on exploration.
- Material follows a supply-first pause/resume contract: source real assets, audit coverage, prepare surplus still prompts for gaps, wait for user returns, inspect stills, then choose local or external motion. Assembly cannot start with `Material readiness` earlier than `complete`.
- Publish Wrap Up follows `publish-copy-v1`: read the approved final script/render, define the viewer promise, compare at least 8 title candidates across 4 angle families, continue the selected promise through body and first comment, then bind the plan and independent scorecard to both source files by SHA-256. Wrap-up also compares the render with `latest-render.json` and `qa-stamp.json`; it validates and syncs that work instead of inventing a last-minute topic-summary title.
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
| 选题 | Raw signal, source evidence, matching account profile, latest account calibration | Raw-information card and 1-3 distinct candidate angles with demand evidence, creator qualification, concrete payoff, mission, portfolio role, and `reuse / repair / explore` relation | Three topic gates from `topic-from-signal.md`; separate reach/account-value potential | Does this solve a real viewer problem, fit the account's proven strengths, and leave a verifiable payoff? | Topic decision note with evidence list, historical metrics, commercial-input status, and comparable works or exploration hypothesis | Topic |
| 评分 | Candidate that passed the pre-score gates | Approved/rejected score, mission-matched success metric, and risk note | `validate_topic_decision.py`; `run-mainline-topic-decision.ps1 -Write` when used | Are the candidates genuinely different, and is the high score backed by evidence rather than complete-looking language? | Validator PASS, calibration score, Rubric hard-gate decision, history relation, failure-risk note, and human lock | Topic |
| 脚本 | Approved topic, deliverable, evidence | `draft\录音稿.txt`, title/opening, duration target | Style/humanize pass; orientation decision check when project exists | Does the hook promise something the viewer can take away? | Locked script, removed-production-language note, `draft\orientation-decision.json` | Script TTS |
| 素材 | Locked script, evidence, orientation | Production carryover, Agent Reach source candidates, sentence-level timed map, screen-owner plan, fetched local assets, coverage audit | `new-video-source-candidates.ps1`, `test-video-material-mix.ps1`, `test-video-screen-ownership.ps1` | Does every spoken sentence have a visual task, and does the right owner carry the question, proof, explanation, or real action? | `production-carryover.md`, `source-candidates.md/json`, `material-beat-map.md`, Agent Reach route/query/timestamp evidence, `project-state.json` Material result | Material |
| visual plan | `LINE##` sentence map, fetched assets, internal inventory, named gaps | Screen-owner handoffs, presenter-led mixed-media modes, surplus still prompt pack, exact user return path, still intake, post-intake HyperFrames/Jimeng/Grok decisions, motion intake | visual-task-v1; screen-owner-v1; presenter-led-mixed-media-v1; motion-job-v1.1; generated-material-readiness-v1; generated clips <=10s | Are there enough distinct usable options, and do talking presenter, proof, real scenes, kinetic images, and optional AIGC perform different duties instead of becoming another deck? | `material-beat-map.md` owner/mode fields; `generated-motion-asset-plan.md` at `complete`; still prompt pack and intake records when required | Material |
| 组装 | Script, audio/SRT, assets, visual plan | HyperFrames composition | `npm run check`; orientation check; `test-video-screen-ownership.ps1`; `test-video-visual-task-coverage.ps1` | Does every VT## visibly serve its LINE##, and does Assembly preserve the planned `primaryOwner`? | Updated composition files, caption data, `visual-task-coverage.json`, assembly notes | Assembly |
| 渲染 | Composition and audio/captions | Render candidate | Project render command | Does the render candidate match intended frame and timing? | Render path, command output or status note | Assembly |
| QA | Render candidate and project evidence | Pass/fail decision | `run-video-draft-qa.ps1`, material check if needed | Frame inspection, subtitle timing, proof readability | `review\draft-qa-report.md`, `review\human-visual-review-vNN.md`, blocker list | Owning failed stage |
| 发布包 | QA-approved render, final script/transcript, cover inputs, account/platform constraints | Viewer brief, 8+ candidate / 4+ angle title matrix, selected promise, final title/body/comment/tags, independent scorecard, project `publish\` package | `test-video-publish-copy.ps1`; `invoke-video-wrap-up.ps1` when formal wrap-up is requested | Does the title create an honest reason to watch, does the video repay it, and do body/comment add value without giving the whole answer away? | `draft\publish-copy\publish-copy-plan.json`, fresh `review\publish-copy-scorecard-vNN.json`, final copy files, cover files, publish manifests | Publish Wrap Up; Script TTS if the finished video has no defensible payoff |
| 收尾 | Publish package and sync targets | Waiting-publish/collection sync and status | Wrap-up script and sync manifest checks | Are exact final paths and skipped actions clear? | `收尾状态.md`, sync manifest, final response paths, cleanup/archive status | Publish Wrap Up |

## Evidence Minimums

- Topic needs one strong decision file plus any required command result. For AI mainline topics, that file records the raw fact and evidence boundary, account profile, one to three distinct viewer questions, demand evidence, remove-the-hot-name result, creator qualification, incremental value, payoff type, verifiable payoff and fulfillment point, content mission, portfolio role, commercial-input status, one to three comparable works or an explicit exploration hypothesis, at least one historical metric, changed judgment, separate reach/account-value potential, success metric, failure signal, three topic-gate results, and human decision. Only approved and human-locked topics hand off to Script TTS. Script/Material may complete with one strong file evidence plus any required command result; Material also needs filled `draft\production-carryover.md`.
- Material assesses generated media only after the script is locked and fetched external/internal coverage is mapped to timed beats. Record `Generation branch: not-needed` plus `Material readiness: complete` as the exemption, or `required` with gap evidence. A required plan prepares minimum coverage plus `max(2, ceil(minimum * 20%))` alternate still prompts, pauses at the exact user-return folder, inspects and accepts `IMG##` files, then chooses HyperFrames/Jimeng/Grok per image. Only `Material readiness: complete` plus Material QA PASS can enter Assembly.
- Material uses `visual-task-v1`: every complete spoken sentence or semantic unit has a `LINE##` ID and one primary task from `prove / explain / analogize / transition / close`. Agent Reach discovery evidence must connect the query and selected source timestamp/region to that line. Subtitles follow narration only and never count as visual coverage.
- New standard AI/business explainers also use `screen-owner-v1` inside the same beat map. Decide `PERSON / EVIDENCE / EXPLAINER / SCENE` before choosing the asset, record the handoff reason and PERSON-return rule, and validate without imposing fixed shot durations. Digital-human ownership remains a downstream layout mapping, not a competing universal contract.
- The account's default presenter-led AI/business videos additionally use `presenter-led-mixed-media-v1`: speaking PERSON video leads; official proof/Demo, real footage, kinetic images, and necessary AIGC/animation take over according to duty; `support-card` stays a bridge. This is a media grammar layered under screen ownership, not a fixed sequence or shot-duration template.
- Assembly needs both build/render evidence and a note for manual visual inspection targets.
- `visual-task-v1` Assembly also needs `hyperframes-app\visual-task-coverage.json` covering every planned `VT##` and `LINE##`; when `screen-owner-v1` applies, each task also declares matching `primaryOwner`.
- QA needs automated QA evidence and a current-render `review\human-visual-review-vNN.md` validated by `test-video-human-visual-review.ps1`.
- Publish Wrap Up needs package paths, actual cover files, manifest/sync evidence, and cleanup/archive status. Formal public copy additionally needs `publish-copy-v1`: a final-script viewer brief, at least 8 non-synonymous title candidates across at least 4 angle families, selected-title traceability, body/comment continuation, and a fresh independent scorecard whose script/render hashes match the plan, actual files, and current render/QA manifests. A handwritten `PASS`, a named writing skill, or a declarative topic summary is not completion evidence.
