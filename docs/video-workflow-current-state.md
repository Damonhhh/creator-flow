# Video Workflow Current State

Status: active public baseline

## Authority

- Router: `.agents\skills\zimeiti-video-workflow\SKILL.md`
- Daily pipeline: `.agents\skills\zimeiti-video-workflow\references\pipeline.md`
- Stage rules: `.agents\skills\zimeiti-video-workflow\references\stage-*.md`
- Failure routing: `docs\failure-pattern-index.md`
- Detailed quality rules: `docs\failure-patterns.md`

Private production history is not a runtime dependency of this package.

## Stable baseline

- The end-to-end chain is routed through six stages: Topic, Script TTS, Material, Assembly, QA and Publish Wrap Up.
- Each video starts from the user's account profile, writing style, knowledge sources and source content.
- Topic candidates are scored before one topic advances.
- Final narration determines subtitle timing and orientation. Videos longer than 90 seconds default to horizontal; shorter videos default to vertical unless the project records an exception.
- Material planning maps each spoken line to one visible task and records source, timing, motion and fallback.
- Assembly records visual-task coverage rather than assuming that a file list proves coverage.
- Automated QA and human visual review are separate gates. The accepted human review is bound to the current render SHA256.
- Formal wrap-up requires the final render, subtitles when present, cover QA, publish copy and the publishing package.
- `project-state.json` is the machine-readable stage authority when present.

## Dependency behavior

- Core checks report missing dependencies without modifying the machine.
- External tools, providers, models and renderer scaffolds require explicit consent before download or installation.
- Project-owned scripts and contracts referenced by the public workflow are bundled in this repository.
- Local configuration stays in ignored `*.local.json` files created from public examples.

## Active backlog

- Deeper detection of rendered blank regions and frozen video frames.
- More automatic verification of planned motion jobs.
- More provider adapters only after repeated, portable use proves they belong in the public workflow.
