param(
  [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
  [string]$WorkspaceRoot = "",
  [string]$InputPath = "",
  [string]$RubricPath = "",
  [string]$OutputRoot = "",
  [switch]$Preflight,
  [switch]$Write,
  [switch]$CloneVoice,
  [string]$ReferenceAudio = "",
  [string]$TtsConfigPath = "",
  [string]$IndexTtsRepo = "",
  [string]$IndexTtsPython = "",
  [string]$FfprobePath = "",
  [string]$CacheRoot = "",
  [switch]$IndexTtsFp16,
  [switch]$AllowBatchCloneVoiceFallback
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve-python-command.ps1")
. (Join-Path $PSScriptRoot "lib\resolve-zimeiti-config.ps1")

function New-TextFromCodePoints {
  param([int[]]$CodePoints)

  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function Test-IndexTtsCudaAvailable {
  param([string]$IndexTtsPythonPath)

  $cudaCheck = & $IndexTtsPythonPath -c "import torch; print('1' if torch.cuda.is_available() else '0')"
  if ($LASTEXITCODE -ne 0) {
    return $false
  }

  return ((($cudaCheck | Out-String).Trim()) -eq "1")
}

function Get-JsonPropertyValue {
  param(
    [object]$Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }

  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) {
    return $null
  }

  return $property.Value
}

function Resolve-SettingValue {
  param(
    [string]$ExplicitValue,
    [string]$EnvironmentName,
    [object]$ConfigValue
  )
  if (-not [string]::IsNullOrWhiteSpace($ExplicitValue)) { return $ExplicitValue }
  $environmentValue = [Environment]::GetEnvironmentVariable($EnvironmentName)
  if (-not [string]::IsNullOrWhiteSpace($environmentValue)) { return $environmentValue }
  return [string]$ConfigValue
}

function Get-OptionalTtsConfig {
  param(
    [string]$WorkspaceRoot,
    [string]$ConfigPath
  )
  $candidate = if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    Join-Path $WorkspaceRoot "config\tts.local.json"
  } else {
    Resolve-ZimeitiConfigPath -RepoRoot $WorkspaceRoot -Value $ConfigPath
  }
  if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $null }
  return Get-ZimeitiConfig -RepoRoot $WorkspaceRoot -Name "tts" -ConfigPath $candidate
}

function Get-TtsSettings {
  param([object]$Config)
  if ($null -eq $Config) { return $null }
  $legacy = Get-JsonPropertyValue -Object $Config -Name "productionTts"
  if ($null -ne $legacy) { return $legacy }
  return $Config
}

function Resolve-ReferenceAudioSetting {
  param(
    [string]$WorkspaceRoot,
    [string]$ExplicitValue,
    [object]$TtsSettings
  )
  $referenceAudio = Get-JsonPropertyValue -Object $TtsSettings -Name "referenceAudio"
  $configuredPath = Get-JsonPropertyValue -Object $referenceAudio -Name "path"
  $referencePath = Resolve-SettingValue -ExplicitValue $ExplicitValue -EnvironmentName "ZIMEITI_TTS_REFERENCE_AUDIO" -ConfigValue $configuredPath
  if ([string]::IsNullOrWhiteSpace($referencePath)) {
    throw "CloneVoice requires -ReferenceAudio, ZIMEITI_TTS_REFERENCE_AUDIO, or config/tts.local.json referenceAudio.path."
  }
  $referencePath = Resolve-ZimeitiConfigPath -RepoRoot $WorkspaceRoot -Value $referencePath
  if (-not (Test-Path -LiteralPath $referencePath -PathType Leaf)) {
    throw "Configured TTS reference audio does not exist: $referencePath"
  }
  $expectedSha256 = [string](Get-JsonPropertyValue -Object $referenceAudio -Name "sha256")
  if (-not [string]::IsNullOrWhiteSpace($expectedSha256)) {
    $actualSha256 = (Get-FileHash -LiteralPath $referencePath -Algorithm SHA256).Hash
    if ($actualSha256.ToUpperInvariant() -ne $expectedSha256.ToUpperInvariant()) {
      throw "Configured TTS reference audio hash mismatch: $referencePath"
    }
  }
  return $referencePath
}

