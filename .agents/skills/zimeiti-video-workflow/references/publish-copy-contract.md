# Publish Copy Contract v1

## Purpose

This contract owns the public title, body, first comment, and tags inside the existing Publish Wrap Up stage. It prevents a QA-approved video from falling back to a topic-summary title or an improvised body during wrap-up.

The production order is:

`final script/render -> viewer brief -> title matrix -> selected promise -> body/comment continuation -> humanize -> independent review -> wrap-up`

Wrap-up validates and syncs these artifacts. It does not invent the first plausible title at the last minute.

## Required Inputs

- QA-approved render and its final script or transcript.
- Active `account-profile.md` and `writing-style.md`.
- The actual platform target and its title/body constraints.
- Source-backed facts, evidence, and factual boundaries already established by the video.

## Required Artifacts

Every formal public package using `publish-copy-v1` must contain:

- `draft\publish-copy\publish-copy-plan.json`
- `review\publish-copy-scorecard-vNN.json`
- `publish\标题.md`
- `publish\正文.md`
- `publish\首评.md`
- `publish\标签.md`
- `publish\发布包.md`

The plan and scorecard are small machine-readable records. Do not create separate title, body, and comment planning documents unless a project genuinely needs them.

`source.script` and `source.qaApprovedRender` must point to files inside the current video project. The plan must also record their exact `scriptSha256` and `qaApprovedRenderSha256`. `source.accountProfile` and `source.writingStyle` may point either to project-local files or to shared rules inside the `zimeiti` repository. Arbitrary external paths do not pass.

The newest `review\latest-render.json` and `review\qa-stamp.json` must describe the same render hash before copy review starts. Replacing either the script or render invalidates the plan and scorecard; regenerate the hashes and review the copy again.

## Step 1: Build The Viewer Brief

Read the final script and render. Fill the `brief` object with:

- `platforms`: where this copy will be used;
- `audience`: the actual viewer, not a broad demographic label;
- `viewerMoment`: the situation in which this topic matters to them;
- `subject`: the concrete event, test, workflow, product, or problem;
- `coreFact`: the strongest supported fact or observed result;
- `evidence`: one or more script/render/source anchors supporting that fact;
- `tension`: what remains unresolved, surprising, costly, or worth checking;
- `audienceStake`: what the viewer may gain, lose, avoid, or decide;
- `promisedTakeaway`: what the viewer can carry away after watching;
- `payoffInVideo`: where the video actually repays that promise;
- `factualBoundary`: what the package must not overclaim.

If these fields cannot be filled from the finished video, return to Script TTS. Title tricks cannot repair a video with no viewer payoff.

## Step 2: Generate A Title Matrix

Generate at least 8 genuinely different candidates across at least 4 angle families. Do not create eight synonym swaps.

Useful angle families include:

- `concrete-result`: a tested result, number, or visible change;
- `contradiction-change`: two facts that do not comfortably fit together;
- `cost-risk`: the mistake, hidden cost, or decision risk;
- `opportunity-action`: what the viewer can do with the change;
- `question-mystery`: a real unanswered question the video resolves;
- `how-to-deliverable`: a concrete method, checklist, map, or artifact;
- `named-event-consequence`: a named event followed by its viewer consequence.

Each candidate needs:

- stable `id`, such as `T01`;
- `angle`;
- final-readable `text`;
- `promise`: what clicking is supposed to deliver;
- `curiosityGap`: what remains worth watching;
- one or more `evidence` anchors;
- six 1-5 scores: `hook`, `concreteness`, `audienceStake`, `curiosity`, `factualFidelity`, `payoffMatch`.

The selected title must score at least 24/30, with both `factualFidelity` and `payoffMatch` at 4 or above. Scores are editorial evidence, not objective truth. A reviewer must still reject unsupported, stale, formulaic, or off-account copy.

A declarative title is allowed. It fails only when it merely reports the topic or gives away the whole conclusion without a viewer stake or remaining question.

## Step 3: Continue The Same Promise

After choosing a title:

- The body opening continues the same tension or viewer stake.
- The body gives one concrete fact, distinction, scene, or decision aid.
- The body does not repeat the title in longer words or summarize every payoff before the viewer watches.
- The first comment adds a usable action, diagnostic choice, example, or boundary.
- The first comment asks one question a viewer can answer from their own situation. Generic prompts such as `你怎么看` or `评论区聊聊` do not pass.
- Tags describe the real subject. They do not introduce a broader trend the video did not establish.

