param(
  [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
  [string]$WorkspaceRoot = "",
  [string]$InputPath = "",
  [string]$RubricPath = "",
  [string]$OutputRoot = "",
  [string]$KnowledgeRoot = "",
  [string]$InboxPath = "",
  [string]$CleanScriptPath = "",
  [string]$BriefingPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
  $WorkspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

$portableMode = -not [string]::IsNullOrWhiteSpace($InputPath) -or -not [string]::IsNullOrWhiteSpace($RubricPath)
if ($portableMode) {
  if ([string]::IsNullOrWhiteSpace($InputPath) -or [string]::IsNullOrWhiteSpace($RubricPath)) {
    throw "Offline topic preflight requires both -InputPath and -RubricPath."
  }

  $decisionScript = Join-Path $PSScriptRoot "run-mainline-topic-decision.ps1"
  $portableArgs = @{
    Date          = $Date
    WorkspaceRoot = $WorkspaceRoot
    InputPath     = $InputPath
    RubricPath    = $RubricPath
    Preflight     = $true
  }
  if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
    $portableArgs["OutputRoot"] = $OutputRoot
  }

  & $decisionScript @portableArgs
  return
}

function New-TextFromCodePoints {
  param([int[]]$CodePoints)

  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function Resolve-KnowledgeFile {
  param(
    [string]$Root,
    [string[]]$Candidates
  )

  foreach ($candidate in $Candidates) {
    $path = Join-Path $Root $candidate
    if (Test-Path -LiteralPath $path) {
      return $path
    }
  }

  return (Join-Path $Root $Candidates[0])
}

function Resolve-DailyBriefingFile {
  param(
    [string]$Root,
    [string]$TargetDate
  )

  $briefingDir = Join-Path $Root "AI-Daily-Briefing"
  $briefingName = New-TextFromCodePoints @(0x6BCF,0x65E5,0x0041,0x0049,0x7B80,0x62A5)
  $todayPath = Join-Path $briefingDir ("{0}-{1}.md" -f $TargetDate, $briefingName)

  if (Test-Path -LiteralPath $todayPath) {
    return $todayPath
  }

  if (Test-Path -LiteralPath $briefingDir) {
    $latest = Get-ChildItem -LiteralPath $briefingDir -File |
      Where-Object { $_.Name -like "*-$briefingName.md" } |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1

    if ($null -ne $latest) {
      return $latest.FullName
    }
  }

  return $todayPath
}

if ([string]::IsNullOrWhiteSpace($KnowledgeRoot)) {
  $KnowledgeRoot = Join-Path (Split-Path -Parent $WorkspaceRoot) (New-TextFromCodePoints @(0x77E5, 0x8BC6, 0x5E93))
}

if ([string]::IsNullOrWhiteSpace($CleanScriptPath)) {
  $CleanScriptPath = Join-Path $WorkspaceRoot "scripts\clean-ai-content-research-inbox.ps1"
}

if ([string]::IsNullOrWhiteSpace($InboxPath)) {
  $InboxPath = Resolve-KnowledgeFile -Root $KnowledgeRoot -Candidates @(
    "10 Content Assets\Research\AI Content Research Inbox.md",
    "AI Content Research Inbox.md"
  )
}

if ([string]::IsNullOrWhiteSpace($BriefingPath)) {
  $BriefingPath = Resolve-DailyBriefingFile -Root $KnowledgeRoot -TargetDate $Date
}

function Get-LastOutputObject {
  param([object[]]$Output)

  if ($Output.Count -eq 0) {
    throw "Expected command to return a result object"
  }

  return $Output[$Output.Count - 1]
}

function Assert-NoResidualCleanup {
  param([object]$Result)

  $residualProblems = New-Object System.Collections.Generic.List[string]

  if ($Result.Changed) {
    $residualProblems.Add("Changed=True")
  }

  foreach ($field in @("RemovedMalformed", "RemovedExampleHost", "RemovedDuplicates", "RemovedTrackingParameters", "RemovedDuplicateExtraUrls", "RemovedNoiseExtraUrls")) {
    if ($Result.$field -ne 0) {
      $residualProblems.Add(("{0}={1}" -f $field, $Result.$field))
    }
  }

  if ($residualProblems.Count -gt 0) {
    throw ("Preflight failed: inbox cleaner is not idempotent after cleanup ({0})" -f ([string]::Join(", ", $residualProblems)))
  }
}

$contentPlanningName = New-TextFromCodePoints @(0x5185, 0x5BB9, 0x4F01, 0x5212)
$signalLibraryName = New-TextFromCodePoints @(0x4FE1, 0x53F7, 0x6E90, 0x5E93)
$signalLibraryFileName = "AI{0}.md" -f $signalLibraryName

$assetSystemPath = Resolve-KnowledgeFile -Root $KnowledgeRoot -Candidates @(
  "10 Content Assets\System\AI Content Asset System.md",
  "AI Content Asset System.md"
)

$assetOperationsPath = Resolve-KnowledgeFile -Root $KnowledgeRoot -Candidates @(
  "10 Content Assets\System\AI Content Asset Operations.md",
  "AI Content Asset Operations.md"
)

$evergreenPath = Resolve-KnowledgeFile -Root $KnowledgeRoot -Candidates @(
  "10 Content Assets\Evergreen Topic Reservoir.md",
  "Evergreen Topic Reservoir.md"
)

$requiredFiles = @(
  (Join-Path $WorkspaceRoot "videos\WORKFLOW.md"),
  (Join-Path $WorkspaceRoot (Join-Path $contentPlanningName (Join-Path ("00-{0}" -f $signalLibraryName) $signalLibraryFileName))),
  $assetSystemPath,
  $assetOperationsPath,
  $InboxPath,
  $evergreenPath,
  $BriefingPath,
  $CleanScriptPath
)

$missingFiles = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath $_) })

if ($missingFiles.Count -gt 0) {
  throw ("Preflight failed: required files are missing: {0}" -f ([string]::Join("; ", $missingFiles)))
}

$cleanResult = Get-LastOutputObject -Output @(& $CleanScriptPath -Path $InboxPath)
$verifyResult = Get-LastOutputObject -Output @(& $CleanScriptPath -Path $InboxPath -WhatIf)

Assert-NoResidualCleanup -Result $verifyResult

[pscustomobject]@{
  Success       = $true
  Date          = $Date
  WorkspaceRoot = $WorkspaceRoot
  KnowledgeRoot = $KnowledgeRoot
  InboxPath     = $InboxPath
  BriefingPath  = $BriefingPath
  Clean         = $cleanResult
  Verify        = $verifyResult
}
