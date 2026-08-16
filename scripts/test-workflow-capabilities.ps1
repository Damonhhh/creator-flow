param(
  [ValidateSet('Core', 'Full')]
  [string]$Profile = 'Core',

  [string]$WorkflowConfigPath = '',

  [string]$TtsConfigPath = '',

  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$script:RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Test-CommandAvailable {
  param([string]$Name)
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Read-OptionalJson {
  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return $null }
  $expanded = [Environment]::ExpandEnvironmentVariables($PathValue)
  $resolved = if ([IO.Path]::IsPathRooted($expanded)) {
    [IO.Path]::GetFullPath($expanded)
  }
  else {
    [IO.Path]::GetFullPath((Join-Path $script:RepoRoot $expanded))
  }
  if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
    throw "Configuration file not found: $PathValue"
  }
  return Get-Content -LiteralPath $resolved -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-PropertyValue {
  param([object]$Object, [string]$Name, [object]$Default = $null)
  if ($null -eq $Object) { return $Default }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $Default }
  return $property.Value
}

function Test-IndexTtsSelected {
  param([object]$TtsConfig)
  $mode = [string](Get-PropertyValue -Object $TtsConfig -Name 'mode' -Default '')
  return $mode -match '^(indextts|indextts2|clone-voice)$'
}

function Resolve-ConfiguredPath {
  param([string]$PathValue, [string]$BasePath = $script:RepoRoot)
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return '' }
  $candidate = [Environment]::ExpandEnvironmentVariables($PathValue)
  if (-not [IO.Path]::IsPathRooted($candidate)) { $candidate = Join-Path $BasePath $candidate }
  return [IO.Path]::GetFullPath($candidate)
}

function Get-IndexTtsReadiness {
  param([object]$TtsConfig = $null)

  $indexTts = Get-PropertyValue -Object $TtsConfig -Name 'indexTts'
  $configuredRepo = [string](Get-PropertyValue -Object $indexTts -Name 'repo' -Default '')
  $repo = if (-not [string]::IsNullOrWhiteSpace($env:INDEXTTS_REPO)) {
    Resolve-ConfiguredPath -PathValue $env:INDEXTTS_REPO
  }
  else {
    Resolve-ConfiguredPath -PathValue $configuredRepo
  }

  $sourceAvailable = -not [string]::IsNullOrWhiteSpace($repo) -and (Test-Path -LiteralPath $repo -PathType Container)
  $configuredPython = [string](Get-PropertyValue -Object $indexTts -Name 'python' -Default '')
  $python = Resolve-ConfiguredPath -PathValue $configuredPython
  if ([string]::IsNullOrWhiteSpace($python) -and $sourceAvailable) {
    $defaultPython = Join-Path $repo '.venv\Scripts\python.exe'
    if (Test-Path -LiteralPath $defaultPython -PathType Leaf) { $python = $defaultPython }
  }
  $runtimeAvailable = -not [string]::IsNullOrWhiteSpace($python) -and (Test-Path -LiteralPath $python -PathType Leaf)
  $modelConfig = if ($sourceAvailable) { Join-Path $repo 'checkpoints\config.yaml' } else { '' }
  $modelAvailable = -not [string]::IsNullOrWhiteSpace($modelConfig) -and (Test-Path -LiteralPath $modelConfig -PathType Leaf)
  $referenceAudio = [string](Get-PropertyValue -Object (Get-PropertyValue -Object $TtsConfig -Name 'referenceAudio') -Name 'path' -Default '')
  $referenceAudioPath = Resolve-ConfiguredPath -PathValue $referenceAudio
  $referenceAudioAvailable = -not [string]::IsNullOrWhiteSpace($referenceAudioPath) -and (Test-Path -LiteralPath $referenceAudioPath -PathType Leaf)

  return [ordered]@{
    ready = $sourceAvailable -and $runtimeAvailable -and $modelAvailable -and $referenceAudioAvailable
    repo = $repo
    python = $python
    modelConfig = $modelConfig
    referenceAudio = $referenceAudioPath
    sourceAvailable = $sourceAvailable
    runtimeAvailable = $runtimeAvailable
    modelAvailable = $modelAvailable
    referenceAudioAvailable = $referenceAudioAvailable
  }
}

