Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

$relativeFiles = @(
  "scripts\run-mainline-topic-decision.ps1",
  "scripts\run-indextts2-batch.py",
  "scripts\run-indextts2-long.py",
  "scripts\run-indextts2-chapters.ps1",
  "scripts\rebuild-hyperframes-captions-from-asr.py"
)

foreach ($relative in $relativeFiles) {
  $path = Join-Path $repoRoot $relative
  Assert-True (Test-Path -LiteralPath $path) "Missing portability target: $relative"
  $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  Assert-True ($text -notmatch '(?i)[A-Z]:\\ai\\models') "Private model path remains in $relative"
  Assert-True ($text -notmatch '(?i)[A-Z]:\\CodexCache') "Private cache path remains in $relative"
  Assert-True (-not $text.Contains("tts-defaults.json")) "Legacy TTS config filename remains in $relative"
}

$mainline = Get-Content -LiteralPath (Join-Path $repoRoot "scripts\run-mainline-topic-decision.ps1") -Raw -Encoding UTF8
Assert-True ($mainline.Contains('[string]$TtsConfigPath = ""')) "Mainline entry must accept TtsConfigPath"
Assert-True ($mainline.Contains('[string]$CacheRoot = ""')) "Mainline entry must accept CacheRoot"
Assert-True ($mainline.Contains("INDEXTTS_REPO")) "Mainline entry must support INDEXTTS_REPO"
Assert-True ($mainline.Contains("INDEXTTS_PYTHON")) "Mainline entry must support INDEXTTS_PYTHON"
Assert-True ($mainline.Contains("FFPROBE_PATH")) "Mainline entry must support FFPROBE_PATH"
Assert-True ($mainline.LastIndexOf("Get-OptionalTtsConfig") -gt $mainline.IndexOf('if ($CloneVoice)')) "TTS config must not load unless CloneVoice runs"

$chapters = Get-Content -LiteralPath (Join-Path $repoRoot "scripts\run-indextts2-chapters.ps1") -Raw -Encoding UTF8
Assert-True ($chapters.Contains("INDEXTTS_REPO")) "Chapter entry must support INDEXTTS_REPO"
Assert-True ($chapters.Contains("config\tts.local.json")) "Chapter entry must use local TTS config"

$asr = Get-Content -LiteralPath (Join-Path $repoRoot "scripts\rebuild-hyperframes-captions-from-asr.py") -Raw -Encoding UTF8
Assert-True ($asr.Contains('"HF_HOME"')) "ASR must support HF_HOME"

Write-Host "TTS portability tests passed"
