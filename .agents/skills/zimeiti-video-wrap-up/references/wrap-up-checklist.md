# Wrap-Up Checklist

Trigger phrases: `收尾`, `收尾吧`, `收尾收尾`, `就这样吧`, `停在这版`, `可以发`, `准备发布`.

This skill means: stop iterating creatively and complete the publishing handoff. It does not mean "summarize the current draft."

## Principle

收尾不是补课。收尾只验证已完成产物，并把同一版交付物同步到发布位置。缺产物就中断，回到对应阶段。

The optimized wrap-up path should normally take minutes, not a full production turn.

## Preferred Fast Path

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-video-wrap-up.ps1 -VideoDir <video-project-dir> -Collection <collection-name>
```

Use `-RunQa` only when the current requested version needs QA and the user has explicitly asked to finish that version now.

Use `-DryRun` when changing the script or testing a project shape:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-video-wrap-up.ps1 -VideoDir <video-project-dir> -Collection <collection-name> -DryRun
```

## Preflight

Before calling wrap-up done, the project must already have these package-ready artifacts:

1. Final MP4:
   - preferred: `publish/成片.mp4` or `publish/最终成片.mp4`;
   - fallback: latest approved file in `final/` or `review/`.
2. QA:
   - `review/draft-qa-report.md` or `publish/draft-qa-report.md`;
   - report must contain `PASS`.
3. Subtitles, when narration/subtitles exist:
   - `publish/字幕.srt`, or the latest approved display/realigned SRT;
   - no mojibake-like replacement characters.
4. Covers:
   - vertical cover under `publish/`, exactly `1080x1920`;
   - horizontal cover under `publish/`, preferably native `4:3`;
   - cover source note in `publish/封面图.md`;
   - visual QA record in `review/cover-qa-vNN.md`.
5. Publishing package:
   - `publish/标题.md`
   - `publish/正文.md`
   - `publish/封面文案.md`
   - `publish/封面图.md`
   - `publish/标签.md`
   - `publish/首评.md`
   - `publish/平台说明.md`
   - `publish/发布检查清单.md`
   - `publish/发布包.md`
6. Publishing-copy pass:
   - required for formal public videos with title/body/comment/tag copy;
   - production plan: `draft/publish-copy/publish-copy-plan.json`;
   - independent review: `review/publish-copy-scorecard-vNN.json`;
   - both records bind the final script and approved render by path plus SHA-256;
   - both must pass `scripts/test-video-publish-copy.ps1` using the pattern configured in `config/publish.local.json`;
   - a skill name, upstream diagnosis, or handwritten PASS marker does not replace this contract.

If any of these are missing, do not pretend wrap-up is complete. Finish that stage first, then rerun the fast path.

## Cover Visual QA

Cover QA is not the same as dimensions passing.

Before running the fast path, open the actual vertical and horizontal PNG files and write `review/cover-qa-vNN.md`. The record must state:

- final status: PASS or FAIL;
- which files were opened;
- which checks from `cover-system.md` were applied;
- whether the cover works at phone-feed thumbnail size;
- whether the base image is current-topic generated art or an explicitly approved reusable series asset;
- whether any candidate was rejected for looking like a grid, panel, PPT card, abstract icon, reused old hero image, or yesterday's cover with changed text.

Do not let `publish/` become a staging folder. Extra source MP4s, old source backgrounds, temporary thumbnails, and rejected cover candidates should not be synced as publish artifacts.

## Publishing Copy Pass

This pass turns the video package from "artifact summary" into public-facing copy. Read `zimeiti-video-workflow\references\publish-copy-contract.md` first.

Before running the fast path, inspect the publish files. If the title, body, first comment, tags, or `发布包.md` read like an internal production summary, or if no configured review record exists, run the copy pass first.

Build `draft/publish-copy/publish-copy-plan.json` from the final script/render. Its `source` object must include both paths and their current SHA-256 values. It must also contain the viewer brief, at least 8 title candidates across at least 4 angles, the scored selection, body continuation, and a concrete first-comment question. Apply the active project's `account-profile.md` and `writing-style.md`, then perform a final `$humanize-writing` pass.

Update or verify:

- `publish/标题.md`
- `publish/正文.md`
- `publish/首评.md`
- `publish/标签.md`
- `publish/发布包.md`

Write `review/publish-copy-scorecard-vNN.json` after the final files, with:

- independent review method and reviewer;
- exact selected title ID and title text;
- `sourceBinding` repeating the exact final script/render paths and hashes reviewed;
- body continuation/value, first-comment value, voice, and platform scores;
- all factual, payoff, continuation, humanize, and platform hard checks set from real review.

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-video-publish-copy.ps1 -VideoDir <video-project-dir>
```

The validator also requires the render hash to match `review/latest-render.json` and `review/qa-stamp.json`. If the script or render changed after review, regenerate the plan hashes and scorecard instead of carrying the old copy forward.

This is allowed during wrap-up only as a missing publishing-package stage. Do not use it to reopen the video edit, rerender, rewrite the script, or change the cover unless the user explicitly asks for that stage.

## Script Outputs

The fast path writes or updates:

- `review/latest-render.json`: final video path, probe data, SHA-256.
- `review/qa-stamp.json`: QA PASS tied to the final video hash.
- `publish/publish-manifest.json`: final package manifest.
- `publish/sync-manifest.json`: sync destinations and hashes.
- `publish/收尾状态.md`: human-readable status.

These files are the default source of truth for later inspection. Prefer reading them over re-scanning a whole project tree.

## Sync Requirements

The same version must be synced to:

- project `publish/`;
- the waiting-publish destination configured in `config/publish.local.json`;
- the collection destination configured for the selected collection;
- each enabled platform destination.

The example configuration enables no platform destinations. Add only the platforms the local account actually uses.

Do not sync `published-to-*.json` files into waiting-publish packages. Those are post-publish markers, not pre-publish deliverables.

## Avoid Slow Paths

- Do not recursively scan the entire video project unless there is no other way.
- Do not use broad `Get-ChildItem -Recurse` across `hyperframes-app`; bad Windows output paths can create `hyperframes-app\ ..` style loops.
- Prefer explicit paths and manifest files.
- Do not regenerate covers, rewrite captions, or rerender video during wrap-up unless the user has explicitly asked for that missing stage.

## Final Reply

Final reply must include:

- final video path;
- vertical cover path;
- horizontal cover path;
- publish package path;
- publish-copy plan and scorecard paths;
- waiting-publish directory;
- skipped items and reasons.

Never claim "收尾完成" if any required item is missing.
