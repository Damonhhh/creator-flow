Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

$skill = Get-Content -LiteralPath (Join-Path $repoRoot ".agents\skills\zimeiti-video-workflow\SKILL.md") -Raw -Encoding UTF8
$pipeline = Get-Content -LiteralPath (Join-Path $repoRoot ".agents\skills\zimeiti-video-workflow\references\pipeline.md") -Raw -Encoding UTF8
$ownershipContract = Get-Content -LiteralPath (Join-Path $repoRoot ".agents\skills\zimeiti-video-workflow\references\screen-ownership-contract.md") -Raw -Encoding UTF8
$mixedMediaContract = Get-Content -LiteralPath (Join-Path $repoRoot ".agents\skills\zimeiti-video-workflow\references\presenter-led-mixed-media-style.md") -Raw -Encoding UTF8
$materialGenerator = Get-Content -LiteralPath (Join-Path $repoRoot "scripts\new-video-source-candidates.ps1") -Raw -Encoding UTF8
$qaScript = Get-Content -LiteralPath (Join-Path $repoRoot "scripts\run-video-draft-qa.ps1") -Raw -Encoding UTF8
$wrapScript = Get-Content -LiteralPath (Join-Path $repoRoot "scripts\invoke-video-wrap-up.ps1") -Raw -Encoding UTF8
$wrapSkill = Get-Content -LiteralPath (Join-Path $repoRoot ".agents\skills\zimeiti-video-wrap-up\SKILL.md") -Raw -Encoding UTF8
$publishCopyValidator = Get-Content -LiteralPath (Join-Path $repoRoot "scripts\test-video-publish-copy.ps1") -Raw -Encoding UTF8
$publishCopyContract = Get-Content -LiteralPath (Join-Path $repoRoot ".agents\skills\zimeiti-video-workflow\references\publish-copy-contract.md") -Raw -Encoding UTF8

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
Assert-True ($qaScript.Contains("test-video-screen-ownership.ps1")) "Expected draft QA screen-ownership gate"
Assert-True ($qaScript.Contains("presenter-led-mixed-media-v1 planning QA passed")) "Expected draft QA mixed-media result"
Assert-True ($ownershipContract.Contains("PERSON") -and $ownershipContract.Contains("EVIDENCE") -and $ownershipContract.Contains("EXPLAINER") -and $ownershipContract.Contains("SCENE")) "Expected four screen-owner roles"
Assert-True ($materialGenerator.Contains("screen-owner-v1")) "Expected generated Material map to declare screen-owner-v1"
Assert-True ($mixedMediaContract.Contains("presenter-led-mixed-media-v1")) "Expected presenter-led mixed-media contract"
Assert-True ($mixedMediaContract.Contains("7634861116409138466")) "Expected verified external reference source to be recorded"
foreach ($mode in @("avatar-talk", "official-proof", "real-footage", "kinetic-image", "aigc-scene", "support-card")) {
  Assert-True ($mixedMediaContract.Contains($mode)) "Expected mixed-media mode $mode"
}
Assert-True ($materialGenerator.Contains("presenter-led-mixed-media-v1")) "Expected generated Material map to declare presenter-led-mixed-media-v1"
Assert-True ($materialGenerator.Contains("Presentation mode") -and $materialGenerator.Contains("Takeover") -and $materialGenerator.Contains("Provenance")) "Expected generated Material map to include mixed-media fields"
Assert-True ($qaScript.Contains("Digital-human mouth motion") -and $qaScript.Contains("Support-card exceptions")) "Expected pending human review template to include presenter-led finished-render checks"
Assert-True ($wrapScript.Contains("test-video-human-visual-review.ps1")) "Expected wrap-up human review gate"
Assert-True ($wrapScript.Contains("humanVisualReviewSha256")) "Expected QA stamp render binding"
Assert-True ($wrapScript.Contains('publishCopyPass = $publishCopyPass.path')) "Expected generic publish-copy pass manifest field"
Assert-True ($wrapScript.Contains('publishCopyContract = $publishCopyContractResult')) "Expected structured publish-copy evidence in the manifest"
Assert-True ($wrapScript.IndexOf('$latestRender = [ordered]@{') -lt $wrapScript.IndexOf('& $publishCopyValidator')) "Render and QA manifests must be refreshed before publish-copy validation"
Assert-True ($wrapSkill.Contains('docs\cover-system.md') -and -not $wrapSkill.Contains('zimeiti-cover-system-v1.md')) "Exported wrap-up skill must use only the public cover-system path"
Assert-True ($publishCopyValidator.Contains('publish-copy-plan-v1')) "Expected publish-copy plan validation"
Assert-True ($publishCopyValidator.Contains('at least 8 candidates')) "Expected title matrix breadth validation"
Assert-True ($publishCopyValidator.Contains('sourceBinding') -and $publishCopyValidator.Contains('latest-render.sha256') -and $publishCopyValidator.Contains('qa-stamp.finalVideoSha256')) "Expected publish-copy SHA binding across scorecard and QA manifests"
Assert-True ($publishCopyContract.Contains('title matrix') -and $publishCopyContract.Contains('independent review')) "Expected publish-copy production and review contract"
Assert-True ($skill.Contains('Missing Dependency Recovery')) "Expected consent-gated dependency recovery"

$stageFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot ".agents\skills\zimeiti-video-workflow\references") -Filter "stage-*.md" -File)
Assert-True ($stageFiles.Count -eq 6) "Expected exactly six workflow stages"
foreach ($stage in $stageFiles) {
  $text = Get-Content -LiteralPath $stage.FullName -Raw -Encoding UTF8
  Assert-True ($text.Contains("failure-pattern-index.md")) "Expected compact failure routing in $($stage.Name)"
}

Write-Host "video workflow contract tests passed"
