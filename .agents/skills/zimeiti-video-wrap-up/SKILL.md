---
name: zimeiti-video-wrap-up
description: Use for zimeiti video wrap-up. Trigger whenever the user says "收尾", "收尾吧", "就这样吧", "停在这版", "可以发", "准备发布", or asks to finish a video project. Executes the publishing handoff with the fast wrap-up script when possible.
---

# Zimeiti Video Wrap-Up

## Rule

When this skill triggers, do not answer with only the final MP4 path. Treat the request as a command to finish the publishing handoff.

Wrap-up is not a place to do late creative work. The default rule is:

> 收尾不是补课。收尾只验证已完成产物，并把同一版交付物同步到发布位置。缺产物就中断，回到对应阶段。

## Read First

Read these files before executing:

1. `references/wrap-up-checklist.md`
2. `docs\cover-system.md`

Then execute against the active `videos\YYYY-MM-DD-short-name` project.

## Fast Path

Prefer the script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-video-wrap-up.ps1 -VideoDir <video-project-dir> -Collection <collection-name>
```

Use this fast path when the project already has:

- a final MP4;
- a passing QA report;
- subtitles when the project has narration/subtitles;
- vertical and horizontal covers in `publish/`;
- a complete `publish/` package;
- a passing `publish-copy-v1` plan and scorecard matching `config\publish.local.json`.

## Publishing Copy Gate

Before the fast path, verify that the project publishing copy was produced from the final video rather than improvised during sync.

Follow `zimeiti-video-workflow\references\publish-copy-contract.md`. Create a viewer brief from the final script/render, generate and score at least 8 titles across at least 4 real angles, select one promise the video repays, then make the body and first comment continue that same line. Finish with the account style and `$humanize-writing`; do not invent facts to make the copy sharper.

This gate updates or verifies at least:

- `publish\标题.md`
- `publish\正文.md`
- `publish\首评.md`
- `publish\标签.md`
- `publish\发布包.md`

Record the production and independent review in:

- `draft\publish-copy\publish-copy-plan.json`
- `review\publish-copy-scorecard-vNN.json`

The scorecard must name:

- `status: PASS`;
- a non-empty review `method` and `reviewer`;
- the exact selected title ID and final title;
- the final script/render paths and SHA-256 values under `sourceBinding`;
- body, first-comment, voice, and platform scores;
- the factual, payoff, continuation, humanize, and platform hard checks required by the contract.

Run `scripts\test-video-publish-copy.ps1`. Its PASS proves that the structured review exists and that the plan, scorecard, actual script/render, `latest-render.json`, and `qa-stamp.json` share the same source binding; it does not replace editorial judgment.

The script verifies the artifacts, writes machine-readable state, syncs the publish folder, and returns the final paths.

It writes or updates:

- `review/latest-render.json`
- `review/qa-stamp.json`
- `publish/publish-manifest.json`
- `publish/sync-manifest.json`
- `publish/收尾状态.md`

## Required Behavior

1. Identify the current video project and collection.
2. If the project is already package-ready, run `invoke-video-wrap-up.ps1`.
3. If QA is missing or stale, run QA first only when the user has clearly asked to finish this exact version. Otherwise stop and report the missing QA stage.
4. If cover files or publishing copy are missing, do not silently invent a low-quality shortcut inside wrap-up. Complete the missing stage first, then rerun the fast path.
5. If publishing copy exists but has no passing `publish-copy-v1` plan/scorecard, return to Publish Wrap Up copy production, finish those artifacts, then run the fast path.
6. If the script fails, fix the named missing artifact or explain the blocker. Do not fall back to slow manual directory spelunking unless the script does not support this project shape.
7. Reply only after paths are verified. Include final video, vertical cover, horizontal cover, publish package, waiting-publish directory, publish-copy record, and any skipped item with reason.

## Series Exception

For a high-frequency series, an existing approved series cover may be reused only when the project records that decision in `收尾状态.md`. Reuse does not waive the final video, subtitles when present, QA, publish package, or configured sync requirements. If one cover variant is intentionally skipped, record the variant and reason.
