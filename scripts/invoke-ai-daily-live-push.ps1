param(
  [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
  [string]$FeedPath = "",
  [string]$ScorePath = "",
  [string]$Endpoint = "",
  [switch]$DryRun,
  [switch]$LiveCollection,
  [switch]$Skip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Skip) {
  [pscustomobject]@{ Success = $true; Skipped = $true; Reason = "skipped_by_request" }
  return
}

if ([string]::IsNullOrWhiteSpace($FeedPath)) {
  [pscustomobject]@{ Success = $true; Skipped = $true; Reason = "public_feed_not_supplied" }
  return
}

if (-not $DryRun -and -not $LiveCollection) {
  [pscustomobject]@{ Success = $true; Skipped = $true; Reason = "live_collection_not_enabled" }
  return
}

$pushScript = Join-Path $PSScriptRoot "push-ai-daily-live-feed.mjs"
if (-not (Test-Path -LiteralPath $pushScript)) {
  throw "AI daily live push failed: missing push script: $pushScript"
}

$resolvedEndpoint = if (-not [string]::IsNullOrWhiteSpace($Endpoint)) { $Endpoint } else { [Environment]::GetEnvironmentVariable("AI_DAILY_LIVE_ENDPOINT") }
$hasSecret = -not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable("AI_DAILY_LIVE_SECRET"))
if (-not $DryRun -and ([string]::IsNullOrWhiteSpace($resolvedEndpoint) -or -not $hasSecret)) {
  [pscustomobject]@{ Success = $true; Skipped = $true; Reason = "live_endpoint_not_configured" }
  return
}

$arguments = @($pushScript, "--date", $Date, "--feed", $FeedPath)
if (-not [string]::IsNullOrWhiteSpace($ScorePath)) { $arguments += @("--scores", $ScorePath) }
if (-not [string]::IsNullOrWhiteSpace($resolvedEndpoint)) { $arguments += @("--endpoint", $resolvedEndpoint) }
if ($DryRun) { $arguments += "--dry-run" }

$rawResult = @(& node @arguments)
if ($LASTEXITCODE -ne 0) {
  throw "AI daily live push failed with exit code $LASTEXITCODE"
}
$jsonLine = @($rawResult | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Last 1)
if (-not $jsonLine) {
  throw "AI daily live push returned no structured result"
}
$parsed = ([string]$jsonLine) | ConvertFrom-Json
[pscustomobject]@{
  Success = [bool]$parsed.success
  Skipped = $false
  DryRun = [bool]$parsed.dryRun
  RunId = $parsed.runId
  InputCount = $parsed.diagnostics.inputCount
  SkippedCount = $parsed.diagnostics.skippedCount
  ScoredCount = $parsed.diagnostics.scoredCount
  ScoringFailedCount = $parsed.diagnostics.scoringFailedCount
}
