param(
  [string]$ManifestPath = (Join-Path (Join-Path $PSScriptRoot "..") "public-export-manifest.json"),
  [string]$Destination = (Join-Path (Split-Path (Join-Path $PSScriptRoot "..") -Parent) "zimeiti-video-workflow"),
  [switch]$Force,
  [switch]$ScanOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Get-NormalizedFullPath {
  param([Parameter(Mandatory = $true)][string]$PathValue)
  return [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($PathValue.Trim()))
}

function Test-PathInsideRoot {
  param(
    [Parameter(Mandatory = $true)][string]$PathValue,
    [Parameter(Mandatory = $true)][string]$RootValue
  )
  $path = (Get-NormalizedFullPath $PathValue).TrimEnd('\')
  $root = (Get-NormalizedFullPath $RootValue).TrimEnd('\')
  return $path.StartsWith($root + "\", [StringComparison]::OrdinalIgnoreCase)
}

function Resolve-SafeDestination {
  param(
    [Parameter(Mandatory = $true)][string]$PathValue,
    [Parameter(Mandatory = $true)][string]$SourceRoot
  )
  $resolved = (Get-NormalizedFullPath $PathValue).TrimEnd('\')
  $driveRoot = ([IO.Path]::GetPathRoot($resolved)).TrimEnd('\')
  $source = (Get-NormalizedFullPath $SourceRoot).TrimEnd('\')
  $userProfile = (Get-NormalizedFullPath ([Environment]::GetFolderPath("UserProfile"))).TrimEnd('\')
  $broadRoots = @($driveRoot, $source, $userProfile)
  if ((Split-Path -Leaf $source) -eq "zimeiti") {
    $broadRoots += (Split-Path -Parent $source)
  }
  foreach ($blocked in $broadRoots) {
    if (-not [string]::IsNullOrWhiteSpace($blocked) -and
        $resolved.Equals($blocked.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
      throw "Unsafe public export destination: $resolved"
    }
  }
  return $resolved
}

function Read-PublicExportManifest {
  param([Parameter(Mandatory = $true)][string]$PathValue)
  if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
    throw "Public export manifest does not exist: $PathValue"
  }
  $manifest = Get-Content -LiteralPath $PathValue -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($manifest.schemaVersion -ne 1) { throw "Unsupported public export schemaVersion: $($manifest.schemaVersion)" }
  if ($manifest.repository -ne "zimeiti-video-workflow") { throw "Unexpected public repository name" }
  if ($manifest.license -ne "MIT") { throw "Unexpected public license" }
  if (@($manifest.files).Count -eq 0) { throw "Public export manifest has no files" }
  return $manifest
}

function Resolve-ManifestRelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$Label
  )
  if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)' -or $RelativePath -match '\*\*') {
    throw "Unsafe $Label path in public export manifest: $RelativePath"
  }
  $resolved = Get-NormalizedFullPath (Join-Path $Root ($RelativePath -replace '/', '\'))
  if (-not (Test-PathInsideRoot -PathValue $resolved -RootValue $Root)) {
    throw "$Label path escapes its root: $RelativePath"
  }
  return $resolved
}

function Test-ExportEntry {
  param(
    [Parameter(Mandatory = $true)][string]$SourceRoot,
    [Parameter(Mandatory = $true)][object]$Entry,
    [Parameter(Mandatory = $true)][hashtable]$Destinations
  )
  $sourceValue = [string]$Entry.source
  $destinationValue = [string]$Entry.destination
  if ([string]::IsNullOrWhiteSpace($sourceValue) -or [string]::IsNullOrWhiteSpace($destinationValue)) {
    throw "Every public export entry requires source and destination"
  }
  $sourcePath = Resolve-ManifestRelativePath -Root $SourceRoot -RelativePath $sourceValue -Label "source"
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Missing public export source: $sourceValue"
  }
  $destinationKey = ($destinationValue -replace '\\', '/').ToLowerInvariant()
  if ($Destinations.ContainsKey($destinationKey)) {
    throw "Duplicate public export destination: $destinationValue"
  }
  $Destinations[$destinationKey] = $true
  return [ordered]@{ Source = $sourcePath; Destination = $destinationValue }
}

function Test-PublicTextSafety {
  param([Parameter(Mandatory = $true)][string]$PathValue)
  $textExtensions = @("", ".md", ".txt", ".json", ".jsonl", ".ps1", ".psm1", ".py", ".mjs", ".js", ".ts", ".tsx", ".css", ".html", ".yml", ".yaml", ".toml", ".gitignore")
  $extension = [IO.Path]::GetExtension($PathValue).ToLowerInvariant()
  if ($textExtensions -notcontains $extension -and (Split-Path -Leaf $PathValue) -ne ".gitignore") { return }

  $text = Get-Content -LiteralPath $PathValue -Raw -Encoding UTF8
  $rules = @(
    [ordered]@{ Name = "private ai drive path"; Pattern = '(?i)[a-z]:\\ai\\' },
    [ordered]@{ Name = "absolute user profile path"; Pattern = '(?i)[a-z]:\\users\\[^\\/]+(?:\\|/)' },
    [ordered]@{ Name = "bearer credential"; Pattern = '(?i)authorization\s*:\s*bearer\s+[a-z0-9._~-]{12,}' },
    [ordered]@{ Name = "assigned credential"; Pattern = '(?im)(api[_-]?key|access[_-]?token|secret|password)\s*[:=]\s*["'']?[a-z0-9_./+~-]{12,}' },
    [ordered]@{ Name = "private key"; Pattern = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----' }
  )
  foreach ($rule in $rules) {
    if ($text -match $rule.Pattern) {
      throw "Public safety scan rejected $($rule.Name) in $PathValue"
    }
  }
}

$resolvedManifest = Get-NormalizedFullPath $ManifestPath
$sourceRoot = Split-Path -Parent $resolvedManifest
$manifest = Read-PublicExportManifest -PathValue $resolvedManifest

if ($ScanOnly) {
  $sourceScanPaths = @()
  $sourceSetComplete = $true
  foreach ($entry in @($manifest.files)) {
    try {
      $path = Resolve-ManifestRelativePath -Root $sourceRoot -RelativePath ([string]$entry.source) -Label "source"
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $sourceSetComplete = $false
        break
      }
      $sourceScanPaths += $path
    }
    catch {
      $sourceSetComplete = $false
      break
    }
  }

  $scanPaths = if ($sourceSetComplete) {
    $sourceScanPaths
  }
  else {
    $packagePaths = @()
    foreach ($entry in @($manifest.files)) {
      $path = Resolve-ManifestRelativePath -Root $sourceRoot -RelativePath ([string]$entry.destination) -Label "destination"
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing public package file: $($entry.destination)"
      }
      $packagePaths += $path
    }
    $packagePaths
  }

  foreach ($path in $scanPaths) {
    Test-PublicTextSafety -PathValue $path
  }
  $scanMode = if ($sourceSetComplete) { "source" } else { "package" }
  Write-Host "Public export safety scan passed ($($scanPaths.Count) files, $scanMode mode)"
  exit 0
}

$destinations = @{}
$validatedEntries = @()
foreach ($entry in @($manifest.files)) {
  $validatedEntries += Test-ExportEntry -SourceRoot $sourceRoot -Entry $entry -Destinations $destinations
}
foreach ($entry in $validatedEntries) {
  Test-PublicTextSafety -PathValue $entry.Source
}

$resolvedDestination = Resolve-SafeDestination -PathValue $Destination -SourceRoot $sourceRoot
if (Test-Path -LiteralPath $resolvedDestination) {
  $existing = @(Get-ChildItem -LiteralPath $resolvedDestination -Force -ErrorAction Stop)
  if ($existing.Count -gt 0 -and -not $Force) {
    throw "Destination is not empty; rerun with -Force to overwrite manifest files only: $resolvedDestination"
  }
}

$stagingBase = Join-Path $sourceRoot ".generated\public-export"
$stagingRoot = Join-Path $stagingBase ((Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss") + "-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null
try {
  foreach ($entry in $validatedEntries) {
    $stagedPath = Resolve-ManifestRelativePath -Root $stagingRoot -RelativePath $entry.Destination -Label "destination"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $stagedPath) | Out-Null
    Copy-Item -LiteralPath $entry.Source -Destination $stagedPath -Force
    Test-PublicTextSafety -PathValue $stagedPath
  }

  # Publish immutable source hashes with the package so a cloned repository can
  # verify itself without access to the source workspace. The manifest
  # entry is intentionally unhashed because a file cannot contain its own hash.
  $publishedFiles = @()
  for ($index = 0; $index -lt $validatedEntries.Count; $index++) {
    $manifestEntry = @($manifest.files)[$index]
    $validatedEntry = $validatedEntries[$index]
    $publishedEntry = [ordered]@{
      source = [string]$manifestEntry.source
      destination = [string]$manifestEntry.destination
    }
    if ([string]$manifestEntry.destination -ne 'public-export-manifest.json') {
      $stagedFile = Resolve-ManifestRelativePath -Root $stagingRoot -RelativePath $validatedEntry.Destination -Label "destination"
      $publishedEntry.sha256 = (Get-FileHash -LiteralPath $stagedFile -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $publishedFiles += $publishedEntry
  }
  $publishedManifest = [ordered]@{
    schemaVersion = $manifest.schemaVersion
    repository = $manifest.repository
    license = $manifest.license
    files = $publishedFiles
  }
  $stagedManifest = Resolve-ManifestRelativePath -Root $stagingRoot -RelativePath 'public-export-manifest.json' -Label 'destination'
  [IO.File]::WriteAllText(
    $stagedManifest,
    (($publishedManifest | ConvertTo-Json -Depth 8) + "`n"),
    [Text.UTF8Encoding]::new($false)
  )
  Test-PublicTextSafety -PathValue $stagedManifest

  New-Item -ItemType Directory -Force -Path $resolvedDestination | Out-Null
  foreach ($entry in $validatedEntries) {
    $stagedPath = Resolve-ManifestRelativePath -Root $stagingRoot -RelativePath $entry.Destination -Label "destination"
    $targetPath = Resolve-ManifestRelativePath -Root $resolvedDestination -RelativePath $entry.Destination -Label "destination"
    if (Test-Path -LiteralPath $targetPath -PathType Container) {
      throw "Manifest target is an existing directory: $targetPath"
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
    Copy-Item -LiteralPath $stagedPath -Destination $targetPath -Force
  }
}
finally {
  if (Test-Path -LiteralPath $stagingRoot) {
    $resolvedStaging = (Resolve-Path -LiteralPath $stagingRoot).Path
    if (-not (Test-PathInsideRoot -PathValue $resolvedStaging -RootValue $stagingBase)) {
      throw "Refusing to clean unsafe staging directory: $resolvedStaging"
    }
    Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
  }
}

Write-Host "Public export completed: $resolvedDestination ($($validatedEntries.Count) files)"
