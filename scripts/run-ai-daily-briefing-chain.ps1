param(
  [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
  [string]$WorkspaceRoot = "",
  [string]$KnowledgeRoot = "",
  [string]$OutputRoot = "",
  [string]$JsonPath = "",
  [string]$SignalRadarOutputRoot = "",
  [string]$SignalRadarAIHotInputPath = "",
  [string]$SignalRadarAIHotEndpoint = "",
  [string]$TrendRadarConfigDir = "",
  [string]$TrendRadarNewsNowApiBase = "",
  [switch]$OverwriteExisting,
  [switch]$RadarOnly,
  [switch]$SkipTrendRadarSideRadar,
  [switch]$SkipSignalRadar,
  [switch]$LiveCollection
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
  $WorkspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
  $WorkspaceRoot = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
}

function New-TextFromCodePoints {
  param([int[]]$CodePoints)

  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function Resolve-OutputRoot {
  param(
    [string]$WorkspaceRoot,
    [string]$KnowledgeRoot,
    [string]$OutputRoot
  )

  if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
    return $OutputRoot
  }

  if (-not [string]::IsNullOrWhiteSpace($KnowledgeRoot)) {
    return (Join-Path $KnowledgeRoot "AI-Daily-Briefing")
  }

  return (Join-Path $WorkspaceRoot "data\AI-Daily-Briefing")
}

function Resolve-OutputPath {
  param(
    [string]$Date,
    [string]$WorkspaceRoot,
    [string]$KnowledgeRoot,
    [string]$OutputRoot
  )

  $briefingFileName = "{0}-{1}.md" -f $Date, (New-TextFromCodePoints @(0x6BCF,0x65E5,0x0041,0x0049,0x7B80,0x62A5))
  return (Join-Path (Resolve-OutputRoot -WorkspaceRoot $WorkspaceRoot -KnowledgeRoot $KnowledgeRoot -OutputRoot $OutputRoot) $briefingFileName)
}

function Get-BriefingNewsItemCount {
  param(
    [string]$Path
  )

  $content = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
  return ([regex]::Matches($content, '(?m)^###\s+\d+\.')).Count
}

function Get-BriefingFocusTitle {
  param(
    [string]$Path
  )

  $content = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
  $focusPrefix = New-TextFromCodePoints @(0x4ECA,0x5929,0x6700,0x503C,0x5F97,0x91CD,0x70B9,0x5173,0x6CE8,0x7684,0x662F,0xFF1A)
  $match = [regex]::Match($content, "(?m)^" + [regex]::Escape($focusPrefix) + "(.*)$")

  if ($match.Success) {
    return $match.Groups[1].Value.Trim()
  }

  return ""
}

function Assert-NotBlank {
  param(
    [string]$Name,
    [object]$Value
  )

  if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
    throw ("Briefing chain failed: {0} is blank" -f $Name)
  }
}

function Assert-OutputFileReady {
  param(
    [string]$Path
  )

  Assert-NotBlank -Name "OutputPath" -Value $Path

  if (-not (Test-Path -LiteralPath $Path)) {
    throw ("Briefing chain failed: output file does not exist: {0}" -f $Path)
  }

  $item = Get-Item -LiteralPath $Path
  if ($item.Length -le 0) {
    throw ("Briefing chain failed: output file is empty: {0}" -f $Path)
  }
}

function Assert-RequiredSections {
  param(
    [string]$Path,
    [string]$Date
  )

  $content = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw

  $briefingTitle = New-TextFromCodePoints @(0x6BCF,0x65E5,0x0020,0x0041,0x0049,0x0020,0x7B80,0x62A5)
  $sectionTopNews = New-TextFromCodePoints @(0x4ECA,0x65E5,0x6700,0x91CD,0x8981,0x7684,0x0020,0x0033,0x0020,0x6761,0x0020,0x0041,0x0049,0x0020,0x65B0,0x95FB)
  $sectionFocus = New-TextFromCodePoints @(0x4ECA,0x65E5,0x91CD,0x70B9,0x5173,0x6CE8)
  $sectionIdeas = New-TextFromCodePoints @(0x53EF,0x8F6C,0x5316,0x9009,0x9898)
  $sectionViews = New-TextFromCodePoints @(0x53EF,0x53D1,0x5C0F,0x7EA2,0x4E66,0x0020,0x002F,0x0020,0x0058,0x0020,0x7684,0x4E00,0x53E5,0x8BDD,0x89C2,0x70B9)

  foreach ($required in @(
    ('title: "{0} - {1}"' -f $briefingTitle, $Date),
    ("date: {0}" -f $Date),
    '# ' + $briefingTitle + ' - ' + $Date,
    '## ' + $sectionTopNews,
    '## ' + $sectionFocus,
    '## ' + $sectionIdeas,
    '## ' + $sectionViews
  )) {
    if (-not $content.Contains($required)) {
      throw ("Briefing chain failed: missing required content `{0}` in {1}" -f $required, $Path)
    }
  }
}

