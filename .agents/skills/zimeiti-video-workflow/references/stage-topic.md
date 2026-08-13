# Stage: Topic

## When To Use

Use this stage when choosing, scoring, or reframing a video topic. This includes daily AI topics, X Following leads, one-off user ideas, evergreen tools, and mainline topic decisions before scripting.

## Read First

- `docs\failure-pattern-index.md` (Topic: FP09, FP17); open matching details only when triggered.
- The active project's `account-profile.md` and `knowledge-sources.md`.
- `examples\ai-mainline-topic\rubric.example.json` when starting without a private scoring rubric.
- Latest daily report, signal brief, or user source for this topic.

## Inputs

- Candidate topic, signal source, or user request.
- Account lane and recent three comparable videos.
- Evidence or source links that make the topic timely.
- Any required viewer-facing deliverable, such as a card, checklist, prompt, map, or case.

## Actions

- State the viewer question in one sentence.
- Decide whether this is front-stage value or only internal workflow talk.
- Score the topic with the project calibration rubric when it is an AI mainline video.
- Name the strongest reason it might fail, then revise or proceed.
- Preserve concrete deliverables from source reports instead of compressing them into abstract labels.

## Hard Gates

- A topic below 7.5, or one that triggers a rubric hard gate, must be rewritten before recording.
- Do not approve a topic just because it confirms the account thesis.
- The title and first sentence must make a stranger know why it matters.
- A "hot" item cannot be used only to prove an old conclusion.
- Internal workflow, creator reflection, or backend process cannot lead unless the audience benefit is obvious in one sentence.

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-ai-daily-briefing-chain.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-ai-daily-topic-chain.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-mainline-topic-decision.ps1 -Write
```

## Outputs

- Approved or rejected topic decision.
- Calibration score and failure-risk note.
- Viewer-facing deliverable statement.
- Evidence list and source paths.
- Handoff note for script stage.

## Completion Evidence

- Topic decision file or report with approved/rejected state.
- Rubric score, hard-gate result, and strongest failure-risk note when this is an AI mainline topic.
- Evidence/source list that supports timeliness or viewer usefulness.
- Viewer-facing deliverable statement in one sentence.

## Failure Patterns

- Weak topic caused by abstract account thesis instead of viewer value.
- Repeating the same conclusion with a different news hook.
- Back-stage production language leaking into the public angle.

## Handoff

Send `stage-script-tts.md` the approved angle, viewer question, deliverable, evidence list, rubric score, and any phrases that must be preserved or avoided.