function Invoke-MainlineGenerator {
  param(
    [hashtable]$PythonInfo,
    [string]$PythonScriptPath,
    [string]$TargetDate,
    [string]$WorkspaceRoot,
    [string]$InputPath = "",
    [string]$RubricPath = "",
    [string]$OutputRoot = "",
    [switch]$Write,
    [switch]$Preflight
  )

  $generatorArgs = @($PythonInfo.PrefixArgs + @($PythonScriptPath, "--date", $TargetDate, "--workspace", $WorkspaceRoot))
  if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
    $generatorArgs += @("--input", $InputPath)
  }
  if (-not [string]::IsNullOrWhiteSpace($RubricPath)) {
    $generatorArgs += @("--rubric", $RubricPath)
  }
  if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
    $generatorArgs += @("--output-root", $OutputRoot)
  }
  if ($Write) {
    $generatorArgs += "--write"
  }
  if ($Preflight) {
    $generatorArgs += "--preflight"
  }

  $raw = & $PythonInfo.Command @generatorArgs
  if ($LASTEXITCODE -ne 0) {
    throw "generate_mainline_topic_decision.py failed with exit code $LASTEXITCODE"
  }

  return $raw | ConvertFrom-Json
}

function Test-CloneVoicePrerequisites {
  param(
    [string]$LongScript,
    [string]$VerifyScript,
    [string]$ReferenceAudioPath,
    [string]$NarrationTextPath,
    [string]$IndexTtsPythonPath
  )

  $problems = [System.Collections.Generic.List[string]]::new()

  if (-not (Test-Path -LiteralPath $LongScript)) {
    $problems.Add("Missing IndexTTS-2 long-read script: $LongScript")
  }
  if (-not (Test-Path -LiteralPath $VerifyScript)) {
    $problems.Add("Missing SRT verification script: $VerifyScript")
  }
  if (-not (Test-Path -LiteralPath $ReferenceAudioPath)) {
    $problems.Add("Reference audio does not exist: $ReferenceAudioPath")
  }
  if (-not (Test-Path -LiteralPath $NarrationTextPath)) {
    $problems.Add("Narration text does not exist: $NarrationTextPath")
  }
  if (-not (Test-Path -LiteralPath $IndexTtsPythonPath)) {
    $problems.Add("IndexTTS-2 Python does not exist: $IndexTtsPythonPath")
  } else {
    $importCheck = & $IndexTtsPythonPath -c "import torch; print(torch.__version__)"
    if ($LASTEXITCODE -ne 0) {
      $problems.Add("IndexTTS-2 Python cannot import torch: $IndexTtsPythonPath")
    }
  }

  if ($problems.Count -gt 0) {
    throw ("CloneVoice preflight failed:`n- " + ($problems -join "`n- "))
  }
}

function Convert-SrtToSegments {
  param(
    [string]$SrtPath,
    [string]$JsonPath,
    [string]$AudioPath,
    [string]$Source
  )

  $raw = Get-Content -LiteralPath $SrtPath -Raw -Encoding UTF8
  $raw = $raw -replace "`r`n", "`n"
  $raw = $raw -replace "`r", "`n"
  $blocks = $raw.Trim() -split "`n`n+"
  $segments = @()
  $index = 1

  foreach ($block in $blocks) {
    $lines = @($block -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($lines.Count -lt 2) {
      continue
    }
    $timeLineIndex = 0
    if ($lines[0] -notmatch "-->" -and $lines.Count -gt 1) {
      $timeLineIndex = 1
    }
    if ($lines[$timeLineIndex] -notmatch "^\s*(?<start>\d\d:\d\d:\d\d,\d\d\d)\s*-->\s*(?<end>\d\d:\d\d:\d\d,\d\d\d)") {
      continue
    }
    $textLines = @()
    for ($lineIndex = $timeLineIndex + 1; $lineIndex -lt $lines.Count; $lineIndex++) {
      $textLines += $lines[$lineIndex]
    }
    $text = ($textLines -join " ").Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
      continue
    }
    $segments += [pscustomobject]@{
      index = $index
      start = $Matches.start
      end = $Matches.end
      text = $text
    }
    $index += 1
  }

  $payload = [pscustomobject]@{
    source = $Source
    audio = $AudioPath
    srt = $SrtPath
    segment_count = $segments.Count
    segments = $segments
  }
  $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $JsonPath -Encoding UTF8
}