function New-CapabilityRecord {
  param(
    [bool]$Available,
    [bool]$Required,
    [string]$Purpose,
    [string]$InstallUrl,
    [string]$Invocation = '',
    [switch]$DownloadMayBeRequired
  )
  return [ordered]@{
    available = $Available
    required = $Required
    purpose = $Purpose
    installUrl = $InstallUrl
    invocation = $Invocation
    downloadMayBeRequired = [bool]$DownloadMayBeRequired
    consentRequired = (-not $Available -or [bool]$DownloadMayBeRequired)
  }
}

function Get-WorkflowCapabilities {
  param(
    [ValidateSet('Core', 'Full')][string]$SelectedProfile = 'Core',
    [object]$WorkflowConfig = $null,
    [object]$TtsConfig = $null,
    [scriptblock]$CommandResolver = ${function:Test-CommandAvailable}
  )

  $isFull = $SelectedProfile -eq 'Full'
  $renderer = Get-PropertyValue -Object $WorkflowConfig -Name 'renderer'
  $rendererEngine = [string](Get-PropertyValue -Object $renderer -Name 'engine' -Default 'hyperframes')
  if ([string]::IsNullOrWhiteSpace($rendererEngine)) { $rendererEngine = 'hyperframes' }
  $rendererCommand = [string](Get-PropertyValue -Object $renderer -Name 'command' -Default '')
  $usesHyperFrames = $rendererEngine -eq 'hyperframes'

  $pythonCommand = ''
  if (& $CommandResolver 'python') { $pythonCommand = 'python' }
  elseif (& $CommandResolver 'py') { $pythonCommand = 'py' }

  $nodeAvailable = [bool](& $CommandResolver 'node')
  $npmAvailable = [bool](& $CommandResolver 'npm')
  $npxAvailable = [bool](& $CommandResolver 'npx')
  $customRendererAvailable = $false
  if (-not $usesHyperFrames -and -not [string]::IsNullOrWhiteSpace($rendererCommand)) {
    $commandName = ($rendererCommand -split '\s+')[0]
    $customRendererAvailable = [bool](& $CommandResolver $commandName)
  }

  $indexTtsRequired = $isFull -and (Test-IndexTtsSelected -TtsConfig $TtsConfig)
  $indexTtsReadiness = Get-IndexTtsReadiness -TtsConfig $TtsConfig
  $indexTtsAvailable = [bool]$indexTtsReadiness.ready

  $powershellCap = (New-CapabilityRecord -Available ([bool](& $CommandResolver 'powershell')) -Required $true -Purpose 'Run workflow entry points and quality gates.' -InstallUrl 'https://learn.microsoft.com/powershell/' -Invocation 'powershell');
  $pythonCap = (New-CapabilityRecord -Available (-not [string]::IsNullOrWhiteSpace($pythonCommand)) -Required $true -Purpose 'Run topic, subtitle, and helper scripts.' -InstallUrl 'https://www.python.org/downloads/' -Invocation $pythonCommand);
  $ffmpegCap = (New-CapabilityRecord -Available ([bool](& $CommandResolver 'ffmpeg')) -Required $true -Purpose 'Process, sample, and encode media.' -InstallUrl 'https://ffmpeg.org/download.html' -Invocation 'ffmpeg');
  $ffprobeCap = (New-CapabilityRecord -Available ([bool](& $CommandResolver 'ffprobe')) -Required $true -Purpose 'Inspect media duration, streams, and codecs.' -InstallUrl 'https://ffmpeg.org/download.html' -Invocation 'ffprobe');
  $nodeCap = (New-CapabilityRecord -Available $nodeAvailable -Required ($isFull -and $usesHyperFrames) -Purpose 'Run the HyperFrames assembly project.' -InstallUrl 'https://nodejs.org/en/download' -Invocation 'node');
  $npmCap = (New-CapabilityRecord -Available $npmAvailable -Required ($isFull -and $usesHyperFrames) -Purpose 'Install and check renderer project dependencies.' -InstallUrl 'https://nodejs.org/en/download' -Invocation 'npm');
  $npxCap = (New-CapabilityRecord -Available $npxAvailable -Required ($isFull -and $usesHyperFrames) -Purpose 'Invoke the project-scoped HyperFrames CLI.' -InstallUrl 'https://nodejs.org/en/download' -Invocation 'npx');
  $hyperFramesCap = (New-CapabilityRecord -Available ($nodeAvailable -and $npmAvailable -and $npxAvailable) -Required ($isFull -and $usesHyperFrames) -Purpose 'Reference Assembly renderer; first setup may download an npm package.' -InstallUrl 'https://www.npmjs.com/package/hyperframes' -Invocation 'npx --yes hyperframes@0.7.55' -DownloadMayBeRequired:$usesHyperFrames);
  $customRendererCap = (New-CapabilityRecord -Available $customRendererAvailable -Required ($isFull -and -not $usesHyperFrames) -Purpose 'Run the alternate renderer selected in workflow.local.json.' -InstallUrl '' -Invocation $rendererCommand);
  $indexTtsCap = (New-CapabilityRecord -Available $indexTtsAvailable -Required $indexTtsRequired -Purpose 'Generate narration only when the IndexTTS or clone-voice route is selected.' -InstallUrl 'https://github.com/index-tts/index-tts' -Invocation '' -DownloadMayBeRequired:$indexTtsRequired);
  $indexTtsCap['details'] = $indexTtsReadiness

  $capabilities = [ordered]@{
    powershell = $powershellCap
    python = $pythonCap
    ffmpeg = $ffmpegCap
    ffprobe = $ffprobeCap
    node = $nodeCap
    npm = $npmCap
    npx = $npxCap
    hyperframes = $hyperFramesCap
    customRenderer = $customRendererCap
    indextts = $indexTtsCap
  }

  $missing = @()
  foreach ($entry in $capabilities.GetEnumerator()) {
    if ($entry.Value.required -and -not $entry.Value.available) { $missing += $entry.Key }
  }

  return [ordered]@{
    profile = $SelectedProfile
    renderer = $rendererEngine
    ready = $missing.Count -eq 0
    missingRequired = $missing
    askBeforeInstall = $true
    capabilities = $capabilities
    installation = 'docs/installation.md'
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  $workflowConfig = Read-OptionalJson -PathValue $WorkflowConfigPath
  $ttsConfig = Read-OptionalJson -PathValue $TtsConfigPath
  $result = Get-WorkflowCapabilities -SelectedProfile $Profile -WorkflowConfig $workflowConfig -TtsConfig $ttsConfig
  if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
  }
  else {
    Write-Host "Workflow profile: $($result.profile)"
    Write-Host "Renderer route: $($result.renderer)"
    foreach ($entry in $result.capabilities.GetEnumerator()) {
      $state = if ($entry.Value.available) { 'available' } else { 'missing' }
      $requirement = if ($entry.Value.required) { 'required' } else { 'optional' }
      Write-Host "- $($entry.Key): $state ($requirement) — $($entry.Value.purpose)"
    }
    if (-not $result.ready) {
      Write-Host "Missing required capabilities: $($result.missingRequired -join ', ')."
      Write-Host 'Explain what each item is used for, show its install source, and ask the user before downloading or installing anything.'
      Write-Host 'See docs/installation.md.'
    }
  }
  if (-not $result.ready) { exit 1 }
}
