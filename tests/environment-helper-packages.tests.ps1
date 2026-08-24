Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$testName = 'test-environment-packs-' + [guid]::NewGuid().ToString('N')
$outputRoot = Join-Path $repoRoot ('.generated\' + $testName)
$extractRoot = Join-Path $outputRoot 'extracted'
$expected = @(
  'CreatorFlow-Core-Windows',
  'CreatorFlow-Material-AgentReach',
  'CreatorFlow-TTS-IndexTTS2',
  'CreatorFlow-Assembly-HyperFrames'
)
$forbiddenExtensions = @('.exe', '.dll', '.msi', '.sys', '.bin', '.pth', '.pt', '.ckpt', '.safetensors', '.onnx', '.gguf', '.7z', '.rar')

try {
  & (Join-Path $repoRoot 'scripts\export-environment-helper-packages.ps1') -OutputRoot $outputRoot -Force
  Assert-True ($?) 'Environment pack exporter failed'

  $manifestPath = Join-Path $outputRoot 'environment-packs-manifest.json'
  Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'Missing release manifest'
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($manifest.schemaVersion -eq 1) 'Unexpected environment pack manifest version'
  Assert-True (@($manifest.packages).Count -eq 4) 'Expected exactly four environment packs'

  New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
  foreach ($name in $expected) {
    $zipPath = Join-Path $outputRoot ($name + '.zip')
    Assert-True (Test-Path -LiteralPath $zipPath -PathType Leaf) "Missing package: $name"
    $entry = @($manifest.packages | Where-Object { $_.package -eq $name })
    Assert-True ($entry.Count -eq 1) "Missing manifest entry: $name"
    $actualHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-True ($actualHash -eq [string]$entry[0].sha256) "SHA256 mismatch: $name"

    $destination = Join-Path $extractRoot $name
    Expand-Archive -LiteralPath $zipPath -DestinationPath $destination
    $packageRoot = Join-Path $destination $name
    foreach ($required in @('README.md', 'start.ps1', 'creatorflow-pack-common.ps1', 'package-manifest.json')) {
      Assert-True (Test-Path -LiteralPath (Join-Path $packageRoot $required) -PathType Leaf) "$name is missing $required"
    }
    $packageManifest = Get-Content -LiteralPath (Join-Path $packageRoot 'package-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ($packageManifest.thirdPartyBinariesIncluded -eq $false) "$name must declare no bundled third-party binaries"

    foreach ($file in @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse)) {
      Assert-True ($forbiddenExtensions -notcontains $file.Extension.ToLowerInvariant()) "$name contains forbidden binary: $($file.Name)"
      $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
      Assert-True ($text -notmatch '(?i)[a-z]:\\ai\\') "$name contains a private AI drive path"
      Assert-True ($text -notmatch '(?i)[a-z]:\\users\\[^\\/]+') "$name contains an absolute user profile path"
      Assert-True ($text -notmatch '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----') "$name contains a private key"
    }
  }

  $coreReadme = Get-Content -LiteralPath (Join-Path $extractRoot 'CreatorFlow-Core-Windows\CreatorFlow-Core-Windows\README.md') -Raw -Encoding UTF8
  Assert-True ($coreReadme.Contains('Python') -and $coreReadme.Contains('FFmpeg')) 'Core pack must identify its system prerequisites'
  $ttsStart = Get-Content -LiteralPath (Join-Path $extractRoot 'CreatorFlow-TTS-IndexTTS2\CreatorFlow-TTS-IndexTTS2\start.ps1') -Raw -Encoding UTF8
  foreach ($cacheName in @('HF_HOME', 'HF_HUB_CACHE', 'UV_CACHE_DIR', 'PIP_CACHE_DIR', 'MODELSCOPE_CACHE')) {
    Assert-True ($ttsStart.Contains($cacheName)) "TTS pack must route cache: $cacheName"
  }
  Assert-True ($ttsStart -match "ValidateSet\('', 'indextts-source', 'indextts-runtime', 'indextts-model'\)") 'TTS pack must keep actions separate'

  Write-Host 'environment helper package tests passed'
}
finally {
  $generatedRoot = (Resolve-Path -LiteralPath (Join-Path $repoRoot '.generated')).Path
  $resolvedOutput = [IO.Path]::GetFullPath($outputRoot)
  Assert-True ($resolvedOutput.StartsWith($generatedRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Unsafe test cleanup target'
  if (Test-Path -LiteralPath $resolvedOutput) { Remove-Item -LiteralPath $resolvedOutput -Recurse -Force }
}
