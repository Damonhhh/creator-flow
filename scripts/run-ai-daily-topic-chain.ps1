param(
  [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
  [string]$WorkspaceRoot = "",
  [string]$InputPath = "",
  [string]$RubricPath = "",
  [string]$OutputRoot = "",
  [string]$KnowledgeRoot = "",
  [string]$CleanScriptPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "resolve-python-command.ps1")

if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
  $WorkspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

function New-TextFromCodePoints {
  param([int[]]$CodePoints)

  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function Get-LastOutputObject {
  param([object[]]$Output)

  if ($Output.Count -eq 0) {
    throw "Expected command to return a result object"
  }

  return $Output[$Output.Count - 1]
}

function Assert-NotBlank {
  param(
    [string]$Name,
    [object]$Value
  )

  if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
    throw ("Topic chain failed: {0} is blank" -f $Name)
  }
}

function Assert-NoManualPlaceholder {
  param(
    [string]$Name,
    [string]$Value
  )

  $manualConfirm = New-TextFromCodePoints @(0x4EBA, 0x5DE5, 0x786E, 0x8BA4)
  $manualTopic = New-TextFromCodePoints @(0x4ECA, 0x65E5, 0x4E3B, 0x7EBF, 0x63A8, 0x8350, 0x5F85, 0x4EBA, 0x5DE5, 0x786E, 0x8BA4)

  if ($Value -match [regex]::Escape($manualConfirm) -or $Value -match [regex]::Escape($manualTopic)) {
    throw ("Topic chain failed: {0} still contains manual-confirmation placeholder" -f $Name)
  }
}

function Assert-OutputFileReady {
  param(
    [string]$Name,
    [string]$Path
  )

  Assert-NotBlank -Name $Name -Value $Path
  if (-not (Test-Path -LiteralPath $Path)) {
    throw ("Topic chain failed: {0} does not exist: {1}" -f $Name, $Path)
  }

  $item = Get-Item -LiteralPath $Path
  if ($item.Length -le 0) {
    throw ("Topic chain failed: {0} is empty: {1}" -f $Name, $Path)
  }
}

$portableMode = -not [string]::IsNullOrWhiteSpace($InputPath) -or -not [string]::IsNullOrWhiteSpace($RubricPath)
if ($portableMode) {
  if ([string]::IsNullOrWhiteSpace($InputPath) -or [string]::IsNullOrWhiteSpace($RubricPath)) {
    throw "Offline topic mode requires both -InputPath and -RubricPath."
  }

  $decisionScript = Join-Path $PSScriptRoot "run-mainline-topic-decision.ps1"
  if (-not (Test-Path -LiteralPath $decisionScript)) {
    throw ("Topic chain failed: missing decision script: {0}" -f $decisionScript)
  }

  $portableArgs = @{
    Date          = $Date
    WorkspaceRoot = $WorkspaceRoot
    InputPath     = $InputPath
    RubricPath    = $RubricPath
    Write         = $true
  }
  if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
    $portableArgs["OutputRoot"] = $OutputRoot
  }

  $portableResult = Get-LastOutputObject -Output @(& $decisionScript @portableArgs)
  if (-not $portableResult.Success) {
    throw "Topic chain failed: offline decision did not report success"
  }
  return $portableResult
}

$preflightScript = Join-Path $PSScriptRoot "run-ai-daily-topic-preflight.ps1"
$generatorScript = Join-Path $PSScriptRoot "generate_mainline_topic_decision.py"

if (-not (Test-Path -LiteralPath $preflightScript)) {
  throw ("Topic chain failed: missing preflight script: {0}" -f $preflightScript)
}

if (-not (Test-Path -LiteralPath $generatorScript)) {
  throw ("Topic chain failed: missing generator script: {0}" -f $generatorScript)
}

$preflightArgs = @{
  Date = $Date
  WorkspaceRoot = $WorkspaceRoot
}

if (-not [string]::IsNullOrWhiteSpace($KnowledgeRoot)) {
  $preflightArgs["KnowledgeRoot"] = $KnowledgeRoot
}

if (-not [string]::IsNullOrWhiteSpace($CleanScriptPath)) {
  $preflightArgs["CleanScriptPath"] = $CleanScriptPath
}

$preflight = Get-LastOutputObject -Output @(& $preflightScript @preflightArgs)

if (-not $preflight.Success) {
  throw "Topic chain failed: preflight did not report success"
}

$generatorArgs = @(
  $generatorScript,
  "--date", $Date,
  "--workspace", $WorkspaceRoot,
  "--write"
)

$python = Resolve-PythonCommand
$raw = & $python.Command @($python.PrefixArgs + $generatorArgs)
if ($LASTEXITCODE -ne 0) {
  throw "Topic chain failed: generate_mainline_topic_decision.py failed with exit code $LASTEXITCODE"
}

$data = ($raw -join "`n") | ConvertFrom-Json

Assert-NotBlank -Name "Topic" -Value $data.topic
Assert-NotBlank -Name "RecommendedTitle" -Value $data.recommended_title
Assert-NoManualPlaceholder -Name "Topic" -Value ([string]$data.topic)
Assert-NoManualPlaceholder -Name "RecommendedTitle" -Value ([string]$data.recommended_title)

Assert-OutputFileReady -Name "DecisionPath" -Path ([string]$data.decision_path)
Assert-OutputFileReady -Name "PlanPath" -Path ([string]$data.plan_path)
Assert-OutputFileReady -Name "AssetPath" -Path ([string]$data.asset_path)
Assert-OutputFileReady -Name "VoicePath" -Path ([string]$data.voice_path)
Assert-OutputFileReady -Name "NarrationTextPath" -Path ([string]$data.narration_text_path)

[pscustomobject]@{
  Success          = $true
  Date             = $data.date
  Topic            = $data.topic
  RecommendedTitle = $data.recommended_title
  Slug             = $data.slug
  DecisionPath     = $data.decision_path
  PlanDirectory    = $data.plan_directory
  PlanPath         = $data.plan_path
  AssetPath        = $data.asset_path
  VoicePath        = $data.voice_path
  NarrationTextPath = $data.narration_text_path
  Preflight        = $preflight
}
