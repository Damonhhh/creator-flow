# Video Editing Tool Integration

The six-stage workflow owns the project contract. External editors and media providers contribute bounded artifacts; they do not bypass project QA or become the final delivery by themselves.

## Routing rule

- Use the configured renderer for formal composition, captions, diagrams, charts, highlights and closing cards.
- Use an external editor when the work mainly involves speech cleanup, rough cutting, natural montage, clip resequencing or complex transitions between real clips.
- Use a media provider only for a named Material-stage gap. Record provenance, license, dimensions, duration and the fallback.
- Use an ASR/caption tool after the final narration is locked.

## Missing tools

Treat an optional tool as unavailable until its preflight succeeds on the current machine. When a needed tool is absent:

1. explain what is missing and which stage needs it;
2. offer an already available route or a manual fallback first;
3. show the official source and the exact proposed install/download command;
4. explain whether it downloads code, models or other large files;
5. ask for explicit permission;
6. install or download only after the user agrees.

The workflow must never infer consent from a request to create a video.

## External tool handoff

Record the following in the active video project:

```markdown
# External Tool Handoff

- tool:
- reason selected:
- inputs:
- outputs:
- media role: prove / explain / advance / texture / rough-cut / reference
- provenance or license:
- duration and dimensions:
- validation result:
- accepted into project: yes/no
- copied to:
- next action:
```

Accepted outputs return to `assets`, `draft` or `review`, then pass the normal Assembly and QA stages.

## Non-negotiables

- Do not expose credentials, local account paths, voice identities or browser state.
- Do not install a provider, model or editor without consent.
- Do not reuse external media without provenance or license notes.
- Do not call a provider's successful response a publishable result before visual QA.
- Do not let an external tool create a second project structure that bypasses `project-state.json`.