function Invoke-TrendRadarSideRadar {
  param(
    [string]$Date,
    [string]$ConfigDir,
    [string]$NewsNowApiBase,
    [bool]$LiveCollection
  )

  $radarScript = Join-Path $PSScriptRoot "run-trendradar-ai-radar.ps1"
  if (-not (Test-Path -LiteralPath $radarScript)) {
    return [pscustomobject]@{
      Success = $false
      Skipped = $false
      Error = "missing radar script: $radarScript"
      ItemCount = $null
      ErrorCount = $null
      JsonPath = $null
      MarkdownPath = $null
    }
  }

  try {
    $radarArguments = @('-LiveCollection')
    if (-not [string]::IsNullOrWhiteSpace($ConfigDir)) {
      $radarArguments += @('-ConfigDir', $ConfigDir)
    }
    if (-not [string]::IsNullOrWhiteSpace($NewsNowApiBase)) {
      $radarArguments += @('-NewsNowApiBase', $NewsNowApiBase)
    }
    $radarResult = & $radarScript @radarArguments
    $last = @($radarResult | Where-Object { $_ -is [pscustomobject] -or $_.PSObject.Properties["success"] } | Select-Object -Last 1)

    if (-not $last) {
      return [pscustomobject]@{
        Success = $false
        Skipped = $false
        Error = "radar script returned no structured result"
        ItemCount = $null
        ErrorCount = $null
        JsonPath = $null
        MarkdownPath = $null
      }
    }

    return [pscustomobject]@{
      Success = [bool]$last.success
      Skipped = $false
      Error = $null
      ItemCount = $last.item_count
      ErrorCount = $last.error_count
      JsonPath = $last.json_path
      MarkdownPath = $last.markdown_path
    }
  } catch {
    return [pscustomobject]@{
      Success = $false
      Skipped = $false
      Error = $_.Exception.Message
      ItemCount = $null
      ErrorCount = $null
      JsonPath = $null
      MarkdownPath = $null
    }
  }
}

function Invoke-DailySignalRadar {
  param(
    [string]$Date,
    [string]$TrendRadarPath,
    [string]$OutputRoot,
    [string]$AIHotInputPath,
    [string]$AIHotEndpoint,
    [bool]$LiveCollection
  )

  $collector = Join-Path $PSScriptRoot "collect-ai-daily-signal-radar.mjs"
  if (-not (Test-Path -LiteralPath $collector)) {
    return [pscustomobject]@{
      Success = $false
      Skipped = $false
      Error = "missing signal radar collector: $collector"
      CandidateCount = $null
      Health = "failed"
      OutputPath = $null
    }
  }

  try {
    $arguments = @($collector, "--date", $Date, "--hours", "48", "--max", "100")
    if (-not [string]::IsNullOrWhiteSpace($TrendRadarPath)) {
      $arguments += @("--trendradar-input", $TrendRadarPath)
    }
    if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
      $arguments += @("--output-root", $OutputRoot)
    }
    if (-not [string]::IsNullOrWhiteSpace($AIHotInputPath)) {
      $arguments += @("--aihot-input", $AIHotInputPath, "--selected-fallback-min-items", "0")
    }
    if (-not [string]::IsNullOrWhiteSpace($AIHotEndpoint)) {
      $arguments += @("--aihot-endpoint", $AIHotEndpoint)
    }
    if ($LiveCollection) {
      $arguments += "--live-collection"
    }

    $node = (Get-Command node -ErrorAction Stop).Source
    $rawOutput = & $node @arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw ($rawOutput -join [Environment]::NewLine)
    }

    $summary = ($rawOutput -join [Environment]::NewLine) | ConvertFrom-Json
    return [pscustomobject]@{
      Success = [bool]$summary.success
      Skipped = $false
      Error = $null
      CandidateCount = [int]$summary.candidate_count
      Health = [string]$summary.health
      AIHotSelectedCount = [int]$summary.aihot_selected_count
      AIHotAllFallbackCount = [int]$summary.aihot_all_fallback_count
      TrendRadarCount = [int]$summary.trendradar_count
      OutputPath = [string]$summary.output_path
    }
  } catch {
    return [pscustomobject]@{
      Success = $false
      Skipped = $false
      Error = $_.Exception.Message
      CandidateCount = $null
      Health = "failed"
      AIHotSelectedCount = $null
      AIHotAllFallbackCount = $null
      TrendRadarCount = $null
      OutputPath = $null
    }
  }
}

