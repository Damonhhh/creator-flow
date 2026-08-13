Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$resolverPath = Join-Path $repoRoot "scripts\lib\resolve-zimeiti-config.ps1"
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("zimeiti-config-test-" + [guid]::NewGuid().ToString("N"))

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Write-Utf8 {
  param([string]$Path, [string]$Content)
  $parent = Split-Path -Parent $Path
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

Assert-True (Test-Path -LiteralPath $resolverPath) "Missing scripts/lib/resolve-zimeiti-config.ps1"
. $resolverPath

try {
  New-Item -ItemType Directory -Force -Path (Join-Path $testRoot "config") | Out-Null
  Write-Utf8 -Path (Join-Path $testRoot "config\workflow.example.json") -Content '{"mode":"example"}'
  Write-Utf8 -Path (Join-Path $testRoot "config\workflow.local.json") -Content '{"mode":"local","nested":{"required":"present"},"secret":"do-not-print-this-value"}'
  Write-Utf8 -Path (Join-Path $testRoot "explicit.json") -Content '{"mode":"explicit","nested":{"required":"present"}}'

  $local = Get-ZimeitiConfig -RepoRoot $testRoot -Name "workflow" -RequiredKeys @("nested.required")
  Assert-True ($local.mode -eq "local") "Expected local config by default"

  $explicit = Get-ZimeitiConfig -RepoRoot $testRoot -Name "workflow" -ConfigPath (Join-Path $testRoot "explicit.json") -RequiredKeys @("nested.required")
  Assert-True ($explicit.mode -eq "explicit") "Expected explicit config to win"

  $relative = Resolve-ZimeitiConfigPath -RepoRoot $testRoot -Value "assets\voice.wav"
  Assert-True ($relative -eq (Join-Path $testRoot "assets\voice.wav")) "Expected relative path to resolve from repo root"

  Remove-Item -LiteralPath (Join-Path $testRoot "config\workflow.local.json") -Force
  $missingMessage = ""
  try {
    Get-ZimeitiConfig -RepoRoot $testRoot -Name "workflow" | Out-Null
  }
  catch {
    $missingMessage = $_.Exception.Message
  }
  Assert-True ($missingMessage.Contains("workflow.example.json")) "Missing config error must name the example file"
  Assert-True (-not $missingMessage.Contains("do-not-print-this-value")) "Config error leaked a private value"

  Write-Utf8 -Path (Join-Path $testRoot "config\workflow.local.json") -Content '{"mode":"local","secret":"do-not-print-this-value"}'
  $keyMessage = ""
  try {
    Get-ZimeitiConfig -RepoRoot $testRoot -Name "workflow" -RequiredKeys @("nested.required") | Out-Null
  }
  catch {
    $keyMessage = $_.Exception.Message
  }
  Assert-True ($keyMessage.Contains("nested.required")) "Missing key error must name the key"
  Assert-True (-not $keyMessage.Contains("do-not-print-this-value")) "Missing key error leaked config contents"

  Write-Host "workflow config tests passed"
}
finally {
  if (Test-Path -LiteralPath $testRoot) {
    $resolved = (Resolve-Path -LiteralPath $testRoot).Path
    if ($resolved.StartsWith(([IO.Path]::GetTempPath()).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolved).StartsWith("zimeiti-config-test-")) {
      Remove-Item -LiteralPath $resolved -Recurse -Force
    }
  }
}
