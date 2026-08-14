param(
  [string]$TrendRadarRoot = "",
  [string]$ConfigDir = "",
  [string]$OutputRoot = "",
  [string]$NewsNowApiBase = "",
  [switch]$DoctorOnly,
  [switch]$FullTrendRadar,
  [switch]$LiveCollection
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$workspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($ConfigDir)) {
  $ConfigDir = Join-Path $workspaceRoot "integrations\trendradar-ai-daily"
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path $workspaceRoot "output\trendradar-ai-daily"
}

if (-not $FullTrendRadar -and -not $DoctorOnly) {
  $liteScript = Join-Path $PSScriptRoot "run-trendradar-ai-radar-lite.ps1"
  & $liteScript -ConfigDir $ConfigDir -OutputRoot $OutputRoot -NewsNowApiBase $NewsNowApiBase -LiveCollection:$LiveCollection
  return
}

function Resolve-Tool {
  param([string[]]$Names)

  foreach ($name in $Names) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) {
      return $cmd.Source
    }
  }

  return $null
}

function New-TextFromCodePoints {
  param([int[]]$CodePoints)

  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

if ([string]::IsNullOrWhiteSpace($TrendRadarRoot)) {
  $TrendRadarRoot = [Environment]::GetEnvironmentVariable("TREND_RADAR_ROOT")
}

if ([string]::IsNullOrWhiteSpace($TrendRadarRoot)) {
  throw "Full TrendRadar mode requires -TrendRadarRoot or the TREND_RADAR_ROOT environment variable."
}

if (-not $DoctorOnly -and -not $LiveCollection) {
  throw "TrendRadar collection is offline by default. Re-run with -LiveCollection to fetch current sources."
}

if (-not (Test-Path -LiteralPath $TrendRadarRoot)) {
  throw "TrendRadarRoot not found: $TrendRadarRoot"
}

$configPath = Join-Path $ConfigDir "config.yaml"
$frequencyPath = Join-Path $ConfigDir "frequency_words.txt"

if (-not (Test-Path -LiteralPath $configPath)) {
  throw "Config file not found: $configPath"
}

if (-not (Test-Path -LiteralPath $frequencyPath)) {
  throw "Frequency words file not found: $frequencyPath"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$uv = Resolve-Tool @("uv")
if (-not $uv) {
  throw "uv not found. Install uv or add it to PATH before running TrendRadar side radar."
}

$env:CONFIG_PATH = $configPath
$env:FREQUENCY_WORDS_PATH = $frequencyPath
$env:STORAGE_BACKEND = "local"
$env:STORAGE_TXT_ENABLED = "true"
$env:STORAGE_HTML_ENABLED = "true"
$env:AI_ANALYSIS_ENABLED = "false"
$env:AI_TRANSLATION_ENABLED = "false"
$env:AI_FILTER_ENABLED = "false"
$env:SCHEDULE_ENABLED = "false"
$env:PYTHONUTF8 = "1"

Push-Location $TrendRadarRoot
try {
  if (-not (Test-Path -LiteralPath ".venv")) {
    & $uv sync
    if ($LASTEXITCODE -ne 0) {
      throw "uv sync failed with exit code $LASTEXITCODE"
    }
  }

  $arguments = @("run", "python", "-m", "trendradar")
  if ($DoctorOnly) {
    $arguments += "--doctor"
  }

  $output = & $uv @arguments 2>&1
  $exitCode = $LASTEXITCODE

  $runLog = Join-Path $OutputRoot ("trendradar-run-{0}.log" -f (Get-Date -Format "yyyy-MM-dd-HH-mm-ss"))
  $output | Set-Content -LiteralPath $runLog -Encoding UTF8

  if ($exitCode -ne 0) {
    throw "TrendRadar failed with exit code $exitCode. Log: $runLog"
  }

  $dataRoot = Join-Path $OutputRoot "output"
  $latestHtml = $null
  $latestTxt = $null
  $latestNewsDb = $null
  $latestRssDb = $null

  if (Test-Path -LiteralPath $dataRoot) {
    $latestHtml = Get-ChildItem -LiteralPath $dataRoot -Recurse -Filter "*.html" -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    $latestTxt = Get-ChildItem -LiteralPath $dataRoot -Recurse -Filter "*.txt" -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    $latestNewsDb = Get-ChildItem -LiteralPath (Join-Path $dataRoot "news") -Filter "*.db" -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    $latestRssDb = Get-ChildItem -LiteralPath (Join-Path $dataRoot "rss") -Filter "*.db" -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
  }

  $summary = [pscustomobject]@{
    success = $true
    mode = if ($DoctorOnly) { "doctor" } else { "run" }
    trendradar_root = $TrendRadarRoot
    config_path = $configPath
    frequency_words_path = $frequencyPath
    output_root = $OutputRoot
    run_log = $runLog
    latest_html = if ($latestHtml) { $latestHtml.FullName } else { $null }
    latest_txt = if ($latestTxt) { $latestTxt.FullName } else { $null }
    latest_news_db = if ($latestNewsDb) { $latestNewsDb.FullName } else { $null }
    latest_rss_db = if ($latestRssDb) { $latestRssDb.FullName } else { $null }
  }

  $summaryPath = Join-Path $OutputRoot "latest-run-summary.json"
  $summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
  $summary
} finally {
  Pop-Location
}
