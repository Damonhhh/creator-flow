param(
  [Parameter(Mandatory = $true)]
  [string]$VideoDir,

  [Parameter(Mandatory = $true)]
  [ValidateSet("Topic", "Script TTS", "Material", "Assembly", "QA", "Publish Wrap Up")]
  [string]$CurrentStage,

  [Parameter(Mandatory = $true)]
  [ValidateSet("in_progress", "blocked", "awaiting_human_review", "ready_for_wrap_up", "pending_manual_publish", "complete")]
  [string]$StageStatus,

  [string]$NextAction = "",
  [string]$LatestRender = "",
  [string]$AutomatedQa = "",
  [string]$AutomatedQaReport = "",
  [string]$HumanVisualReview = "",
  [string[]]$Blockers = @(),
  [string]$Source = "manual"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-OptionalPath {
  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return $null }
  if (Test-Path -LiteralPath $PathValue) {
    return (Resolve-Path -LiteralPath $PathValue).Path
  }
  return $PathValue
}

function Get-ExistingValue {
  param(
    [object]$Object,
    [string]$Name,
    [object]$DefaultValue = $null
  )
  if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
    return $Object.$Name
  }
  return $DefaultValue
}

$videoRoot = (Resolve-Path -LiteralPath $VideoDir -ErrorAction Stop).Path
$statePath = Join-Path $videoRoot "project-state.json"
$existing = $null
if (Test-Path -LiteralPath $statePath) {
  try {
    $existing = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
  }
  catch {
    throw "Existing project-state.json is invalid JSON: $statePath"
  }
}

$createdAt = Get-ExistingValue -Object $existing -Name "createdAt" -DefaultValue (Get-Date).ToString("o")
$existingRender = Get-ExistingValue -Object $existing -Name "latestRender"
$existingRenderPath = Get-ExistingValue -Object $existingRender -Name "path"
$existingRenderHash = Get-ExistingValue -Object $existingRender -Name "sha256"
$renderPath = Resolve-OptionalPath -PathValue $LatestRender
$renderHash = $null
if ($renderPath -and (Test-Path -LiteralPath $renderPath)) {
  $renderHash = (Get-FileHash -LiteralPath $renderPath -Algorithm SHA256).Hash
}
elseif ($existingRender) {
  $renderPath = $existingRenderPath
  $renderHash = $existingRenderHash
}
$renderChanged = $false
if ($LatestRender) {
  $renderChanged = -not [string]::Equals([string]$existingRenderHash, [string]$renderHash, [System.StringComparison]::OrdinalIgnoreCase)
}

$existingQa = Get-ExistingValue -Object $existing -Name "qa"
$validAutomatedQa = @("", "not_run", "PASS", "FAIL")
if ($validAutomatedQa -notcontains $AutomatedQa) {
  throw "AutomatedQa must be PASS, FAIL, not_run, or empty. Actual: $AutomatedQa"
}
$automatedQaValue = if ($AutomatedQa) { $AutomatedQa } else { Get-ExistingValue -Object $existingQa -Name "automated" -DefaultValue "not_run" }
$automatedReportValue = if ($AutomatedQaReport) { Resolve-OptionalPath $AutomatedQaReport } else { Get-ExistingValue -Object $existingQa -Name "automatedReport" }
$humanReviewValue = Get-ExistingValue -Object $existingQa -Name "humanVisualReview"
$humanStatus = Get-ExistingValue -Object $existingQa -Name "humanStatus" -DefaultValue "not_run"
if ($renderChanged -and -not $HumanVisualReview) {
  $humanReviewValue = $null
  $humanStatus = "not_run"
}
if ($HumanVisualReview) {
  $resolvedHumanReview = Resolve-OptionalPath $HumanVisualReview
  if (-not (Test-Path -LiteralPath $resolvedHumanReview)) {
    throw "Human visual review does not exist: $HumanVisualReview"
  }
  if (-not $renderPath -or -not (Test-Path -LiteralPath $renderPath)) {
    throw "A real latest render is required before human review can be marked PASS."
  }
  $validator = Join-Path $PSScriptRoot "test-video-human-visual-review.ps1"
  $validationJson = & $validator -VideoDir $videoRoot -VideoPath $renderPath
  $validation = (@($validationJson) -join "`n") | ConvertFrom-Json
  if (-not [string]::Equals([string]$validation.reviewPath, [string](Resolve-Path -LiteralPath $resolvedHumanReview).Path, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "HumanVisualReview is not the latest accepted review. Expected $($validation.reviewPath), got $resolvedHumanReview"
  }
  $humanReviewValue = $validation.reviewPath
  $humanStatus = "PASS"
}

$state = [ordered]@{
  schemaVersion = "video-project-state-v1"
  project = Split-Path -Leaf $videoRoot
  projectPath = $videoRoot
  createdAt = $createdAt
  updatedAt = (Get-Date).ToString("o")
  currentStage = $CurrentStage
  stageStatus = $StageStatus
  nextAction = $NextAction
  latestRender = [ordered]@{
    path = $renderPath
    sha256 = $renderHash
  }
  qa = [ordered]@{
    automated = $automatedQaValue
    automatedReport = $automatedReportValue
    humanStatus = $humanStatus
    humanVisualReview = $humanReviewValue
  }
  blockers = @($Blockers | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
  source = $Source
}

$json = $state | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($statePath, $json + "`n", [System.Text.UTF8Encoding]::new($false))
$state | ConvertTo-Json -Depth 8
