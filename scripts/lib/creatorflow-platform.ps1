Set-StrictMode -Version Latest

function Get-CreatorFlowPlatform {
  if ([Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([Runtime.InteropServices.OSPlatform]::OSX)) { return 'macos' }
  if ([Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([Runtime.InteropServices.OSPlatform]::Linux)) { return 'linux' }
  return 'windows'
}

function Get-CreatorFlowPathComparison {
  if ((Get-CreatorFlowPlatform) -eq 'windows') {
    return [StringComparison]::OrdinalIgnoreCase
  }
  return [StringComparison]::Ordinal
}

function Get-CreatorFlowPowerShellCommand {
  foreach ($name in @('pwsh', 'powershell')) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
  }
  throw 'PowerShell 7 (pwsh) or Windows PowerShell (powershell) was not found.'
}

function Get-CreatorFlowPythonCommand {
  $candidates = if ((Get-CreatorFlowPlatform) -eq 'windows') {
    @('python', 'py', 'python3')
  }
  else {
    @('python3', 'python')
  }
  foreach ($name in $candidates) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
  }
  throw 'Python 3 was not found.'
}

function Join-CreatorFlowPath {
  param(
    [Parameter(Mandatory = $true)][string]$BasePath,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  if ([IO.Path]::IsPathRooted($RelativePath)) {
    throw "Expected a relative path, got: $RelativePath"
  }

  $result = $BasePath
  foreach ($segment in @($RelativePath -split '[\\/]')) {
    if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.') { continue }
    if ($segment -eq '..') { throw "Parent traversal is not allowed: $RelativePath" }
    $result = Join-Path $result $segment
  }
  return $result
}

function Resolve-CreatorFlowCommandName {
  param([Parameter(Mandatory = $true)][string]$Name)
  if ($Name -eq 'powershell') { return Get-CreatorFlowPowerShellCommand }
  if ($Name -eq 'python') { return Get-CreatorFlowPythonCommand }
  return $Name
}
