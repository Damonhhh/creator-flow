param(
  [string]$OutputRoot = (Join-Path (Join-Path $PSScriptRoot '..') '.generated\environment-packs'),
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
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
  $path = (Get-NormalizedFullPath $PathValue).TrimEnd([char]'\', [char]'/')
  $root = (Get-NormalizedFullPath $RootValue).TrimEnd([char]'\', [char]'/')
  return $path.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Assert-PackageTextSafe {
  param([Parameter(Mandatory = $true)][string]$PathValue)

  $text = Get-Content -LiteralPath $PathValue -Raw -Encoding UTF8
  $rules = @(
    [ordered]@{ name = 'private ai drive path'; pattern = '(?i)[a-z]:\\ai\\' },
    [ordered]@{ name = 'absolute user profile path'; pattern = '(?i)[a-z]:\\users\\[^\\/]+' },
    [ordered]@{ name = 'bearer credential'; pattern = '(?i)authorization\s*:\s*bearer\s+[a-z0-9._~-]{12,}' },
    [ordered]@{ name = 'assigned credential'; pattern = '(?im)(api[_-]?key|access[_-]?token|secret|password)\s*[:=]\s*["'']?[a-z0-9_./+~-]{12,}' },
    [ordered]@{ name = 'private key'; pattern = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----' }
  )
  foreach ($rule in $rules) {
    if ($text -match $rule.pattern) { throw "Environment package safety scan rejected $($rule.name): $PathValue" }
  }
}

$repoRoot = Get-NormalizedFullPath (Join-Path $PSScriptRoot '..')
$generatedRoot = Get-NormalizedFullPath (Join-Path $repoRoot '.generated')
$output = Get-NormalizedFullPath $OutputRoot
if (-not (Test-PathInsideRoot -PathValue $output -RootValue $generatedRoot)) {
  throw "OutputRoot must stay inside the repository .generated directory: $output"
}

if (Test-Path -LiteralPath $output) {
  if (-not $Force) { throw "Output already exists. Rerun with -Force: $output" }
  Remove-Item -LiteralPath $output -Recurse -Force
}
New-Item -ItemType Directory -Path $output -Force | Out-Null
$staging = Join-Path $output '.staging'
New-Item -ItemType Directory -Path $staging -Force | Out-Null

$sourceRoot = Join-Path $repoRoot 'packaging\environment-packs'
$commonFile = Join-Path $sourceRoot 'common\creatorflow-pack-common.ps1'
$packs = @(
  [ordered]@{ name = 'CreatorFlow-Core-Windows'; source = 'core-windows'; kind = 'core' },
  [ordered]@{ name = 'CreatorFlow-Material-AgentReach'; source = 'material-agent-reach'; kind = 'material' },
  [ordered]@{ name = 'CreatorFlow-TTS-IndexTTS2'; source = 'tts-indextts2'; kind = 'tts' },
  [ordered]@{ name = 'CreatorFlow-Assembly-HyperFrames'; source = 'assembly-hyperframes'; kind = 'assembly' }
)
$forbiddenExtensions = @('.exe', '.dll', '.msi', '.sys', '.bin', '.pth', '.pt', '.ckpt', '.safetensors', '.onnx', '.gguf', '.zip', '.7z', '.rar')
$releaseEntries = @()

try {
  foreach ($pack in $packs) {
    $packSource = Join-Path $sourceRoot $pack.source
    if (-not (Test-Path -LiteralPath $packSource -PathType Container)) { throw "Missing environment pack source: $packSource" }
    $packRoot = Join-Path $staging $pack.name
    New-Item -ItemType Directory -Path $packRoot -Force | Out-Null

    Copy-Item -LiteralPath $commonFile -Destination (Join-Path $packRoot 'creatorflow-pack-common.ps1')
    Get-ChildItem -LiteralPath $packSource -File | ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $packRoot $_.Name)
    }

    $contentFiles = @(Get-ChildItem -LiteralPath $packRoot -File | Sort-Object Name)
    foreach ($file in $contentFiles) {
      if ($forbiddenExtensions -contains $file.Extension.ToLowerInvariant()) {
        throw "Third-party binary or nested archive is forbidden in environment packages: $($file.FullName)"
      }
      Assert-PackageTextSafe -PathValue $file.FullName
    }

    $packageManifest = [ordered]@{
      schemaVersion = 1
      package = $pack.name
      kind = $pack.kind
      generatedAtUtc = [DateTime]::UtcNow.ToString('o')
      thirdPartyBinariesIncluded = $false
      files = @($contentFiles | ForEach-Object {
        [ordered]@{
          path = $_.Name
          bytes = $_.Length
          sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
      })
    }
    $packageManifestPath = Join-Path $packRoot 'package-manifest.json'
    $packageManifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $packageManifestPath -Encoding UTF8
    Assert-PackageTextSafe -PathValue $packageManifestPath

    $zipPath = Join-Path $output ($pack.name + '.zip')
    Compress-Archive -LiteralPath $packRoot -DestinationPath $zipPath -CompressionLevel Optimal
    $releaseEntries += [ordered]@{
      package = $pack.name
      kind = $pack.kind
      file = [IO.Path]::GetFileName($zipPath)
      bytes = (Get-Item -LiteralPath $zipPath).Length
      sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
  }
}
finally {
  if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
}

$releaseManifest = [ordered]@{
  schemaVersion = 1
  product = 'CreatorFlow'
  platform = 'Windows'
  generatedAtUtc = [DateTime]::UtcNow.ToString('o')
  policy = 'Helper scripts only. No third-party binaries, models, credentials, cookies, voice samples, or private paths.'
  packages = $releaseEntries
}
$releaseManifestPath = Join-Path $output 'environment-packs-manifest.json'
$releaseManifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $releaseManifestPath -Encoding UTF8

Write-Host "Environment helper packages generated: $output"
foreach ($entry in $releaseEntries) {
  Write-Host "- $($entry.file)  $($entry.bytes) bytes  SHA256 $($entry.sha256)"
}