$generatorScript = Join-Path $PSScriptRoot "new-ai-daily-briefing.ps1"
$resolvedOutputRoot = Resolve-OutputRoot -WorkspaceRoot $WorkspaceRoot -KnowledgeRoot $KnowledgeRoot -OutputRoot $OutputRoot
$expectedOutputPath = Resolve-OutputPath -Date $Date -WorkspaceRoot $WorkspaceRoot -KnowledgeRoot $KnowledgeRoot -OutputRoot $OutputRoot

$trendRadarResult = [pscustomobject]@{
  Success = $null
  Skipped = $true
  Error = $null
  ItemCount = $null
  ErrorCount = $null
  JsonPath = $null
  MarkdownPath = $null
}

if ($LiveCollection -and -not $SkipTrendRadarSideRadar) {
  $trendRadarResult = Invoke-TrendRadarSideRadar -Date $Date -ConfigDir $TrendRadarConfigDir -NewsNowApiBase $TrendRadarNewsNowApiBase -LiveCollection $true
}

$signalRadarResult = [pscustomobject]@{
  Success = $null
  Skipped = $true
  Error = $null
  CandidateCount = $null
  Health = "skipped"
  AIHotSelectedCount = $null
  AIHotAllFallbackCount = $null
  TrendRadarCount = $null
  OutputPath = $null
}

if (-not $SkipSignalRadar -and ($LiveCollection -or -not [string]::IsNullOrWhiteSpace($SignalRadarAIHotInputPath) -or [bool]$trendRadarResult.Success)) {
  $sideRadarPath = if ($trendRadarResult.Success) { [string]$trendRadarResult.JsonPath } else { "" }
  $signalRadarResult = Invoke-DailySignalRadar `
    -Date $Date `
    -TrendRadarPath $sideRadarPath `
    -OutputRoot $SignalRadarOutputRoot `
    -AIHotInputPath $SignalRadarAIHotInputPath `
    -AIHotEndpoint $SignalRadarAIHotEndpoint `
    -LiveCollection ([bool]$LiveCollection)
}

if ($RadarOnly) {
  [pscustomobject]@{
    Success = [bool]$signalRadarResult.Success
    Date = $Date
    RadarOnly = $true
    SignalRadar = $signalRadarResult
    TrendRadarSideRadar = $trendRadarResult
  }
  return
}

if (-not (Test-Path -LiteralPath $generatorScript)) {
  throw ("Briefing chain failed: missing generator script: {0}" -f $generatorScript)
}

$shouldReuseExisting = (
  -not $OverwriteExisting -and
  [string]::IsNullOrWhiteSpace($JsonPath) -and
  (Test-Path -LiteralPath $expectedOutputPath)
)

if ($shouldReuseExisting) {
  Assert-OutputFileReady -Path $expectedOutputPath
  Assert-RequiredSections -Path $expectedOutputPath -Date $Date

  [pscustomobject]@{
    Success       = $true
    Date          = $Date
    OutputRoot    = $resolvedOutputRoot
    OutputPath    = $expectedOutputPath
    ItemCount     = Get-BriefingNewsItemCount -Path $expectedOutputPath
    FocusTitle    = Get-BriefingFocusTitle -Path $expectedOutputPath
    ReusedExisting = $true
    OverwroteFile = $false
    SignalRadar   = $signalRadarResult
    TrendRadarSideRadar = $trendRadarResult
  }
  return
}

$generatorArgs = @{
  Date = $Date
  WorkspaceRoot = $WorkspaceRoot
  Write = $true
}

if (-not [string]::IsNullOrWhiteSpace($KnowledgeRoot)) {
  $generatorArgs["KnowledgeRoot"] = $KnowledgeRoot
}

if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
  $generatorArgs["OutputRoot"] = $OutputRoot
}

if (-not [string]::IsNullOrWhiteSpace($JsonPath)) {
  $generatorArgs["JsonPath"] = $JsonPath
}

$result = & $generatorScript @generatorArgs

if (-not $result.Success) {
  throw "Briefing chain failed: generator did not report success"
}

$outputPath = [string]$result.OutputPath

Assert-OutputFileReady -Path $outputPath
Assert-RequiredSections -Path $outputPath -Date $Date

[pscustomobject]@{
  Success        = $true
  Date           = $Date
  OutputRoot     = $result.OutputRoot
  OutputPath     = $outputPath
  ItemCount      = $result.ItemCount
  FocusTitle     = $result.FocusTitle
  ReusedExisting = $false
  OverwroteFile  = $true
  SignalRadar    = $signalRadarResult
  TrendRadarSideRadar = $trendRadarResult
}
