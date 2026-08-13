# Visual Task Coverage Contract

Use this contract during Assembly when `material-beat-map.md` declares `visual-task-v1`.

Create `hyperframes-app\visual-task-coverage.json` before draft QA. Every unique `VT##` from the Material map needs one implementation entry. Shared tasks list every covered `LINE##`.

```json
{
  "schemaVersion": "visual-task-coverage-v1",
  "tasks": [
    {
      "taskId": "VT01",
      "lineIds": ["LINE01", "LINE02"],
      "startSec": 0,
      "endSec": 16,
      "status": "implemented",
      "implementation": "Official product window with a moving source highlight",
      "ownerElement": "scene-vt01"
    }
  ]
}
```

Required fields:

- `taskId`: stable `VT##` from the accepted beat map.
- `lineIds`: every `LINE##` served by this task.
- `startSec` / `endSec`: actual composition timing.
- `status`: `implemented` before QA.
- `implementation`: what the viewer sees happening.
- `ownerElement` or `assetPath`: traceable HyperFrames element or local asset.

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-video-visual-task-coverage.ps1 -VideoDir <video-dir>
```

This manifest proves implementation traceability. Human visual review still decides whether the task is actually readable and useful in the render.