function Invoke-VideoCaptionerTranscribe {
  param(
    [string]$AudioPath,
    [string]$SrtPath
  )

  $cmd = Get-Command videocaptioner -ErrorAction SilentlyContinue
  $captionerCommand = $null
  if ($cmd) {
    $captionerCommand = $cmd.Source
  } else {
    $captionerCandidates = @(
      (Join-Path $script:workspaceRoot "音频转字幕\VideoCaptioner-1.4.1\.venv\Scripts\videocaptioner.exe"),
      (Join-Path $script:scriptRoot "..\音频转字幕\VideoCaptioner-1.4.1\.venv\Scripts\videocaptioner.exe")
    )
    foreach ($candidate in $captionerCandidates) {
      if (Test-Path -LiteralPath $candidate) {
        $captionerCommand = (Resolve-Path -LiteralPath $candidate).Path
        break
      }
    }
  }

  if (-not $captionerCommand) {
    throw "videocaptioner CLI was not found on PATH or at the project-local VideoCaptioner venv; cannot create real ASR SRT for long-read narration."
  }

  $asrBackends = @("jianying", "bijian", "faster-whisper")
  $lastFailure = $null
  foreach ($backend in $asrBackends) {
    & $captionerCommand transcribe $AudioPath --asr $backend --language zh --format srt -o $SrtPath -q
    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $SrtPath)) {
      return $backend
    }
    $lastFailure = "videocaptioner $backend failed with exit code $LASTEXITCODE"
  }

  throw "All videocaptioner ASR backends failed for long-read narration. Last failure: $lastFailure"
}

$script:scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
  $script:workspaceRoot = Split-Path -Parent $script:scriptRoot
} else {
  $script:workspaceRoot = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
}

$pythonScript = Join-Path $script:scriptRoot "generate_mainline_topic_decision.py"
$python = Resolve-PythonCommand
$portableMode = -not [string]::IsNullOrWhiteSpace($InputPath) -or -not [string]::IsNullOrWhiteSpace($RubricPath)
if ($portableMode) {
  if ([string]::IsNullOrWhiteSpace($InputPath) -or [string]::IsNullOrWhiteSpace($RubricPath)) {
    throw "Offline topic mode requires both -InputPath and -RubricPath."
  }
  if ($CloneVoice) {
    throw "Offline topic mode scores candidates only and cannot be combined with -CloneVoice."
  }
  $InputPath = Resolve-ZimeitiConfigPath -RepoRoot $script:workspaceRoot -Value $InputPath
  $RubricPath = Resolve-ZimeitiConfigPath -RepoRoot $script:workspaceRoot -Value $RubricPath
  if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $script:workspaceRoot "output\ai-mainline-topic"
  } else {
    $OutputRoot = Resolve-ZimeitiConfigPath -RepoRoot $script:workspaceRoot -Value $OutputRoot
  }
}

$preflightResult = Invoke-MainlineGenerator `
  -PythonInfo $python `
  -PythonScriptPath $pythonScript `
  -TargetDate $Date `
  -WorkspaceRoot $script:workspaceRoot `
  -InputPath $InputPath `
  -RubricPath $RubricPath `
  -OutputRoot $OutputRoot `
  -Preflight
