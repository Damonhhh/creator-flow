param(
  [Parameter(Mandatory = $true)]
  [string]$VideoDir,

  [string]$Python = "",
  [string]$Repo = "",
  [string]$Runner = "",
  [string]$TtsConfig = "",
  [string]$FfprobePath = "",
  [int]$MaxTextTokensPerSegment = 120,
  [int]$MaxMelTokens = 1500,
  [int]$IntervalMs = 280,
  [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "lib\resolve-zimeiti-config.ps1")

function Get-PropertyValue {
  param([object]$Object, [string]$Name)
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Resolve-SettingValue {
  param([string]$ExplicitValue, [string]$EnvironmentName, [object]$ConfigValue)
  if (-not [string]::IsNullOrWhiteSpace($ExplicitValue)) { return $ExplicitValue }
  $environmentValue = [Environment]::GetEnvironmentVariable($EnvironmentName)
  if (-not [string]::IsNullOrWhiteSpace($environmentValue)) { return $environmentValue }
  return [string]$ConfigValue
}

function Get-AudioDurationSec {
  param([Parameter(Mandatory = $true)][string]$Path)

  $json = & $script:FfprobeCommand -v error -show_entries format=duration -of json $Path
  if ($LASTEXITCODE -ne 0) {
    throw "ffprobe failed for $Path"
  }
  $probe = $json | ConvertFrom-Json
  return [math]::Round([double]$probe.format.duration, 3)
}

$resolvedVideoDir = (Resolve-Path -LiteralPath $VideoDir).Path
$chapterManifestPath = Join-Path $resolvedVideoDir "draft\tts-chapters\chapter-manifest.json"
$outDir = Join-Path $resolvedVideoDir "audio\chapters"

$configPath = if ([string]::IsNullOrWhiteSpace($TtsConfig)) {
  Join-Path $repoRoot "config\tts.local.json"
} else {
  Resolve-ZimeitiConfigPath -RepoRoot $repoRoot -Value $TtsConfig
}
$config = Get-ZimeitiConfig -RepoRoot $repoRoot -Name "tts" -ConfigPath $configPath
$settings = Get-PropertyValue -Object $config -Name "productionTts"
if ($null -eq $settings) { $settings = $config }
$indexTts = Get-PropertyValue -Object $config -Name "indexTts"
if ($null -eq $indexTts) { $indexTts = Get-PropertyValue -Object $settings -Name "indexTts" }

$Repo = Resolve-SettingValue -ExplicitValue $Repo -EnvironmentName "INDEXTTS_REPO" -ConfigValue (Get-PropertyValue -Object $indexTts -Name "repo")
if ([string]::IsNullOrWhiteSpace($Repo)) {
  throw "IndexTTS chapters require -Repo, INDEXTTS_REPO, or config/tts.local.json indexTts.repo."
}
$Repo = Resolve-ZimeitiConfigPath -RepoRoot $repoRoot -Value $Repo

$Python = Resolve-SettingValue -ExplicitValue $Python -EnvironmentName "INDEXTTS_PYTHON" -ConfigValue (Get-PropertyValue -Object $indexTts -Name "python")
if ([string]::IsNullOrWhiteSpace($Python)) { $Python = Join-Path $Repo ".venv\Scripts\python.exe" }
$Python = Resolve-ZimeitiConfigPath -RepoRoot $repoRoot -Value $Python

if ([string]::IsNullOrWhiteSpace($Runner)) { $Runner = Join-Path $PSScriptRoot "run-indextts2-long.py" }
$Runner = Resolve-ZimeitiConfigPath -RepoRoot $repoRoot -Value $Runner

$FfprobePath = Resolve-SettingValue -ExplicitValue $FfprobePath -EnvironmentName "FFPROBE_PATH" -ConfigValue (Get-PropertyValue -Object $config -Name "ffprobePath")
if ([string]::IsNullOrWhiteSpace($FfprobePath)) {
  $ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
  if (-not $ffprobe) { throw "ffprobe is required. Install it on PATH, pass -FfprobePath, or set FFPROBE_PATH." }
  $script:FfprobeCommand = $ffprobe.Source
} else {
  $script:FfprobeCommand = Resolve-ZimeitiConfigPath -RepoRoot $repoRoot -Value $FfprobePath
}

foreach ($requiredPath in @($Python, $Repo, $Runner, $configPath, $script:FfprobeCommand, $chapterManifestPath)) {
  if (-not (Test-Path -LiteralPath $requiredPath)) {
    throw "Missing required path: $requiredPath"
  }
}

$referenceAudioConfig = Get-PropertyValue -Object $settings -Name "referenceAudio"
$referenceAudio = [string](Get-PropertyValue -Object $referenceAudioConfig -Name "path")
$referenceAudio = Resolve-SettingValue -ExplicitValue "" -EnvironmentName "ZIMEITI_TTS_REFERENCE_AUDIO" -ConfigValue $referenceAudio
if ([string]::IsNullOrWhiteSpace($referenceAudio)) {
  throw "IndexTTS chapters require ZIMEITI_TTS_REFERENCE_AUDIO or config/tts.local.json referenceAudio.path."
}
$referenceAudio = Resolve-ZimeitiConfigPath -RepoRoot $repoRoot -Value $referenceAudio
$expectedHash = [string](Get-PropertyValue -Object $referenceAudioConfig -Name "sha256")

if (-not (Test-Path -LiteralPath $referenceAudio -PathType Leaf)) {
  throw "Missing reference audio: $referenceAudio"
}

$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $referenceAudio).Hash
if (-not [string]::IsNullOrWhiteSpace($expectedHash) -and $actualHash -ne $expectedHash) {
  throw "Reference audio hash mismatch: $referenceAudio"
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$chapters = Get-Content -Raw -Encoding UTF8 -LiteralPath $chapterManifestPath | ConvertFrom-Json
$results = New-Object System.Collections.Generic.List[object]

foreach ($chapter in $chapters) {
  $chapterId = [string]$chapter.id
  $textFile = [string]$chapter.path
  $output = Join-Path $outDir "$chapterId.wav"

  if ((Test-Path -LiteralPath $output -PathType Leaf) -and -not $Force) {
    Write-Host "SKIP existing $chapterId -> $output"
  } else {
    Write-Host "START $chapterId -> $output"
    & $Python $Runner `
      --repo $Repo `
      --reference-audio $referenceAudio `
      --text-file $textFile `
      --output $output `
      --max-text-tokens-per-segment $MaxTextTokensPerSegment `
      --max-mel-tokens $MaxMelTokens `
      --interval-ms $IntervalMs

    if ($LASTEXITCODE -ne 0) {
      throw "IndexTTS-2 failed for $chapterId with exit code $LASTEXITCODE"
    }
  }

  if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
    throw "Missing chapter output after generation: $output"
  }

  $duration = Get-AudioDurationSec -Path $output
  $generationJson = Join-Path $outDir "$chapterId-generation.json"
  $results.Add([pscustomobject]@{
      chapter = [int]$chapter.chapter
      id = $chapterId
      title = [string]$chapter.title
      textFile = $textFile
      wav = $output
      generationJson = $generationJson
      durationSec = $duration
      nonWhitespaceChars = [int]$chapter.nonWhitespaceChars
    })
  Write-Host ("DONE {0}: {1}s" -f $chapterId, $duration)
}

$summary = [pscustomobject]@{
  schema = "zimeiti.indextts2-chapter-audio.v1"
  videoDir = $resolvedVideoDir
  referenceAudio = $referenceAudio
  referenceSha256 = $actualHash
  chapterManifest = $chapterManifestPath
  outputDir = $outDir
  generatedAt = (Get-Date).ToString("s")
  totalDurationSec = [math]::Round((($results | Measure-Object -Property durationSec -Sum).Sum), 3)
  chapters = $results
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$summaryPath = Join-Path $outDir "chapter-audio-manifest.json"
$summaryJson = $summary | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($summaryPath, $summaryJson + [Environment]::NewLine, $utf8NoBom)
Write-Host "Audio manifest: $summaryPath"
