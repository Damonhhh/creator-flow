param(
  [string]$OutputRoot = (Join-Path (Join-Path $PSScriptRoot '..') '.generated\trae-work-brand'),
  [string]$PackageName = 'CreatorFlow-TRAE-Work',
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Get-NormalizedFullPath {
  param([string]$PathValue)
  return [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($PathValue.Trim()))
}

function Test-PathInsideRoot {
  param([string]$PathValue, [string]$RootValue)
  $path = (Get-NormalizedFullPath $PathValue).TrimEnd([char]'\', [char]'/')
  $root = (Get-NormalizedFullPath $RootValue).TrimEnd([char]'\', [char]'/')
  return $path.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Resolve-SafeOutputRoot {
  param([string]$PathValue, [string]$SourceRoot)
  $resolved = (Get-NormalizedFullPath $PathValue).TrimEnd([char]'\', [char]'/')
  $driveRoot = ([IO.Path]::GetPathRoot($resolved)).TrimEnd([char]'\', [char]'/')
  $source = (Get-NormalizedFullPath $SourceRoot).TrimEnd([char]'\', [char]'/')
  $userProfile = (Get-NormalizedFullPath ([Environment]::GetFolderPath('UserProfile'))).TrimEnd([char]'\', [char]'/')
  foreach ($blocked in @($driveRoot, $source, $userProfile, (Split-Path -Parent $source))) {
    if ($resolved.Equals($blocked, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Unsafe output root: $resolved"
    }
  }
  return $resolved
}

function Resolve-RelativePath {
  param([string]$Root, [string]$RelativePath)
  if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
    throw "Unsafe relative path: $RelativePath"
  }
  $resolved = Get-NormalizedFullPath (Join-Path $Root ($RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)))
  if (-not (Test-PathInsideRoot -PathValue $resolved -RootValue $Root)) { throw "Path escapes root: $RelativePath" }
  return $resolved
}

function Test-IsTextFile {
  param([string]$PathValue)
  $extensions = @('', '.md', '.txt', '.json', '.jsonl', '.ps1', '.psm1', '.py', '.mjs', '.js', '.ts', '.tsx', '.css', '.html', '.yml', '.yaml', '.toml')
  return $extensions -contains [IO.Path]::GetExtension($PathValue).ToLowerInvariant()
}

$sourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resolvedOutputRoot = Resolve-SafeOutputRoot -PathValue $OutputRoot -SourceRoot $sourceRoot
$approvedRepositoryUrl = 'https://github.com/Damonhhh/creator-flow'
if ($PackageName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]+$') { throw "Unsafe package name: $PackageName" }

$manifestPath = Join-Path $sourceRoot 'public-export-manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.repository -ne 'creator-flow' -or @($manifest.files).Count -eq 0) { throw 'Unexpected public export manifest' }

$excludedScripts = @(
  'scripts/export-public-workflow.ps1',
  'scripts/test-public-release.ps1',
  'scripts/export-trae-work-brand-package.ps1',
  'scripts/test-trae-work-package.ps1'
)
$entries = @($manifest.files | Where-Object {
  $relative = ([string]$_.destination -replace '\\', '/')
  ($relative -eq 'LICENSE' -or $relative -match '^(\.agents|config|docs|examples|scripts)/') -and
  $relative -ne 'docs/installation.md' -and
  $excludedScripts -notcontains $relative
})
if ($entries.Count -lt 20) { throw "Brand package whitelist is unexpectedly small: $($entries.Count)" }

$stagingBase = Join-Path $sourceRoot '.generated\trae-work-brand-staging'
$stagingParent = Join-Path $stagingBase ([guid]::NewGuid().ToString('N'))
$stagingPackage = Join-Path $stagingParent $PackageName
New-Item -ItemType Directory -Force -Path $stagingPackage | Out-Null

try {
  foreach ($entry in $entries) {
    $relative = ([string]$entry.destination -replace '\\', '/')
    $source = Resolve-RelativePath -Root $sourceRoot -RelativePath $relative
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing whitelisted source file: $relative" }
    $target = Resolve-RelativePath -Root $stagingPackage -RelativePath $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
  }

  $overlays = @{
    'packaging/trae-work/README.md' = 'README.md'
    'packaging/trae-work/installation.md' = 'docs/installation.md'
    'scripts/test-trae-work-package.ps1' = 'scripts/test-trae-work-package.ps1'
  }
  foreach ($sourceRelative in $overlays.Keys) {
    $source = Resolve-RelativePath -Root $sourceRoot -RelativePath $sourceRelative
    $target = Resolve-RelativePath -Root $stagingPackage -RelativePath $overlays[$sourceRelative]
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
  }

  $forbiddenPlatforms = @(
    [string]::Concat([char[]](99, 111, 100, 101, 120)),
    [string]::Concat([char[]](67, 108, 97, 117, 100, 101, 32, 67, 111, 100, 101)),
    [string]::Concat([char[]](79, 112, 101, 110, 67, 108, 97, 119)),
    [string]::Concat([char[]](72, 101, 114, 109, 101, 115))
  )
  $utf8NoBom = [Text.UTF8Encoding]::new($false)
  foreach ($file in @(Get-ChildItem -LiteralPath $stagingPackage -File -Recurse -Force)) {
    $relative = $file.FullName.Substring($stagingPackage.Length).TrimStart([char]'\', [char]'/') -replace '\\', '/'
    foreach ($forbiddenPlatform in $forbiddenPlatforms) {
      if ($relative -match ('(?i)' + [regex]::Escape($forbiddenPlatform))) { throw "Forbidden platform name in filename: $relative" }
    }
    if (-not (Test-IsTextFile -PathValue $file.FullName)) { continue }
    $content = [IO.File]::ReadAllText($file.FullName)
    foreach ($forbiddenPlatform in $forbiddenPlatforms) {
      if ($content -match ('(?i)' + [regex]::Escape($forbiddenPlatform))) {
        $replacement = if ($relative -match '^scripts/') { 'TRAE' } else { 'TRAE Work' }
        $content = [regex]::Replace($content, [regex]::Escape($forbiddenPlatform), $replacement, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
      }
    }
    [IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
  }

  $packageFiles = @()
  foreach ($file in @(Get-ChildItem -LiteralPath $stagingPackage -File -Recurse -Force | Sort-Object FullName)) {
    $relative = $file.FullName.Substring($stagingPackage.Length).TrimStart([char]'\', [char]'/') -replace '\\', '/'
    $packageFiles += [ordered]@{
      path = $relative
      sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      bytes = $file.Length
    }
  }
  $packageManifest = [ordered]@{
    schemaVersion = 1
    product = 'CreatorFlow'
    platform = 'TRAE Work'
    package = $PackageName
    repository = $approvedRepositoryUrl
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    files = $packageFiles
  }
  [IO.File]::WriteAllText(
    (Join-Path $stagingPackage 'package-manifest.json'),
    (($packageManifest | ConvertTo-Json -Depth 8) + "`n"),
    $utf8NoBom
  )

  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $stagingPackage 'scripts\test-trae-work-package.ps1') -PackageRoot $stagingPackage
  if ($LASTEXITCODE -ne 0) { throw 'Brand package validation failed' }

  New-Item -ItemType Directory -Force -Path $resolvedOutputRoot | Out-Null
  $finalPackage = Join-Path $resolvedOutputRoot $PackageName
  $finalArchive = Join-Path $resolvedOutputRoot ($PackageName + '.zip')
  if ((Test-Path -LiteralPath $finalPackage) -or (Test-Path -LiteralPath $finalArchive)) {
    if (-not $Force) { throw "Output already exists; rerun with -Force: $resolvedOutputRoot" }
    if (Test-Path -LiteralPath $finalPackage) { Remove-Item -LiteralPath $finalPackage -Recurse -Force }
    if (Test-Path -LiteralPath $finalArchive) { Remove-Item -LiteralPath $finalArchive -Force }
  }

  Move-Item -LiteralPath $stagingPackage -Destination $finalPackage
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [IO.Compression.ZipFile]::CreateFromDirectory($finalPackage, $finalArchive, [IO.Compression.CompressionLevel]::Optimal, $true)

  Write-Host "TRAE Work brand package exported:"
  Write-Host "- Directory: $finalPackage"
  Write-Host "- Archive:   $finalArchive"
}
finally {
  if (Test-Path -LiteralPath $stagingParent) {
    $resolvedStaging = (Resolve-Path -LiteralPath $stagingParent).Path
    if (-not (Test-PathInsideRoot -PathValue $resolvedStaging -RootValue $stagingBase)) { throw "Unsafe staging cleanup target: $resolvedStaging" }
    Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
  }
}
