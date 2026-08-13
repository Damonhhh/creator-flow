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
- a passing publishing-copy review record matching `config\publish.local.json`.

## Publishing Copy Gate

Before the fast path, verify that the project publishing copy is not only present, but actually written for public distribution.

For public-facing videos, review the copy against the active project's `account-profile.md` and `writing-style.md`. Check that the title opens a real question, the body makes one useful point, the first comment adds value, and the tags match the actual subject. Finish with a human-readable editing pass; do not invent facts to make the copy sharper.

This gate updates or verifies at least:

- `publish\标题.md`
- `publish\正文.md`
- `publish\首评.md`
- `publish\标签.md`
- `publish\发布包.md`

Record the invocation in:

`review\publish-copy-pass-vNN.md`

The record must name:

- `status: PASS`;
- a non-empty `method:` describing how the review was done;
- previous copy problem;
- final recommended title and first comment;
- files updated;
- boundary: whether MP4/SRT/covers/QA were unchanged.

Upstream planning notes do not replace the downstream publish-copy pass. The publish package itself must show the conversion from diagnosis into public title, body, comment, and tag copy.

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
5. If publishing copy exists but has no configured publish-copy pass, perform that review first, write `review\publish-copy-pass-vNN.md`, then run the fast path.
6. If the script fails, fix the named missing artifact or explain the blocker. Do not fall back to slow manual directory spelunking unless the script does not support this project shape.
7. Reply only after paths are verified. Include final video, vertical cover, horizontal cover, publish package, waiting-publish directory, publish-copy record, and any skipped item with reason.

## Series Exception

For a high-frequency series, an existing approved series cover may be reused only when the project records that decision in `收尾状态.md`. Reuse does not waive the final video, subtitles when present, QA, publish package, or configured sync requirements. If one cover variant is intentionally skipped, record the variant and reason.
