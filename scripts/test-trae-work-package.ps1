param(
  [string]$PackageRoot = (Join-Path $PSScriptRoot '..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Resolve-PackagePath {
  param([string]$Root, [string]$RelativePath)
  if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
    throw "Unsafe package path: $RelativePath"
  }
  $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd([char]'\', [char]'/')
  $resolved = [IO.Path]::GetFullPath((Join-Path $resolvedRoot ($RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))))
  if (-not $resolved.StartsWith($resolvedRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Package path escapes root: $RelativePath"
  }
  return $resolved
}

function Get-TextExtensions {
  return @('', '.md', '.txt', '.json', '.jsonl', '.ps1', '.psm1', '.py', '.mjs', '.js', '.ts', '.tsx', '.css', '.html', '.yml', '.yaml', '.toml')
}

$root = [IO.Path]::GetFullPath($PackageRoot).TrimEnd([char]'\', [char]'/')
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Package root does not exist: $root" }
$approvedRepositoryOwner = [string]::Concat([char[]](68, 97, 109, 111, 110, 104, 104, 104))
$approvedRepositoryUrl = 'https://github.com/' + $approvedRepositoryOwner + '/creator-flow'
$approvedRepositoryFiles = @('README.md', 'docs/installation.md', 'package-manifest.json')

$required = @(
  'README.md',
  'LICENSE',
  'package-manifest.json',
  'docs/installation.md',
  'docs/dependency-matrix.md',
  'config/workflow.example.json',
  'config/tts.example.json',
  'config/providers.example.json',
  'config/publish.example.json',
  '.agents/skills/zimeiti-video-workflow/SKILL.md',
  '.agents/skills/zimeiti-video-wrap-up/SKILL.md',
  'scripts/test-trae-work-package.ps1',
  'scripts/test-workflow-capabilities.ps1',
  'scripts/new-video-project.ps1'
)
foreach ($relative in $required) {
  if (-not (Test-Path -LiteralPath (Resolve-PackagePath -Root $root -RelativePath $relative) -PathType Leaf)) {
    throw "Missing required package file: $relative"
  }
}

$forbiddenPlatforms = @(
  [string]::Concat([char[]](99, 111, 100, 101, 120)),
  [string]::Concat([char[]](67, 108, 97, 117, 100, 101, 32, 67, 111, 100, 101)),
  [string]::Concat([char[]](79, 112, 101, 110, 67, 108, 97, 119)),
  [string]::Concat([char[]](72, 101, 114, 109, 101, 115))
)
$forbiddenIdentity = @(
  [string]::Concat([char[]](68, 97, 109, 111, 110, 104, 104, 104)),
  [string]::Concat([char[]](104, 117, 97, 110, 103, 104, 97, 111, 104, 97, 111)),
  [string]::Concat([char[]](50, 56, 49, 56, 48, 57, 49, 57, 54))
)
$files = @(Get-ChildItem -LiteralPath $root -File -Recurse -Force)
foreach ($file in $files) {
  $relative = $file.FullName.Substring($root.Length).TrimStart([char]'\', [char]'/') -replace '\\', '/'
  foreach ($forbiddenPlatform in $forbiddenPlatforms) {
    if ($relative -match ('(?i)' + [regex]::Escape($forbiddenPlatform))) { throw "Forbidden platform name in path: $relative" }
  }
  if ($relative -match '(?i)(^|/)(\.env(?:\.|$)|\.secrets(?:/|$))' -or $relative -match '(?i)\.local\.json$') {
    throw "Private runtime file included in package: $relative"
  }

  $extension = [IO.Path]::GetExtension($file.Name).ToLowerInvariant()
  if ((Get-TextExtensions) -notcontains $extension) { continue }
  $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
  foreach ($forbiddenPlatform in $forbiddenPlatforms) {
    if ($content -match ('(?i)' + [regex]::Escape($forbiddenPlatform))) { throw "Forbidden platform name in: $relative" }
  }
  $identityScanContent = $content
  if ($approvedRepositoryFiles -contains $relative) {
    if ($identityScanContent -match ('(?i)' + [regex]::Escape($approvedRepositoryUrl) + '(?:/|\.git)')) {
      throw "Only the approved repository homepage may appear in: $relative"
    }
    $identityScanContent = $identityScanContent.Replace($approvedRepositoryUrl, '')
  }
  foreach ($identity in $forbiddenIdentity) {
    if ($identityScanContent -match ('(?i)' + [regex]::Escape($identity))) { throw "Private identity in: $relative" }
  }
  $safetyRules = @(
    '(?i)[a-z]:\\ai\\',
    '(?i)[a-z]:\\users\\[^\\/]+(?:\\|/)',
    '(?i)authorization\s*:\s*bearer\s+[a-z0-9._~-]{12,}',
    '(?im)(api[_-]?key|access[_-]?token|secret|password)\s*[:=]\s*["'']?[a-z0-9_./+~-]{12,}',
    '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
  )
  foreach ($rule in $safetyRules) {
    if ($content -match $rule) { throw "Sensitive content pattern in: $relative" }
  }
}

$manifestPath = Join-Path $root 'package-manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or $manifest.product -ne 'CreatorFlow' -or $manifest.platform -ne 'TRAE Work' -or $manifest.repository -ne $approvedRepositoryUrl) {
  throw 'Unexpected package manifest identity'
}

foreach ($relative in @('README.md', 'docs/installation.md')) {
  $content = Get-Content -LiteralPath (Resolve-PackagePath -Root $root -RelativePath $relative) -Raw -Encoding UTF8
  if ($content -notmatch [regex]::Escape($approvedRepositoryUrl)) {
    throw "Approved repository URL is missing from: $relative"
  }
}

$actualFiles = @($files | ForEach-Object {
  $_.FullName.Substring($root.Length).TrimStart([char]'\', [char]'/') -replace '\\', '/'
} | Where-Object { $_ -ne 'package-manifest.json' } | Sort-Object)
$manifestFiles = @($manifest.files | ForEach-Object { [string]$_.path } | Sort-Object)
if (($actualFiles -join "`n") -ne ($manifestFiles -join "`n")) { throw 'Package files do not match package-manifest.json' }

foreach ($entry in @($manifest.files)) {
  $path = Resolve-PackagePath -Root $root -RelativePath ([string]$entry.path)
  $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualHash -ne ([string]$entry.sha256).ToLowerInvariant()) { throw "SHA256 mismatch: $($entry.path)" }
  if ((Get-Item -LiteralPath $path).Length -ne [long]$entry.bytes) { throw "Size mismatch: $($entry.path)" }
}

Write-Host "TRAE Work package validation: PASS ($($actualFiles.Count) files)"
