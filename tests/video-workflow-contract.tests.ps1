Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

$skill = Get-Content -LiteralPath (Join-Path $repoRoot ".agents\skills\zimeiti-video-workflow\SKILL.md") -Raw -Encoding UTF8
$pipeline = Get-Content -LiteralPath (Join-Path $repoRoot ".agents\skills\zimeiti-video-workflow\references\pipeline.md") -Raw -Encoding UTF8
$qaScript = Get-Content -LiteralPath (Join-Path $repoRoot "scripts\run-video-draft-qa.ps1") -Raw -Encoding UTF8
$wrapScript = Get-Content -LiteralPath (Join-Path $repoRoot "scripts\invoke-video-wrap-up.ps1") -Raw -Encoding UTF8

Assert-True ($skill.Contains("video-workflow-current-state.md")) "Expected live workflow state entry"
Assert-True ($skill.Contains("project-state.json")) "Expected machine-readable stage routing"
Assert-True ($pipeline.Contains("awaiting_human_review")) "Expected automated QA to stop before human pass"
Assert-True ($qaScript.Contains("[int]`$MaxReviewFrames = 80")) "Expected review-frame budget"
Assert-True ($qaScript.Contains("qa-frames-current")) "Expected isolated current QA frame directory"
Assert-True ($qaScript.Contains("Parse-SceneElementsFromHtml")) "Expected timed scene parsing for peak-state QA"
Assert-True ($qaScript.Contains("hyperframes@0.7.55 inspect --at")) "Expected current HyperFrames scene-midpoint inspection"
Assert-True ($qaScript.Contains("Open every exported scene-midpoint frame")) "Expected human review instruction for full-entry collision checks"
Assert-True ($qaScript.Contains("human-visual-review-pending.md")) "Expected pending human review template"
Assert-True ($qaScript.Contains("test-video-visual-task-coverage.ps1")) "Expected draft QA visual-task implementation gate"
Assert-True ($wrapScript.Contains("test-video-human-visual-review.ps1")) "Expected wrap-up human review gate"
Assert-True ($wrapScript.Contains("humanVisualReviewSha256")) "Expected QA stamp render binding"
Assert-True ($wrapScript.Contains('publishCopyPass = $publishCopyPass.path')) "Expected generic publish-copy pass manifest field"
Assert-True ($skill.Contains('Missing Dependency Recovery')) "Expected consent-gated dependency recovery"

$stageFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot ".agents\skills\zimeiti-video-workflow\references") -Filter "stage-*.md" -File)
Assert-True ($stageFiles.Count -eq 6) "Expected exactly six workflow stages"
foreach ($stage in $stageFiles) {
  $text = Get-Content -LiteralPath $stage.FullName -Raw -Encoding UTF8
  Assert-True ($text.Contains("failure-pattern-index.md")) "Expected compact failure routing in $($stage.Name)"
}

Write-Host "video workflow contract tests passed"
