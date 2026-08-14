Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Invoke-ChildProcess {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$Arguments = @()
  )

  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousPreference
  }

  return [pscustomobject]@{
    ExitCode = $exitCode
    Output = (($output | Out-String).Trim())
  }
}

$briefingPath = Join-Path $repoRoot 'scripts\run-ai-daily-briefing-chain.ps1'
$collectorPath = Join-Path $repoRoot 'scripts\collect-ai-daily-signal-radar.mjs'
$trendLitePath = Join-Path $repoRoot 'scripts\run-trendradar-ai-radar-lite.ps1'
$trendWrapperPath = Join-Path $repoRoot 'scripts\run-trendradar-ai-radar.ps1'
$livePushFileName = 'invoke-ai-daily-' + 'live-push.ps1'
$livePushPath = Join-Path $repoRoot (Join-Path 'scripts' $livePushFileName)

Assert-True (-not (Test-Path -LiteralPath $livePushPath)) 'The incomplete public live-push wrapper must be removed'

$briefingText = Get-Content -LiteralPath $briefingPath -Raw -Encoding UTF8
foreach ($privateLivePushNeedle in @(
    'Invoke-DailyLivePush',
    $livePushFileName,
    'LiveFeedPath',
    'LiveScorePath',
    'LiveEndpoint',
    'SkipLivePush',
    'LiveDryRun',
    'LivePush'
  )) {
  Assert-True (-not $briefingText.Contains($privateLivePushNeedle)) "Briefing chain still exposes private live-push residue: $privateLivePushNeedle"
}

$collectorText = Get-Content -LiteralPath $collectorPath -Raw -Encoding UTF8
Assert-True (-not $collectorText.Contains('https://')) 'Collector must not contain a hardcoded HTTPS endpoint'
Assert-True ($collectorText.Contains('--aihot-endpoint')) 'Collector must accept --aihot-endpoint'
Assert-True ($collectorText.Contains('AIHOT_PUBLIC_ENDPOINT')) 'Collector must accept AIHOT_PUBLIC_ENDPOINT'
Assert-True ($collectorText.Contains('endpoint_configured: Boolean(aihotEndpoint)')) 'Collector output must record only whether the endpoint was configured'
Assert-True ($collectorText -notmatch '(?m)^\s+endpoint:\s+aihotEndpoint') 'Collector output must not persist the configured AI Hot endpoint'
Assert-True ($briefingText.Contains('SignalRadarAIHotEndpoint')) 'Briefing chain must expose the AI Hot endpoint option'
Assert-True ($briefingText.Contains('TrendRadarNewsNowApiBase')) 'Briefing chain must expose the NewsNow API base option'
Assert-True ($briefingText.Contains('TrendRadarConfigDir')) 'Briefing chain must expose the TrendRadar config directory option'

$trendLiteText = Get-Content -LiteralPath $trendLitePath -Raw -Encoding UTF8
$trendWrapperText = Get-Content -LiteralPath $trendWrapperPath -Raw -Encoding UTF8
Assert-True (-not $trendLiteText.Contains('https://')) 'TrendRadar lite must not contain a hardcoded HTTPS endpoint'
Assert-True ($trendLiteText.Contains('NewsNowApiBase')) 'TrendRadar lite must accept -NewsNowApiBase'
Assert-True ($trendLiteText.Contains('NEWSNOW_API_BASE')) 'TrendRadar lite must accept NEWSNOW_API_BASE'
Assert-True ($trendWrapperText.Contains('NewsNowApiBase')) 'TrendRadar wrapper must forward -NewsNowApiBase'

$node = (Get-Command node -ErrorAction Stop).Source
$powershell = (Get-Command powershell -ErrorAction Stop).Source
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('creator-flow-network-boundary-' + [guid]::NewGuid().ToString('N'))
$oldAIHotEndpoint = [Environment]::GetEnvironmentVariable('AIHOT_PUBLIC_ENDPOINT')
$oldNewsNowApiBase = [Environment]::GetEnvironmentVariable('NEWSNOW_API_BASE')

