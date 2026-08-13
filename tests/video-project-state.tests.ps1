Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$updater = Join-Path $repoRoot "scripts\update-video-project-state.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zimeiti-project-state-test-" + [guid]::NewGuid().ToString("N"))

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

try {
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
  $render = Join-Path $tempRoot "candidate.mp4"
  [System.IO.File]::WriteAllBytes($render, [byte[]](8, 6, 7, 5, 3, 0, 9))
  $qaReport = Join-Path $tempRoot "draft-qa-report.md"
  Set-Content -LiteralPath $qaReport -Value "- PASS" -Encoding UTF8

  & $updater -VideoDir $tempRoot -CurrentStage "QA" -StageStatus "awaiting_human_review" -NextAction "Review frames" -LatestRender $render -AutomatedQa "PASS" -AutomatedQaReport $qaReport -Source "test" | Out-Null
  $statePath = Join-Path $tempRoot "project-state.json"
  $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($state.schemaVersion -eq "video-project-state-v1") "Expected state schema"
  Assert-True ($state.currentStage -eq "QA") "Expected QA stage"
  Assert-True ($state.stageStatus -eq "awaiting_human_review") "Expected human review wait state"
  Assert-True (-not [string]::IsNullOrWhiteSpace($state.latestRender.sha256)) "Expected render hash"

  $reviewDir = Join-Path $tempRoot "review"
  New-Item -ItemType Directory -Force -Path $reviewDir | Out-Null
  $humanReview = Join-Path $reviewDir "human-visual-review-v01.md"
  @(
    "# Human Visual Review",
    "Status: PASS",
    "Candidate SHA256: $($state.latestRender.sha256)",
    "- First visible frame: PASS",
    "- Subtitle readability: PASS",
    "- Evidence readability: PASS",
    "- Visual-task coverage: PASS",
    "- Blank media slots: PASS",
    "- Transition artifacts: PASS",
    "- Static-card duration: PASS",
    "- Audio review: PASS",
    "- Closing beat: PASS",
    "- Evidence files opened: review/contact-sheet.jpg"
  ) | Set-Content -LiteralPath $humanReview -Encoding UTF8

  & $updater -VideoDir $tempRoot -CurrentStage "Publish Wrap Up" -StageStatus "ready_for_wrap_up" -NextAction "Wrap up" -LatestRender $render -AutomatedQa "PASS" -AutomatedQaReport $qaReport -HumanVisualReview $humanReview -Source "test" | Out-Null
  $reviewed = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($reviewed.qa.humanStatus -eq "PASS") "Expected validated human review state"
  Assert-True ($reviewed.qa.humanVisualReview -eq $humanReview) "Expected human review path"

  & $updater -VideoDir $tempRoot -CurrentStage "Publish Wrap Up" -StageStatus "pending_manual_publish" -NextAction "Publish manually" -Source "test" | Out-Null
  $updated = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($updated.currentStage -eq "Publish Wrap Up") "Expected publish stage update"
  Assert-True ($updated.latestRender.sha256 -eq $state.latestRender.sha256) "Expected existing render binding to persist"

  $revisedRender = Join-Path $tempRoot "candidate-v02.mp4"
  [System.IO.File]::WriteAllBytes($revisedRender, [byte[]](2, 7, 1, 8, 2, 8))
  & $updater -VideoDir $tempRoot -CurrentStage "QA" -StageStatus "awaiting_human_review" -NextAction "Review revised render" -LatestRender $revisedRender -AutomatedQa "not_run" -Source "test" | Out-Null
  $revised = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($revised.latestRender.sha256 -ne $state.latestRender.sha256) "Expected revised render binding"
  Assert-True ($revised.qa.humanStatus -eq "not_run") "Expected human review to reset when render changes"
  Assert-True ($null -eq $revised.qa.humanVisualReview) "Expected stale human review path to clear when render changes"

  Write-Host "video project state tests passed"
}
finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
