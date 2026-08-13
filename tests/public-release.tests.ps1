Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$gatePath = Join-Path $repoRoot 'scripts\test-public-release.ps1'

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

Assert-True (Test-Path -LiteralPath $gatePath -PathType Leaf) 'Missing scripts/test-public-release.ps1'

. $gatePath

$requiredFunctions = @(
  'Read-PublicReleaseManifest',
  'Test-PublicManifestIntegrity',
  'Test-PublicGitState',
  'Test-PublicRequiredLayout'
)
foreach ($name in $requiredFunctions) {
  Assert-True ($null -ne (Get-Command $name -CommandType Function -ErrorAction SilentlyContinue)) "Missing release-gate function: $name"
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('zimeiti-public-release-test-' + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
  [IO.File]::WriteAllText((Join-Path $testRoot 'README.md'), "# Fixture`n", [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $testRoot 'LICENSE'), "MIT License`n", [Text.UTF8Encoding]::new($false))

  $readmeHash = (Get-FileHash -LiteralPath (Join-Path $testRoot 'README.md') -Algorithm SHA256).Hash.ToLowerInvariant()
  $licenseHash = (Get-FileHash -LiteralPath (Join-Path $testRoot 'LICENSE') -Algorithm SHA256).Hash.ToLowerInvariant()
  $manifest = [ordered]@{
    schemaVersion = 1
    repository = 'zimeiti-video-workflow'
    license = 'MIT'
    files = @(
      [ordered]@{ source = 'open-source/README.md'; destination = 'README.md'; sha256 = $readmeHash },
      [ordered]@{ source = 'open-source/LICENSE'; destination = 'LICENSE'; sha256 = $licenseHash },
      [ordered]@{ source = 'public-export-manifest.json'; destination = 'public-export-manifest.json' }
    )
  }
  [IO.File]::WriteAllText(
    (Join-Path $testRoot 'public-export-manifest.json'),
    ($manifest | ConvertTo-Json -Depth 8),
    [Text.UTF8Encoding]::new($false)
  )

  $parsed = Read-PublicReleaseManifest -PackageRoot $testRoot
  $integrity = Test-PublicManifestIntegrity -PackageRoot $testRoot -Manifest $parsed
  Assert-True ($integrity.CheckedFiles -eq 2) 'Expected two hashed fixture files'

  [IO.File]::AppendAllText((Join-Path $testRoot 'README.md'), "tampered`n", [Text.UTF8Encoding]::new($false))
  $tamperRejected = $false
  try {
    Test-PublicManifestIntegrity -PackageRoot $testRoot -Manifest $parsed | Out-Null
  }
  catch {
    $tamperRejected = $_.Exception.Message -match 'SHA256 mismatch'
  }
  Assert-True $tamperRejected 'Expected a modified manifest file to fail SHA256 verification'

  Write-Host 'public release tests passed'
}
finally {
  if (Test-Path -LiteralPath $testRoot) {
    $resolved = (Resolve-Path -LiteralPath $testRoot).Path
    $temp = ([IO.Path]::GetTempPath()).TrimEnd('\')
    if ($resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolved).StartsWith('zimeiti-public-release-test-')) {
      Remove-Item -LiteralPath $resolved -Recurse -Force
    }
  }
}
