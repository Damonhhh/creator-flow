Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$creator = Join-Path $repoRoot "scripts\new-video-project.ps1"
$sourceLayoutTemplate = Join-Path $repoRoot "open-source\examples\minimal-video-project"
$packageLayoutTemplate = Join-Path $repoRoot "examples\minimal-video-project"
$template = if (Test-Path -LiteralPath $sourceLayoutTemplate -PathType Container) { $sourceLayoutTemplate } else { $packageLayoutTemplate }
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zimeiti-minimal-project-test-" + [guid]::NewGuid().ToString("N"))
$projectName = "2026-08-12-minimal-demo"
$projectRoot = Join-Path $tempRoot $projectName

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

try {
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

  $resultJson = & $creator -Name $projectName -Destination $tempRoot -Template $template
  $result = (@($resultJson) -join "`n") | ConvertFrom-Json

  Assert-True ($result.success -eq $true) "Expected project creation to succeed"
  Assert-True ($result.projectRoot -eq $projectRoot) "Expected the reported project root"
  Assert-True ($result.state -eq "topic_ready") "Expected topic_ready initial state"
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$result.nextStep)) "Expected an actionable next step"

  foreach ($directory in @("draft", "assets", "review", "publish", "draft\visual-plan", "draft\web-assets")) {
    Assert-True (Test-Path -LiteralPath (Join-Path $projectRoot $directory) -PathType Container) "Missing directory: $directory"
  }

  foreach ($file in @(
      "README.md",
      "account-profile.md",
      "writing-style.md",
      "knowledge-sources.md",
      "source-content.md",
      "project-state.json",
      "draft\visual-plan\material-beat-map.md",
      "draft\web-assets\source-candidates.md"
    )) {
    Assert-True (Test-Path -LiteralPath (Join-Path $projectRoot $file) -PathType Leaf) "Missing file: $file"
  }

  $state = Get-Content -LiteralPath (Join-Path $projectRoot "project-state.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($state.schemaVersion -eq "video-project-state-v1") "Expected the shared state schema"
  Assert-True ($state.currentStage -eq "Topic") "Expected the project to start at Topic"
  Assert-True ($state.stageStatus -eq "topic_ready") "Expected topic_ready stage status"
  Assert-True ($state.qa.automated -eq "not_run") "Automated QA must not be pre-approved"
  Assert-True ($state.qa.humanStatus -eq "not_run") "Human review must not be pre-approved"
  Assert-True ($null -eq $state.qa.humanVisualReview) "Human review record must not be pre-created"
  Assert-True ($null -eq $state.published) "Published success must not be pre-created"
  Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $projectRoot "review") -Force).Count -eq 0) "Review directory must start empty"
  Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $projectRoot "publish") -Force).Count -eq 0) "Publish directory must start empty"

  $sentinel = Join-Path $projectRoot "keep.txt"
  [System.IO.File]::WriteAllText($sentinel, "keep", [System.Text.UTF8Encoding]::new($false))
  $failedSafely = $false
  try {
    & $creator -Name $projectName -Destination $tempRoot -Template $template | Out-Null
  }
  catch {
    $failedSafely = $_.Exception.Message -match "already exists"
  }
  Assert-True $failedSafely "Expected an existing target to fail clearly"
  Assert-True ((Get-Content -LiteralPath $sentinel -Raw -Encoding UTF8) -eq "keep") "Existing project content must not be overwritten"

  $defaultName = "2026-08-12-default-template-demo"
  $defaultJson = & $creator -Name $defaultName -Destination $tempRoot
  $defaultResult = (@($defaultJson) -join "`n") | ConvertFrom-Json
  Assert-True ($defaultResult.success -eq $true) "Expected the script default template to work"
  Assert-True (Test-Path -LiteralPath (Join-Path $tempRoot "$defaultName\project-state.json") -PathType Leaf) "Default template project is incomplete"

  Write-Host "minimal video project tests passed"
}
finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
