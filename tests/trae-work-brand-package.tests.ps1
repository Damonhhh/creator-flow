Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('creator-flow-trae-brand-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

try {
  $exporter = Join-Path $repoRoot 'scripts\export-trae-work-brand-package.ps1'
  & powershell -NoProfile -ExecutionPolicy Bypass -File $exporter -OutputRoot $testRoot
  Assert-True ($LASTEXITCODE -eq 0) 'Brand exporter failed'

  $packageRoot = Join-Path $testRoot 'CreatorFlow-TRAE-Work'
  $archive = Join-Path $testRoot 'CreatorFlow-TRAE-Work.zip'
  Assert-True (Test-Path -LiteralPath $packageRoot -PathType Container) 'Package directory was not created'
  Assert-True (Test-Path -LiteralPath $archive -PathType Leaf) 'Package archive was not created'
  foreach ($relative in @(
      'docs\first-real-run.md',
      'docs\workflow-thread-map.md',
      'docs\assets\real-case-ai-literacy-ep02-keyframes.jpg',
      'docs\assets\creatorflow-workflow-roadmap.png'
    )) {
    Assert-True (Test-Path -LiteralPath (Join-Path $packageRoot $relative) -PathType Leaf) "Brand package is missing required guide asset: $relative"
  }

  $validator = Join-Path $packageRoot 'scripts\test-trae-work-package.ps1'
  & powershell -NoProfile -ExecutionPolicy Bypass -File $validator -PackageRoot $packageRoot
  Assert-True ($LASTEXITCODE -eq 0) 'Generated package validation failed'

  $approvedRepositoryUrl = 'https://github.com/Damonhhh/creator-flow'
  foreach ($relative in @('README.md', 'docs\installation.md')) {
    $content = Get-Content -LiteralPath (Join-Path $packageRoot $relative) -Raw -Encoding UTF8
    Assert-True ($content -match [regex]::Escape($approvedRepositoryUrl)) "Approved repository URL missing from: $relative"
  }
  $packageManifest = Get-Content -LiteralPath (Join-Path $packageRoot 'package-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($packageManifest.repository -eq $approvedRepositoryUrl) 'Package manifest repository URL is incorrect'

  $forbiddenPlatforms = @(
    [string]::Concat([char[]](99, 111, 100, 101, 120)),
    [string]::Concat([char[]](67, 108, 97, 117, 100, 101, 32, 67, 111, 100, 101)),
    [string]::Concat([char[]](79, 112, 101, 110, 67, 108, 97, 119)),
    [string]::Concat([char[]](72, 101, 114, 109, 101, 115))
  )
  foreach ($file in @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse -Force)) {
    $relative = $file.FullName.Substring($packageRoot.Length).TrimStart([char]'\', [char]'/') -replace '\\', '/'
    foreach ($forbiddenPlatform in $forbiddenPlatforms) {
      Assert-True ($relative -notmatch ('(?i)' + [regex]::Escape($forbiddenPlatform))) "Forbidden platform name in path: $relative"
    }
    if ([IO.Path]::GetExtension($file.Name).ToLowerInvariant() -in @('.md', '.txt', '.json', '.ps1', '.py', '.mjs')) {
      $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
      foreach ($forbiddenPlatform in $forbiddenPlatforms) {
        Assert-True ($content -notmatch ('(?i)' + [regex]::Escape($forbiddenPlatform))) "Forbidden platform name in file: $relative"
      }
    }
  }

  foreach ($excluded in @('tests', 'public-export-manifest.json', 'scripts\export-public-workflow.ps1', 'scripts\test-public-release.ps1')) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $packageRoot $excluded))) "Development-only path included: $excluded"
  }

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [IO.Compression.ZipFile]::OpenRead($archive)
  try {
    Assert-True ($zip.Entries.Count -gt 20) 'Archive is unexpectedly small'
    foreach ($entry in $zip.Entries) {
      foreach ($forbiddenPlatform in $forbiddenPlatforms) {
        Assert-True ($entry.FullName -notmatch ('(?i)' + [regex]::Escape($forbiddenPlatform))) "Forbidden platform name in ZIP path: $($entry.FullName)"
      }
    }
  }
  finally { $zip.Dispose() }

  Write-Host 'TRAE Work brand package tests passed'
}
finally {
  $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot).TrimEnd([char]'\', [char]'/')
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]'\', [char]'/')
  if ($resolvedTestRoot.StartsWith($tempRoot + '\', [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolvedTestRoot) -like 'creator-flow-trae-brand-*') {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
  }
}
