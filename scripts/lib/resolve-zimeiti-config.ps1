Set-StrictMode -Version Latest

function Resolve-ZimeitiConfigPath {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [AllowEmptyString()][string]$Value
  )
  if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
  $expanded = [Environment]::ExpandEnvironmentVariables($Value.Trim().Trim('"', "'"))
  if ([IO.Path]::IsPathRooted($expanded)) {
    return [IO.Path]::GetFullPath($expanded)
  }
  return [IO.Path]::GetFullPath((Join-Path $RepoRoot $expanded))
}

function Get-ZimeitiNestedProperty {
  param(
    [Parameter(Mandatory = $true)][object]$Object,
    [Parameter(Mandatory = $true)][string]$DottedKey
  )
  $cursor = $Object
  foreach ($part in $DottedKey.Split('.')) {
    if ($null -eq $cursor) { return [ordered]@{ Found = $false; Value = $null } }
    $property = $cursor.PSObject.Properties[$part]
    if ($null -eq $property) { return [ordered]@{ Found = $false; Value = $null } }
    $cursor = $property.Value
  }
  return [ordered]@{ Found = $true; Value = $cursor }
}

function Get-ZimeitiConfig {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z][a-z0-9-]*$')][string]$Name,
    [string]$ConfigPath = '',
    [string[]]$RequiredKeys = @()
  )
  $resolvedRoot = [IO.Path]::GetFullPath($RepoRoot)
  $examplePath = Join-Path $resolvedRoot ("config\{0}.example.json" -f $Name)
  $resolvedPath = if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    Join-Path $resolvedRoot ("config\{0}.local.json" -f $Name)
  }
  else {
    Resolve-ZimeitiConfigPath -RepoRoot $resolvedRoot -Value $ConfigPath
  }

  if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
    throw "Missing local config '$Name'. Copy and edit: $examplePath"
  }

  try {
    $config = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
  }
  catch {
    throw "Invalid JSON in local config '$Name': $resolvedPath"
  }

  foreach ($key in $RequiredKeys) {
    if ([string]::IsNullOrWhiteSpace($key)) { continue }
    $result = Get-ZimeitiNestedProperty -Object $config -DottedKey $key
    if (-not $result.Found) {
      throw "Missing required config key: $key"
    }
  }
  return $config
}