if (-not $preflightResult.ok) {
  throw ("Mainline topic preflight failed before CloneVoice started: " + $preflightResult.reason)
}
if ($Preflight) {
  if ($portableMode) {
    [pscustomobject]@{
      Success        = [bool]$preflightResult.success
      Mode           = $preflightResult.mode
      CandidateCount = $preflightResult.candidateCount
      RubricName     = $preflightResult.rubricName
      Dimensions     = $preflightResult.dimensions
      InputPath      = $preflightResult.inputPath
      RubricPath     = $preflightResult.rubricPath
    }
  } else {
    [pscustomobject]@{
      Success      = [bool]$preflightResult.ok
      Mode         = "project"
      Date         = $Date
      BriefPath    = $preflightResult.brief_path
      TopicPreview = $preflightResult.topic_preview
      Reason       = $preflightResult.reason
    }
  }
  return
}

$data = Invoke-MainlineGenerator `
  -PythonInfo $python `
  -PythonScriptPath $pythonScript `
  -TargetDate $Date `
  -WorkspaceRoot $script:workspaceRoot `
  -InputPath $InputPath `
  -RubricPath $RubricPath `
  -OutputRoot $OutputRoot `
  -Write:$Write

if ($portableMode) {
  [pscustomobject]@{
    Success          = [bool]$data.success
    Mode             = $data.mode
    Date             = $data.date
    CandidateCount   = $data.candidateCount
    SelectedTopic    = $data.selectedTopic
    RankedCandidates = $data.rankedCandidates
    RankingPath      = $data.rankingPath
    DecisionPath     = $data.decisionPath
    Preflight        = $preflightResult
  }
  return
}

