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

$requiredMappings = @(
  @{ sources = @("open-source/README.md", "README.md"); destination = "README.md" }
  @{ sources = @("open-source/LICENSE", "LICENSE"); destination = "LICENSE" }
  @{ sources = @("open-source/.gitignore", ".gitignore"); destination = ".gitignore" }
  @{ sources = @("public-export-manifest.json"); destination = "public-export-manifest.json" }
  @{ sources = @("scripts/test-video-publish-copy.ps1"); destination = "scripts/test-video-publish-copy.ps1" }
  @{ sources = @("scripts/test-video-screen-ownership.ps1"); destination = "scripts/test-video-screen-ownership.ps1" }
  @{ sources = @("tests/video-publish-copy.tests.ps1"); destination = "tests/video-publish-copy.tests.ps1" }
  @{ sources = @("tests/video-screen-ownership.tests.ps1"); destination = "tests/video-screen-ownership.tests.ps1" }
  @{ sources = @(".agents/skills/zimeiti-video-workflow/references/publish-copy-contract.md"); destination = ".agents/skills/zimeiti-video-workflow/references/publish-copy-contract.md" }
  @{ sources = @(".agents/skills/zimeiti-video-workflow/references/screen-ownership-contract.md"); destination = ".agents/skills/zimeiti-video-workflow/references/screen-ownership-contract.md" }
  @{ sources = @(".agents/skills/zimeiti-video-workflow/references/presenter-led-mixed-media-style.md"); destination = ".agents/skills/zimeiti-video-workflow/references/presenter-led-mixed-media-style.md" }
)
foreach ($mapping in $requiredMappings) {
  $acceptedSources = @($mapping.sources)
  $destination = [string]$mapping.destination
  $matches = @($manifest.files | Where-Object {
    $acceptedSources -contains ([string]$_.source -replace '\\', '/') -and
    ([string]$_.destination -replace '\\', '/') -eq $destination
  })
  Assert-True ($matches.Count -eq 1) "Missing required manifest mapping: [$($acceptedSources -join ' or ')] -> $destination"
}

Write-Host "public export manifest tests passed"