Run the active account style first, then `$humanize-writing`. For this project, `dbs-content` may diagnose the viewer takeaway, `dbs-hook` may challenge hook strength, and `dbs-spread` may clarify audience emotion. `dbs-xhs-title` is a Xiaohongshu adapter, not the default title engine for every platform.

## Step 4: Independent Review

Write `review\publish-copy-scorecard-vNN.json` only after the final publish files exist. The review should be a separate pass from first-draft generation whenever possible.

The scorecard must record:

- `status: PASS`;
- a non-empty `method` and `reviewer`;
- exact `selectedTitleId` and `finalTitle`;
- `sourceBinding` with the exact script/render paths and both SHA-256 values copied from the reviewed plan;
- five 1-5 scores: `bodyContinuation`, `bodyConcreteValue`, `firstCommentValue`, `voiceFit`, `platformFit`;
- all hard checks below as `true`:
  - `sourceFactsVerified`
  - `titlePromisePaidOff`
  - `titleDoesNotSpoilEntirePayoff`
  - `bodyContinuesSameLine`
  - `bodyAddsConcreteValue`
  - `firstCommentAddsNewValue`
  - `firstCommentQuestionIsAnswerable`
  - `humanizeWritingApplied`
  - `platformConstraintsChecked`

Every final score must be 4 or above. A low score must produce `FAIL` and a return to Publish Wrap Up copy production, not a ceremonial PASS.

## Machine Boundary

`scripts\test-video-publish-copy.ps1` can verify artifact completeness, candidate diversity, score ranges, title selection consistency, final-file freshness, and declared hard checks. It cannot prove that a title will earn clicks or that a paragraph feels sincere.

Human/LLM review owns semantic judgment. The machine gate owns whether that judgment was performed against the exact final files. It calculates both source hashes again, compares the plan and scorecard bindings, checks the render against `latest-render.json` and `qa-stamp.json`, and includes the script/render in scorecard freshness checks.

## Plan Shape

```json
{
  "schemaVersion": "publish-copy-plan-v1",
  "source": {
    "script": "draft/final-script.md",
    "scriptSha256": "64_HEX_CHARACTERS",
    "qaApprovedRender": "publish/成片.mp4",
    "qaApprovedRenderSha256": "64_HEX_CHARACTERS",
    "accountProfile": "account-profile.md",
    "writingStyle": "writing-style.md"
  },
  "brief": {
    "platforms": ["wechat-channels"],
    "audience": "...",
    "viewerMoment": "...",
    "subject": "...",
    "coreFact": "...",
    "evidence": ["..."],
    "tension": "...",
    "audienceStake": "...",
    "promisedTakeaway": "...",
    "payoffInVideo": "...",
    "factualBoundary": "..."
  },
  "titleCandidates": [],
  "selection": {
    "selectedTitleId": "T01",
    "reason": "...",
    "rejectedRisks": ["..."]
  },
  "bodyPlan": {
    "openingJob": "...",
    "concreteValue": "...",
    "videoReason": "..."
  },
  "firstCommentPlan": {
    "addedValue": "...",
    "answerableQuestion": "..."
  }
}
```

The matching scorecard includes:

```json
{
  "schemaVersion": "publish-copy-scorecard-v1",
  "status": "PASS",
  "sourceBinding": {
    "script": "draft/final-script.md",
    "scriptSha256": "64_HEX_CHARACTERS",
    "qaApprovedRender": "publish/成片.mp4",
    "qaApprovedRenderSha256": "64_HEX_CHARACTERS"
  }
}
```

## Handoff

Do not call the package ready until:

1. the selected candidate is the first visible title in `publish\标题.md`;
2. the final body and first comment follow the plan, and `publish\发布包.md` contains the exact selected title plus the final standalone body and first comment;
3. the latest scorecard is newer than the plan, final copy files, final script, and approved render;
4. plan and scorecard hashes match the actual script/render, and the render also matches `latest-render.json` plus `qa-stamp.json`;
5. `test-video-publish-copy.ps1` passes;
6. `invoke-video-wrap-up.ps1` records the structured contract in the publish manifest.