$cloneResult = $null
if ($CloneVoice) {
  if (-not $Write) {
    throw "CloneVoice requires -Write so the narration text file exists on disk."
  }

  $ttsConfig = Get-OptionalTtsConfig -WorkspaceRoot $script:workspaceRoot -ConfigPath $TtsConfigPath
  $ttsSettings = Get-TtsSettings -Config $ttsConfig
  $indexTtsSettings = Get-JsonPropertyValue -Object $ttsConfig -Name "indexTts"
  if ($null -eq $indexTtsSettings) {
    $indexTtsSettings = Get-JsonPropertyValue -Object $ttsSettings -Name "indexTts"
  }

  $ReferenceAudio = Resolve-ReferenceAudioSetting `
    -WorkspaceRoot $script:workspaceRoot `
    -ExplicitValue $ReferenceAudio `
    -TtsSettings $ttsSettings

  $IndexTtsRepo = Resolve-SettingValue `
    -ExplicitValue $IndexTtsRepo `
    -EnvironmentName "INDEXTTS_REPO" `
    -ConfigValue (Get-JsonPropertyValue -Object $indexTtsSettings -Name "repo")
  if ([string]::IsNullOrWhiteSpace($IndexTtsRepo)) {
    throw "CloneVoice requires -IndexTtsRepo, INDEXTTS_REPO, or config/tts.local.json indexTts.repo."
  }
  $IndexTtsRepo = Resolve-ZimeitiConfigPath -RepoRoot $script:workspaceRoot -Value $IndexTtsRepo

  $IndexTtsPython = Resolve-SettingValue `
    -ExplicitValue $IndexTtsPython `
    -EnvironmentName "INDEXTTS_PYTHON" `
    -ConfigValue (Get-JsonPropertyValue -Object $indexTtsSettings -Name "python")
  if ([string]::IsNullOrWhiteSpace($IndexTtsPython)) {
    $IndexTtsPython = Join-Path $IndexTtsRepo ".venv\Scripts\python.exe"
  }
  $IndexTtsPython = Resolve-ZimeitiConfigPath -RepoRoot $script:workspaceRoot -Value $IndexTtsPython

  $CacheRoot = Resolve-SettingValue `
    -ExplicitValue $CacheRoot `
    -EnvironmentName "ZIMEITI_CACHE_ROOT" `
    -ConfigValue (Get-JsonPropertyValue -Object $indexTtsSettings -Name "cacheRoot")
  if (-not [string]::IsNullOrWhiteSpace($CacheRoot)) {
    $CacheRoot = Resolve-ZimeitiConfigPath -RepoRoot $script:workspaceRoot -Value $CacheRoot
  }

  $FfprobePath = Resolve-SettingValue `
    -ExplicitValue $FfprobePath `
    -EnvironmentName "FFPROBE_PATH" `
    -ConfigValue (Get-JsonPropertyValue -Object $ttsConfig -Name "ffprobePath")
  if ([string]::IsNullOrWhiteSpace($FfprobePath)) {
    $ffprobeCommand = Get-Command ffprobe -ErrorAction SilentlyContinue
    if ($ffprobeCommand) { $FfprobePath = $ffprobeCommand.Source }
  } else {
    $FfprobePath = Resolve-ZimeitiConfigPath -RepoRoot $script:workspaceRoot -Value $FfprobePath
  }

  $longScript = Join-Path $scriptRoot "run-indextts2-long.py"
  $batchScript = Join-Path $scriptRoot "run-indextts2-batch.py"
  $verifyScript = Join-Path $scriptRoot "verify-srt-timeline.py"

  if (-not (Test-Path -LiteralPath $longScript)) {
    throw "Missing IndexTTS-2 long-read script: $longScript"
  }
  if (-not (Test-Path -LiteralPath $verifyScript)) {
    throw "Missing SRT verification script: $verifyScript"
  }
  if (-not (Test-Path -LiteralPath $ReferenceAudio)) {
    throw "Reference audio does not exist: $ReferenceAudio"
  }
  if (-not (Test-Path -LiteralPath ([string]$data.narration_text_path))) {
    throw "Narration text does not exist: $($data.narration_text_path)"
  }

  Test-CloneVoicePrerequisites `
    -LongScript $longScript `
    -VerifyScript $verifyScript `
    -ReferenceAudioPath $ReferenceAudio `
    -NarrationTextPath ([string]$data.narration_text_path) `
    -IndexTtsPythonPath $IndexTtsPython

  $audioDir = Join-Path ([string]$data.plan_directory) "audio\index-tts2-long"
  if (Test-Path -LiteralPath $audioDir) {
    Remove-Item -LiteralPath $audioDir -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $audioDir | Out-Null
  $audioName = "$Date-$($data.slug)-index-tts2"

  $longOutput = Join-Path $audioDir "$audioName.wav"
  $longArgs = @(
    $longScript,
    "--repo", $IndexTtsRepo,
    "--reference-audio", $ReferenceAudio,
    "--text-file", ([string]$data.narration_text_path),
    "--output", $longOutput,
    "--interval-ms", "220"
  )
  $useFp16 = $IndexTtsFp16.IsPresent
  if (-not $useFp16) {
    $useFp16 = Test-IndexTtsCudaAvailable -IndexTtsPythonPath $IndexTtsPython
  }
  if ($useFp16) {
    $longArgs += "--fp16"
  }

  $env:PYTHONIOENCODING = "utf-8"
  if (-not [string]::IsNullOrWhiteSpace($CacheRoot)) {
    $env:UV_CACHE_DIR = Join-Path $CacheRoot ".uv-cache"
    $env:UV_PYTHON_INSTALL_DIR = Join-Path $CacheRoot ".uv-python"
    $env:HF_HOME = Join-Path $CacheRoot ".hf-cache"
    $env:MODELSCOPE_CACHE = Join-Path $CacheRoot ".modelscope-cache"
  }
  $env:HF_HUB_DISABLE_SYMLINKS_WARNING = "1"
  $voiceRaw = & $IndexTtsPython @longArgs
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $longOutput)) {
    if (-not $AllowBatchCloneVoiceFallback) {
      throw "run-indextts2-long.py failed with exit code $LASTEXITCODE using IndexTTS Python: $IndexTtsPython. Batch fallback is disabled by default because short-sentence stitching is not acceptable final narration."
    }

    if (-not (Test-Path -LiteralPath $batchScript)) {
      throw "Long-read failed and batch fallback was allowed, but missing IndexTTS-2 batch script: $batchScript"
    }
    "Batch fallback used because long-read generation failed. This output is not final until human listen-check confirms no stitched cadence." |
      Set-Content -LiteralPath (Join-Path $audioDir "BATCH-FALLBACK-NOT-FINAL.txt") -Encoding UTF8

    $batchArgs = @(
      $batchScript,
      "--repo", $IndexTtsRepo,
      "--reference-audio", $ReferenceAudio,
      "--lines-file", ([string]$data.narration_text_path),
      "--out-dir", $audioDir,
      "--name", $audioName,
      "--max-chars-per-line", "0",
      "--max-text-tokens-per-segment", "90",
      "--interval-ms", "0",
      "--inner-interval-ms", "80",
      "--top-p", "0.82",
      "--temperature", "0.76",
      "--num-beams", "1"
    )
    if ($useFp16) {
      $batchArgs += "--fp16"
    }
    $voiceRaw = & $IndexTtsPython @batchArgs
    if ($LASTEXITCODE -ne 0) {
      throw "run-indextts2-batch.py fallback failed with exit code $LASTEXITCODE using IndexTTS Python: $IndexTtsPython"
    }

    $voiceText = ($voiceRaw -join "`n")
    $jsonStart = $voiceText.LastIndexOf("`n{")
    if ($jsonStart -ge 0) {
      $voiceJsonText = $voiceText.Substring($jsonStart + 1)
    } else {
      $jsonStart = $voiceText.IndexOf("{")
      if ($jsonStart -lt 0) {
        throw "run-indextts2-batch.py did not emit a JSON summary."
      }
      $voiceJsonText = $voiceText.Substring($jsonStart)
    }
    $voiceData = $voiceJsonText | ConvertFrom-Json
    $finalAudio = [string]$voiceData.final_wav
    $srtPath = [string]$voiceData.srt
    $segmentJsonPath = [string](Join-Path $audioDir "$audioName-segments.json")
    $generationJsonPath = $null
  } else {
    $finalAudio = $longOutput
    $generationJsonPath = Join-Path $audioDir "$audioName-generation.json"
    $srtPath = Join-Path $audioDir "$audioName-asr.srt"
    $asrBackend = Invoke-VideoCaptionerTranscribe -AudioPath $finalAudio -SrtPath $srtPath
    $segmentJsonPath = Join-Path $audioDir "$audioName-asr-segments.json"
    Convert-SrtToSegments -SrtPath $srtPath -JsonPath $segmentJsonPath -AudioPath $finalAudio -Source "videocaptioner-$asrBackend"
  }

  $proofPath = Join-Path $audioDir "$audioName-timeline-proof.md"
  $verifyArgs = @(
    $verifyScript,
    "--audio", $finalAudio,
    "--srt", $srtPath,
    "--report", $proofPath
  )
  if (Test-Path -LiteralPath $FfprobePath) {
    $verifyArgs += @("--ffprobe", $FfprobePath)
  }

  & $python.Command @($python.PrefixArgs + $verifyArgs) | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "verify-srt-timeline.py failed with exit code $LASTEXITCODE"
  }

  $cloneResult = [pscustomobject]@{
    ReferenceAudio = $ReferenceAudio
    Mode           = if (Test-Path -LiteralPath (Join-Path $audioDir "BATCH-FALLBACK-NOT-FINAL.txt")) { "batch-fallback-not-final" } else { "long-read" }
    AudioPath      = $finalAudio
    SrtPath        = $srtPath
    SegmentJson    = $segmentJsonPath
    GenerationJson = $generationJsonPath
    TimelineProof  = $proofPath
  }
}

[pscustomobject]@{
  Date             = $data.date
  DecisionPath     = $data.decision_path
  PlanDirectory    = $data.plan_directory
  PlanPath         = $data.plan_path
  AssetPath        = $data.asset_path
  VoicePath        = $data.voice_path
  NarrationTextPath = $data.narration_text_path
  VoiceClone        = $cloneResult
  Topic            = $data.topic
  RecommendedTitle = $data.recommended_title
  Slug             = $data.slug
}
