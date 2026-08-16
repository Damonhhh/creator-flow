Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$scriptPath = Join-Path $repoRoot 'scripts\resolve-workflow-dependencies.ps1'

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

. $scriptPath

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("creatorflow-dependency-resolver-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
try {
  $coreOnlyResolver = {
    param($name)
    return $name -in @('powershell', 'python', 'ffmpeg', 'ffprobe', 'node', 'npm', 'npx')
  }

  $materialToolRoot = Join-Path $tempRoot 'material-tools'
  $material = Get-DependencyResolutionPlan -SelectedStage Material -SelectedToolRoot $materialToolRoot -CommandResolver $coreOnlyResolver
  Assert-True $material.ready 'Material must support a degraded route instead of blocking the whole workflow'
  Assert-True $material.degraded 'Missing Agent Reach must be visible as degraded'
  Assert-True (@($material.proposedActions | Where-Object { $_.id -eq 'agent-reach' }).Count -eq 1) 'Material must propose one Agent Reach action'
  Assert-True (-not (Test-Path -LiteralPath $materialToolRoot)) 'A plan-only check must not create the tool directory'
  $agentAction = @($material.proposedActions | Where-Object { $_.id -eq 'agent-reach' })[0]
  Assert-True $agentAction.consentRequired 'Agent Reach installation must require consent'
  Assert-True $agentAction.downloadsOrRunsThirdPartyCode 'The plan must disclose third-party code execution'
  Assert-True ($agentAction.scope -match 'current user') 'Agent Reach must be scoped outside the video workspace'

  $ttsConfigPath = Join-Path $tempRoot 'tts.local.json'
  [IO.File]::WriteAllText($ttsConfigPath, '{"mode":"clone-voice","referenceAudio":{"path":""},"indexTts":{"repo":"","python":"","cacheRoot":""}}', [Text.UTF8Encoding]::new($false))
  $ttsToolRoot = Join-Path $tempRoot 'tts-tools'
  $tts = Get-DependencyResolutionPlan -SelectedStage ScriptTTS -SelectedTtsConfigPath $ttsConfigPath -SelectedToolRoot $ttsToolRoot -CommandResolver $coreOnlyResolver
  Assert-True (-not $tts.ready) 'Selected clone voice must block until its selected route is ready'
  Assert-True (@($tts.proposedActions | Where-Object { $_.id -eq 'indextts-source' }).Count -eq 1) 'The first TTS action must fetch pinned source only'
  Assert-True (@($tts.proposedActions | Where-Object { $_.id -eq 'provide-reference-audio' }).Count -eq 1) 'Clone voice must request the private reference audio separately'
  $sourceAction = @($tts.proposedActions | Where-Object { $_.id -eq 'indextts-source' })[0]
  Assert-True (@($sourceAction.remainingAfterAction).Count -eq 3) 'The source action must disclose remaining runtime, model, and audio work'
  Assert-True (-not (Test-Path -LiteralPath $ttsToolRoot)) 'TTS planning must not download or create tool state'

  $existingAudioConfig = Join-Path $tempRoot 'existing-audio.json'
  [IO.File]::WriteAllText($existingAudioConfig, '{"mode":"existing-audio"}', [Text.UTF8Encoding]::new($false))
  $existingAudio = Get-DependencyResolutionPlan -SelectedStage ScriptTTS -SelectedTtsConfigPath $existingAudioConfig -SelectedToolRoot $ttsToolRoot -CommandResolver $coreOnlyResolver
  Assert-True $existingAudio.ready 'Existing audio must bypass local TTS installation'
  Assert-True (@($existingAudio.proposedActions).Count -eq 0) 'Existing audio must not propose IndexTTS downloads'

  $videoDir = Join-Path $tempRoot 'video-project'
  New-Item -ItemType Directory -Force -Path $videoDir | Out-Null
  $assembly = Get-DependencyResolutionPlan -SelectedStage Assembly -SelectedProjectDir $videoDir -SelectedToolRoot $tempRoot -CommandResolver $coreOnlyResolver
  Assert-True (-not $assembly.ready) 'Assembly must stop before a missing renderer is initialized'
  Assert-True (@($assembly.proposedActions | Where-Object { $_.id -eq 'hyperframes' }).Count -eq 1) 'Assembly must propose the existing HyperFrames initializer'
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $videoDir 'hyperframes-app'))) 'Assembly planning must not scaffold without consent'
}
finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force
}

Write-Host 'workflow dependency resolver tests passed'
