Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$scriptPath = Join-Path $repoRoot 'scripts\test-workflow-capabilities.ps1'

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

. $scriptPath

$savedIndexTtsRepo = $env:INDEXTTS_REPO
$env:INDEXTTS_REPO = $null
try {
  $coreResolver = {
    param($name)
    return $name -in @('powershell', 'py', 'ffmpeg', 'ffprobe')
  }
  $core = Get-WorkflowCapabilities -SelectedProfile Core -CommandResolver $coreResolver
  Assert-True $core.ready 'Core should pass with py as the Python launcher'
  Assert-True ($core.capabilities['python']['invocation'] -eq 'py') 'Capability output must name the detected Python launcher'
  Assert-True (-not $core.capabilities['node']['required']) 'Node must be optional for Core'
  Assert-True (-not $core.capabilities['hyperframes']['available']) 'Missing optional renderer capability must be reported'
  Assert-True $core.askBeforeInstall 'Capability output must require consent before installation'

  $full = Get-WorkflowCapabilities -SelectedProfile Full -CommandResolver $coreResolver
  Assert-True (-not $full.ready) 'Full must fail when renderer commands are missing'
  Assert-True $full.capabilities['node']['required'] 'Node must be required for the HyperFrames route'
  Assert-True $full.capabilities['npx']['required'] 'npx must be required for the HyperFrames route'
  Assert-True $full.capabilities['hyperframes']['required'] 'HyperFrames must be required for the selected route'
  Assert-True (@($full.missingRequired) -contains 'npx') 'Missing requirements must be enumerated'

  $allResolver = { param($name) return $true }
  $fullNoTts = Get-WorkflowCapabilities -SelectedProfile Full -CommandResolver $allResolver
  Assert-True $fullNoTts.ready 'Full with renderer commands and no selected TTS should be ready'
  Assert-True (-not $fullNoTts.capabilities['indextts']['required']) 'IndexTTS must remain optional without that route'
  Assert-True ($fullNoTts.capabilities['hyperframes']['invocation'] -match '^npx ') 'HyperFrames must use the project-local npx route'
  Assert-True $fullNoTts.capabilities['hyperframes']['consentRequired'] 'First-use package download must require consent'

  $existingAudio = [pscustomobject]@{ mode = 'existing-audio' }
  $fullExistingAudio = Get-WorkflowCapabilities -SelectedProfile Full -TtsConfig $existingAudio -CommandResolver $allResolver
  Assert-True $fullExistingAudio.ready 'Existing audio must not require IndexTTS'

  $ttsConfig = [pscustomobject]@{ mode = 'clone-voice' }
  $fullTts = Get-WorkflowCapabilities -SelectedProfile Full -TtsConfig $ttsConfig -CommandResolver $allResolver
  Assert-True $fullTts.capabilities['indextts']['required'] 'Selected clone voice must require IndexTTS'
  Assert-True (-not $fullTts.ready) 'Selected IndexTTS route must fail when its repository is unavailable'

  $partialRoot = Join-Path ([IO.Path]::GetTempPath()) ("creatorflow-indextts-capability-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $partialRoot | Out-Null
  try {
    $partialConfig = [pscustomobject]@{
      mode = 'clone-voice'
      indexTts = [pscustomobject]@{ repo = $partialRoot; python = ''; cacheRoot = '' }
      referenceAudio = [pscustomobject]@{ path = ''; sha256 = '' }
    }
    $partial = Get-WorkflowCapabilities -SelectedProfile Full -TtsConfig $partialConfig -CommandResolver $allResolver
    Assert-True (-not $partial.capabilities['indextts']['available']) 'A source directory alone must not claim IndexTTS readiness'
    Assert-True $partial.capabilities['indextts']['details']['sourceAvailable'] 'IndexTTS diagnostics must distinguish source availability'
    Assert-True (-not $partial.capabilities['indextts']['details']['runtimeAvailable']) 'IndexTTS diagnostics must report a missing runtime'
    Assert-True (-not $partial.capabilities['indextts']['details']['modelAvailable']) 'IndexTTS diagnostics must report missing checkpoints'
    Assert-True (-not $partial.capabilities['indextts']['details']['referenceAudioAvailable']) 'Clone voice must report a missing private reference audio file'
  }
  finally {
    Remove-Item -LiteralPath $partialRoot -Recurse -Force
  }

  $customWorkflow = [pscustomobject]@{
    renderer = [pscustomobject]@{ engine = 'custom'; command = 'my-renderer build' }
  }
  $customResolver = { param($name) return $name -in @('powershell', 'python', 'ffmpeg', 'ffprobe', 'my-renderer') }
  $custom = Get-WorkflowCapabilities -SelectedProfile Full -WorkflowConfig $customWorkflow -CommandResolver $customResolver
  Assert-True $custom.ready 'A configured available custom renderer must satisfy Full'
  Assert-True (-not $custom.capabilities['hyperframes']['required']) 'Custom renderer routes must not require HyperFrames'

  $json = $core | ConvertTo-Json -Depth 8 | ConvertFrom-Json
  foreach ($name in @('powershell', 'python', 'ffmpeg', 'ffprobe', 'node', 'npm', 'npx', 'hyperframes', 'customRenderer', 'indextts')) {
    Assert-True ($null -ne $json.capabilities.PSObject.Properties[$name]) "Missing capability field: $name"
  }
}
finally {
  $env:INDEXTTS_REPO = $savedIndexTtsRepo
}

Write-Host 'workflow capability tests passed'
