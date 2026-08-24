# Screen Ownership Contract

`screen-owner-v1` is the upstream narrative contract for AI, business, case-teardown, and presenter-led explainers. It answers **who owns the frame and is responsible for the current meaning** before Material asks which asset matches a sentence.

For the account's default AI/business finished-video style, declare `presenter-led-mixed-media-v1` in the same `material-beat-map.md` and read `presenter-led-mixed-media-style.md`. This contract decides **who owns the frame**; the mixed-media contract decides **which presentation medium performs that duty**. Do not merge them into a second owner system.

This contract extends `visual-task-v1`; it does not replace sentence coverage, material roles, motion jobs, or the digital-human `avatar-beat-plan-v1`.

## Four owners

| Owner | Owns the frame when | Required purpose | Viewer question answered |
| --- | --- | --- | --- |
| `PERSON` | attitude, judgment, question, reversal, chapter opening, emotional lift, conclusion, or a reset after dense material | `continue-listening` | Why should I keep listening? |
| `EVIDENCE` | official screenshot, number, quotation, source excerpt, product operation, or demo | `belief` | Why should I believe this? |
| `EXPLAINER` | mechanism, causal chain, comparison logic, or abstract relationship | `understanding` | Why can I understand this? |
| `SCENE` | workflow, production, enterprise use, physical context, or real behavior | `reality` | Why does this matter in reality? |

The presenter is a narrative anchor, not a persistent corner sticker. After a dense proof or explanation run, a PERSON return can reset attention and reclaim the judgment. A useful sequence may be:

`PERSON -> EVIDENCE -> PERSON -> EXPLAINER -> PERSON -> SCENE -> PERSON`

This is an example of narrative-rights handoff, not a fixed shot list or timing template. The semantic task decides when ownership changes.

## Owner triggers

Use these machine-readable `handoff_reason` values:

| Owner | Preferred reasons |
| --- | --- |
| `PERSON` | `opening`, `chapter-open`, `question`, `reversal`, `judgment`, `emotion-lift`, `conclusion`, `return-after-proof`, `return-after-explainer`, `return-after-scene`, `complex-reset` |
| `EVIDENCE` | `official-proof`, `number`, `quote`, `demo` |
| `EXPLAINER` | `mechanism`, `causal-chain`, `abstract-concept` |
| `SCENE` | `workflow`, `production`, `enterprise-use`, `real-action` |

Use `custom:<short-reason>` only when none of the standard reasons is accurate. Do not use `custom` to hide an owner/reason mismatch.

New chapters, reversals, rhetorical questions, value judgments, emotional lifts, and final conclusions prefer `PERSON`. Numbers, quotations, official proof, and product demos prefer `EVIDENCE`. Mechanisms, causal chains, and abstract concepts prefer `EXPLAINER`. Workflows, production, enterprise application, and real behavior prefer `SCENE`.

## Beat contract

When `material-beat-map.md` declares `screen-owner-v1`, every `LINE## -> VT##` row also declares:

- `Owner`: one of `PERSON / EVIDENCE / EXPLAINER / SCENE`.
- `Purpose`: the owner-specific purpose in the table above.
- `Handoff reason`: a standard reason or `custom:<short-reason>`.
- `Return to person`: `required`, `recommended`, or `no`.
- `Evidence source`: source URL, local path, citation, or demo identifier for `EVIDENCE`; `n/a` for other owners.
- `Motion action`: the visible action, proof hold, interface operation, camera action, or state change. Motion supports the owner; it does not create proof or narrative progress by itself.

Rows that share a `VT##` must share one owner. If the ownership changes, create a new visual task even when the spoken subject stays the same.

Use `return_to_person: required` when the following beat must contain human judgment or when the current material would otherwise be allowed to carry a conclusion it cannot own. Use `recommended` after a dense proof/explainer run or before a new judgment. Use `no` when the next semantic owner can continue cleanly.

## Ownership is not layout

- `PERSON` means the person is the dominant narrative subject. It does not mean a small portrait over a board.
- `EVIDENCE` means the proof is readable at the size needed to verify it.
- `EXPLAINER` means the mechanism or relationship visibly changes; a pile of labels is not explanation.
- `SCENE` means a real action or context is legible; generic office texture is not automatically a production scene.
- A side-by-side or PiP is a short layout bridge only when both subjects are semantically necessary. It does not create a fifth owner.

## Anti-patterns

- A presenter hangs in a corner through proof, operation, or explanation beats.
- A person and a PPT board remain side by side as the default layout.
- Every sentence becomes a new card while narrative ownership never changes.
- Evidence is asked to carry an opinion, judgment, or emotional conclusion.
- Animation is asked to prove a fact that has no source.
- Complex information continues for many beats without a person, real scene, or another deliberate re-anchor.
- Card fly-ins, number scaling, and arrow drawing are treated as narrative progress although the same owner and semantic responsibility remain unchanged.

The PPT problem is not simply that elements are static. It is that narrative ownership does not change. Movement without a new responsibility is decoration.

## DeepSeek v17 positive example

`videos\2026-08-21-deepseek-flash-vision-system-competition` v17 is a historical positive example, not a fixed template. Its accepted flow let PERSON open the question, EVIDENCE prove product and pricing claims, EXPLAINER unpack abstract relations, and SCENE land the system argument in real production. The person did not stay in a corner to accompany every card, and dense information was reset by a new owner instead of another one-second slide.

## Validation

Run in Material and again in draft QA:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-video-screen-ownership.ps1 -VideoDir <video-dir>
```

The validation pair has two jobs. `test-video-screen-ownership.ps1` fails malformed owner contracts, incompatible purpose/reason assignments, missing evidence sources, broken required returns, and shared tasks with conflicting owners. `test-video-visual-task-coverage.ps1` then fails Assembly `primaryOwner` mismatches. The planning validator emits warnings for prolonged same-owner/card runs, presenter-only-at-opening plans, recommended returns that never occur, and corner-presenter language. Warnings require human review; they do not impose a fixed duration or shot-count template.
