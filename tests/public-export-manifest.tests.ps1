Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$manifestPath = Join-Path $repoRoot "public-export-manifest.json"

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

Assert-True (Test-Path -LiteralPath $manifestPath) "Missing public-export-manifest.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

Assert-True ($manifest.schemaVersion -eq 1) "Expected schemaVersion 1"
Assert-True ($manifest.repository -eq "creator-flow") "Expected repository name creator-flow"
Assert-True ($manifest.license -eq "MIT") "Expected MIT license"
Assert-True (@($manifest.files).Count -ge 4) "Expected at least four manifest files"

$destinations = @{}
foreach ($entry in @($manifest.files)) {
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$entry.source)) "Manifest entry source is required"
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$entry.destination)) "Manifest entry destination is required"
  Assert-True (-not [IO.Path]::IsPathRooted([string]$entry.source)) "Source must be relative: $($entry.source)"
  Assert-True (-not [IO.Path]::IsPathRooted([string]$entry.destination)) "Destination must be relative: $($entry.destination)"
  Assert-True ([string]$entry.source -notmatch '(^|[\\/])\.\.([\\/]|$)') "Parent traversal is forbidden: $($entry.source)"
  Assert-True ([string]$entry.destination -notmatch '(^|[\\/])\.\.([\\/]|$)') "Parent traversal is forbidden: $($entry.destination)"
  Assert-True ([string]$entry.source -notmatch '\*\*') "Recursive wildcards are forbidden: $($entry.source)"
  Assert-True (-not $destinations.ContainsKey([string]$entry.destination)) "Duplicate destination: $($entry.destination)"
  $destinations[[string]$entry.destination] = $true
}

$requiredMappings = @{
  "open-source/README.md" = "README.md"
  "open-source/LICENSE" = "LICENSE"
  "open-source/.gitignore" = ".gitignore"
  "public-export-manifest.json" = "public-export-manifest.json"
}
foreach ($source in $requiredMappings.Keys) {
  $matches = @($manifest.files | Where-Object {
    ([string]$_.source -replace '\\', '/') -eq $source -and
    ([string]$_.destination -replace '\\', '/') -eq $requiredMappings[$source]
  })
  Assert-True ($matches.Count -eq 1) "Missing required manifest mapping: $source -> $($requiredMappings[$source])"
}

Write-Host "public export manifest tests passed"
