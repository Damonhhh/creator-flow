Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Resolve-CreatorFlowRoot {
  param([string]$CreatorFlowRoot = '')

  $candidates = New-Object System.Collections.Generic.List[string]
  if (-not [string]::IsNullOrWhiteSpace($CreatorFlowRoot)) {
    $candidates.Add($CreatorFlowRoot)
  }
  $candidates.Add((Get-Location).Path)
  $candidates.Add((Join-Path $PSScriptRoot '..\creator-flow'))
  $candidates.Add((Join-Path $PSScriptRoot '..\..\creator-flow'))

  foreach ($candidate in $candidates) {
    try {
      $resolved = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($candidate))
    }
    catch { continue }
    $resolver = Join-Path $resolved 'scripts\resolve-workflow-dependencies.ps1'
    if (Test-Path -LiteralPath $resolver -PathType Leaf) { return $resolved }
  }

  throw 'CreatorFlow root was not found. Pass the extracted creator-flow directory with -CreatorFlowRoot.'
}

function Invoke-CreatorFlowResolver {
  param(
    [Parameter(Mandatory = $true)][string]$CreatorFlowRoot,
    [Parameter(Mandatory = $true)][ValidateSet('Core', 'ScriptTTS', 'Material', 'Assembly')][string]$Stage,
    [string]$ProjectDir = '',
    [string]$TtsConfigPath = '',
    [string]$ToolRoot = '',
    [string]$AcceptAction = ''
  )

  $resolver = Join-Path $CreatorFlowRoot 'scripts\resolve-workflow-dependencies.ps1'
  $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $resolver, '-Stage', $Stage)
  if (-not [string]::IsNullOrWhiteSpace($ProjectDir)) { $arguments += @('-ProjectDir', $ProjectDir) }
  if (-not [string]::IsNullOrWhiteSpace($TtsConfigPath)) { $arguments += @('-TtsConfigPath', $TtsConfigPath) }
  if (-not [string]::IsNullOrWhiteSpace($ToolRoot)) { $arguments += @('-ToolRoot', $ToolRoot) }
  if (-not [string]::IsNullOrWhiteSpace($AcceptAction)) { $arguments += @('-AcceptAction', $AcceptAction) }

  & powershell @arguments
  $exitCode = $LASTEXITCODE
  if ($exitCode -notin @(0, 2)) { throw "CreatorFlow dependency resolver failed with exit code $exitCode." }
  return $exitCode
}

function Open-CreatorFlowOfficialPages {
  param([Parameter(Mandatory = $true)][string[]]$Urls)

  foreach ($url in $Urls) {
    if ($url -notmatch '^https://') { throw "Only HTTPS official pages may be opened: $url" }
    Start-Process $url
  }
}