try {
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
  [Environment]::SetEnvironmentVariable('AIHOT_PUBLIC_ENDPOINT', $null)
  [Environment]::SetEnvironmentVariable('NEWSNOW_API_BASE', $null)

  $offlineInputPath = Join-Path $tempRoot 'aihot-offline.json'
  '{"items":[]}' | Set-Content -LiteralPath $offlineInputPath -Encoding ASCII
  [Environment]::SetEnvironmentVariable('AIHOT_PUBLIC_ENDPOINT', 'not-a-url')
  $offlineAIHot = Invoke-ChildProcess -FilePath $node -Arguments @(
    $collectorPath,
    '--aihot-input', $offlineInputPath,
    '--output-root', (Join-Path $tempRoot 'aihot-offline')
  )
  Assert-True ($offlineAIHot.ExitCode -eq 0) 'Offline AI Hot input must ignore an unused endpoint environment variable'
  [Environment]::SetEnvironmentVariable('AIHOT_PUBLIC_ENDPOINT', $null)

  $missingAIHot = Invoke-ChildProcess -FilePath $node -Arguments @(
    $collectorPath,
    '--live-collection',
    '--output-root', (Join-Path $tempRoot 'aihot-missing')
  )
  Assert-True ($missingAIHot.ExitCode -ne 0) 'Live AI Hot collection must fail when no endpoint is configured'
  Assert-True ($missingAIHot.Output -match '--aihot-endpoint|AIHOT_PUBLIC_ENDPOINT') 'Missing AI Hot endpoint error must explain both configuration options'

  $unsafeAIHot = Invoke-ChildProcess -FilePath $node -Arguments @(
    $collectorPath,
    '--live-collection',
    '--aihot-endpoint', 'http://example.test/api/items',
    '--output-root', (Join-Path $tempRoot 'aihot-http')
  )
  Assert-True ($unsafeAIHot.ExitCode -ne 0) 'Live AI Hot collection must reject a non-HTTPS endpoint'
  Assert-True ($unsafeAIHot.Output -match 'HTTPS') 'Unsafe AI Hot endpoint error must require HTTPS'

  $configDir = Join-Path $tempRoot 'trend-config'
  New-Item -ItemType Directory -Force -Path $configDir | Out-Null
  @'
platforms:
  sources:
    - id: "example"
      name: "Example"
      expected_domain: "example.com"
rss:
  feeds:
'@ | Set-Content -LiteralPath (Join-Path $configDir 'config.yaml') -Encoding UTF8

  $missingNewsNow = Invoke-ChildProcess -FilePath $powershell -Arguments @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $trendLitePath,
    '-ConfigDir', $configDir,
    '-OutputRoot', (Join-Path $tempRoot 'trend-output'),
    '-LiveCollection'
  )
  Assert-True ($missingNewsNow.ExitCode -ne 0) 'Platform collection must fail when no NewsNow API base is configured'
  Assert-True ($missingNewsNow.Output -match '-NewsNowApiBase|NEWSNOW_API_BASE') 'Missing NewsNow API base error must explain both configuration options'

  $missingConfigDir = Join-Path $tempRoot 'missing-config'
  $missingConfig = Invoke-ChildProcess -FilePath $powershell -Arguments @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $trendLitePath,
    '-ConfigDir', $missingConfigDir,
    '-OutputRoot', (Join-Path $tempRoot 'missing-config-output'),
    '-LiveCollection'
  )
  Assert-True ($missingConfig.ExitCode -ne 0) 'TrendRadar lite must fail when config.yaml is missing'
  Assert-True ($missingConfig.Output -match 'config.yaml') 'Missing TrendRadar config error must name config.yaml'
  Assert-True ($missingConfig.Output -match '-ConfigDir') 'Missing TrendRadar config error must explain how to set the config directory'
}
finally {
  [Environment]::SetEnvironmentVariable('AIHOT_PUBLIC_ENDPOINT', $oldAIHotEndpoint)
  [Environment]::SetEnvironmentVariable('NEWSNOW_API_BASE', $oldNewsNowApiBase)
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}

Write-Host 'public network boundary tests passed'
