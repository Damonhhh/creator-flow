param(
  [ValidateSet('Core', 'ScriptTTS', 'Material', 'Assembly', 'QA', 'PublishWrapUp')]
  [string]$Stage = 'Core',

  [string]$ProjectDir = '',
  [string]$WorkflowConfigPath = '',
  [string]$TtsConfigPath = '',
  [string]$ToolRoot = '',

  [ValidateSet('', 'agent-reach', 'indextts-source', 'indextts-runtime', 'indextts-model', 'hyperframes')]
  [string]$AcceptAction = '',

  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$script:RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:AgentReachCommit = '93ae1d18c37b707dec053c7c4f9d91cd8ef8943d'
$script:IndexTtsTag = 'v2.0.0'

$entryParameters = [ordered]@{
  Stage = $Stage
  ProjectDir = $ProjectDir
  WorkflowConfigPath = $WorkflowConfigPath
  TtsConfigPath = $TtsConfigPath
  ToolRoot = $ToolRoot
  AcceptAction = $AcceptAction
  AsJson = [bool]$AsJson
}
. (Join-Path $PSScriptRoot 'test-workflow-capabilities.ps1')
. (Join-Path $PSScriptRoot 'initialize-video-renderer.ps1')
$Stage = $entryParameters.Stage
$ProjectDir = $entryParameters.ProjectDir
$WorkflowConfigPath = $entryParameters.WorkflowConfigPath
$TtsConfigPath = $entryParameters.TtsConfigPath
$ToolRoot = $entryParameters.ToolRoot
$AcceptAction = $entryParameters.AcceptAction
$AsJson = $entryParameters.AsJson

function Test-DependencyCommand {
  param([string]$Name)
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-DefaultToolRoot {
  $userRoot = [Environment]::GetFolderPath('UserProfile')
  if ([string]::IsNullOrWhiteSpace($userRoot)) { throw 'Could not resolve the current user profile.' }
  return Join-Path $userRoot '.creatorflow\tools'
}

function Resolve-DependencyPath {
  param([string]$PathValue, [string]$BasePath = $script:RepoRoot)
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return '' }
  $expanded = [Environment]::ExpandEnvironmentVariables($PathValue)
  if (-not [IO.Path]::IsPathRooted($expanded)) { $expanded = Join-Path $BasePath $expanded }
  return [IO.Path]::GetFullPath($expanded)
}

function Get-AgentReachExecutable {
  param([string]$SelectedToolRoot, [scriptblock]$CommandResolver = ${function:Test-DependencyCommand})
  if (& $CommandResolver 'agent-reach') { return 'agent-reach' }
  $local = Join-Path $SelectedToolRoot 'agent-reach-venv\Scripts\agent-reach.exe'
  if (Test-Path -LiteralPath $local -PathType Leaf) { return $local }
  return ''
}

function Get-ResolverIndexTtsReadiness {
  param([object]$TtsConfig, [string]$SelectedToolRoot)
  $initial = Get-IndexTtsReadiness -TtsConfig $TtsConfig
  if (-not [string]::IsNullOrWhiteSpace([string]$initial.repo)) { return $initial }

  $configuredIndexTts = Get-PropertyValue -Object $TtsConfig -Name 'indexTts'
  $effectiveConfig = [pscustomobject]@{
    mode = [string](Get-PropertyValue -Object $TtsConfig -Name 'mode' -Default 'existing-audio')
    referenceAudio = Get-PropertyValue -Object $TtsConfig -Name 'referenceAudio'
    indexTts = [pscustomobject]@{
      repo = Join-Path $SelectedToolRoot 'index-tts-v2'
      python = [string](Get-PropertyValue -Object $configuredIndexTts -Name 'python' -Default '')
      cacheRoot = [string](Get-PropertyValue -Object $configuredIndexTts -Name 'cacheRoot' -Default '')
    }
  }
  return Get-IndexTtsReadiness -TtsConfig $effectiveConfig
}

function New-DependencyAction {
  param(
    [string]$Id,
    [string]$Purpose,
    [string]$OfficialSource,
    [string]$Command,
    [string]$Scope,
    [string]$Fallback,
    [bool]$AutoExecutable = $false,
    [bool]$DownloadsCode = $false,
    [bool]$LargeDownload = $false,
    [bool]$NeedsCredentials = $false,
    [string[]]$RemainingAfterAction = @()
  )
  return [ordered]@{
    id = $Id
    purpose = $Purpose
    officialSource = $OfficialSource
    command = $Command
    scope = $Scope
    fallback = $Fallback
    consentRequired = $true
    autoExecutable = $AutoExecutable
    downloadsOrRunsThirdPartyCode = $DownloadsCode
    largeDownload = $LargeDownload
    needsCredentials = $NeedsCredentials
    remainingAfterAction = @($RemainingAfterAction)
  }
}

function Get-DependencyResolutionPlan {
  param(
    [ValidateSet('Core', 'ScriptTTS', 'Material', 'Assembly', 'QA', 'PublishWrapUp')][string]$SelectedStage,
    [string]$SelectedProjectDir = '',
    [string]$SelectedWorkflowConfigPath = '',
    [string]$SelectedTtsConfigPath = '',
    [string]$SelectedToolRoot = '',
    [scriptblock]$CommandResolver = ${function:Test-DependencyCommand}
  )

  if ([string]::IsNullOrWhiteSpace($SelectedToolRoot)) { $SelectedToolRoot = Get-DefaultToolRoot }
  $SelectedToolRoot = [IO.Path]::GetFullPath($SelectedToolRoot)
  $workflowConfig = Read-OptionalJson -PathValue $SelectedWorkflowConfigPath
  $ttsConfig = Read-OptionalJson -PathValue $SelectedTtsConfigPath
  $actions = @()
  $missing = @()
  $fallbacks = @()
  $ready = $true
  $degraded = $false
  $details = [ordered]@{}

  if ($SelectedStage -in @('Core', 'QA', 'PublishWrapUp')) {
    $capabilities = Get-WorkflowCapabilities -SelectedProfile Core -WorkflowConfig $workflowConfig -TtsConfig $ttsConfig -CommandResolver $CommandResolver
    $details['core'] = $capabilities
    $missing = @($capabilities.missingRequired)
    $ready = $capabilities.ready
    foreach ($name in $missing) {
      $cap = $capabilities.capabilities[$name]
      $actions += New-DependencyAction -Id "install-$name" -Purpose $cap.purpose -OfficialSource $cap.installUrl -Command '' -Scope 'system; follow the official installer for this operating system' -Fallback 'No safe workflow fallback; install it manually, then rerun this check.'
    }
  }

  if ($SelectedStage -eq 'Material') {
    $agentReach = Get-AgentReachExecutable -SelectedToolRoot $SelectedToolRoot -CommandResolver $CommandResolver
    $fallbackCommands = @('mcporter', 'gh', 'yt-dlp', 'curl.exe') | Where-Object { & $CommandResolver $_ }
    $details['agentReach'] = [ordered]@{ available = -not [string]::IsNullOrWhiteSpace($agentReach); invocation = $agentReach }
    $details['fallbackCommands'] = @($fallbackCommands)
    if ([string]::IsNullOrWhiteSpace($agentReach)) {
      $degraded = $true
      $missing += 'agent-reach'
      $venv = Join-Path $SelectedToolRoot 'agent-reach-venv'
      $archive = "https://github.com/Panniantong/agent-reach/archive/$($script:AgentReachCommit).zip"
      $canInstallAgentReach = [bool](& $CommandResolver 'python') -or [bool](& $CommandResolver 'py')
      $actions += New-DependencyAction -Id 'agent-reach' -Purpose 'Discover first-hand web, video, social, and repository sources during Material.' -OfficialSource 'https://github.com/Panniantong/agent-reach' -Command "python -m venv `"$venv`"; <venv-python> -m pip install $archive; agent-reach install --env=auto --safe; agent-reach doctor" -Scope 'current user under .creatorflow/tools; no workspace install and no credential setup' -Fallback 'Use an available routed CLI, browser research, or user-provided assets and record the unavailable channel.' -AutoExecutable $canInstallAgentReach -DownloadsCode $true
      $fallbacks += 'Material may continue with available routed tools or user-provided assets, but source discovery is degraded.'
    }
  }

  if ($SelectedStage -eq 'ScriptTTS') {
    $mode = [string](Get-PropertyValue -Object $ttsConfig -Name 'mode' -Default 'existing-audio')
    $details['ttsMode'] = $mode
    if ($mode -notmatch '^(indextts|indextts2|clone-voice)$') {
      $fallbacks += 'Provide an existing narration file and verified SRT; no local TTS installation is required.'
    }
    else {
      $readiness = Get-ResolverIndexTtsReadiness -TtsConfig $ttsConfig -SelectedToolRoot $SelectedToolRoot
      $details['indexTts'] = $readiness
      $ready = [bool]$readiness.ready
      $defaultRepo = Join-Path $SelectedToolRoot 'index-tts-v2'
      $repo = if ([string]::IsNullOrWhiteSpace([string]$readiness.repo)) { $defaultRepo } else { [string]$readiness.repo }
      if (-not $readiness.sourceAvailable) {
        $missing += 'indextts-source'
        $actions += New-DependencyAction -Id 'indextts-source' -Purpose 'Fetch the pinned IndexTTS2 source expected by CreatorFlow’s adapter.' -OfficialSource 'https://github.com/index-tts/index-tts/tree/v2.0.0' -Command "git clone --branch $($script:IndexTtsTag) --depth 1 https://github.com/index-tts/index-tts.git `"$repo`"" -Scope 'current user under .creatorflow/tools unless indexTts.repo is configured' -Fallback 'Keep mode=existing-audio and provide narration plus verified subtitles.' -AutoExecutable ([bool](& $CommandResolver 'git')) -DownloadsCode $true -RemainingAfterAction @('install the Python runtime', 'download model files', 'provide a local reference-audio path')
      }
      else {
        if (-not $readiness.runtimeAvailable) {
          $missing += 'indextts-runtime'
          $actions += New-DependencyAction -Id 'indextts-runtime' -Purpose 'Create the project’s isolated Python environment and install IndexTTS2 dependencies.' -OfficialSource 'https://github.com/index-tts/index-tts/tree/v2.0.0' -Command "uv sync --all-extras (working directory: $repo)" -Scope 'IndexTTS repository virtual environment' -Fallback 'Use existing audio or another TTS adapter.' -AutoExecutable ([bool](& $CommandResolver 'uv')) -DownloadsCode $true -LargeDownload $true -RemainingAfterAction @('download model files', 'provide a local reference-audio path')
        }
        if (-not $readiness.modelAvailable) {
          $missing += 'indextts-model'
          $actions += New-DependencyAction -Id 'indextts-model' -Purpose 'Download the IndexTTS2 model checkpoints required for synthesis.' -OfficialSource 'https://huggingface.co/IndexTeam/IndexTTS-2' -Command "uv run hf download IndexTeam/IndexTTS-2 --local-dir=checkpoints (working directory: $repo)" -Scope 'IndexTTS checkpoints directory; large network download' -Fallback 'Use existing audio or another TTS adapter.' -AutoExecutable ([bool](& $CommandResolver 'uv')) -DownloadsCode $true -LargeDownload $true -RemainingAfterAction @('provide a local reference-audio path')
        }
      }
      if (-not $readiness.referenceAudioAvailable) {
        $missing += 'reference-audio'
        $actions += New-DependencyAction -Id 'provide-reference-audio' -Purpose 'Supply the voice reference used by the selected clone-voice route.' -OfficialSource '' -Command '' -Scope 'local private file; never copied into the public package' -Fallback 'Use an existing narration file or a non-cloning TTS adapter.' -NeedsCredentials $false
      }
      $fallbacks += 'Switch config/tts.local.json to existing-audio and provide narration plus verified SRT.'
    }
  }

  if ($SelectedStage -eq 'Assembly') {
    if ([string]::IsNullOrWhiteSpace($SelectedProjectDir)) {
      $ready = $false
      $missing += 'project-directory'
      $fallbacks += 'Pass -ProjectDir, or configure a custom renderer that satisfies the project contract.'
    }
    else {
      $project = Resolve-DependencyPath -PathValue $SelectedProjectDir
      $engine = Get-RendererEngine -ConfigPath $SelectedWorkflowConfigPath
      $renderer = Get-VideoRendererSetupPlan -TargetProjectDir $project -Engine $engine -CommandResolver $CommandResolver
      $details['renderer'] = $renderer
      $ready = [bool]$renderer.ready
      if (-not $renderer.ready) {
        $missing += @($renderer.missing)
        if ($renderer.action -eq 'scaffold-renderer') {
          $actions += New-DependencyAction -Id 'hyperframes' -Purpose $renderer.purpose -OfficialSource 'https://www.npmjs.com/package/hyperframes' -Command $renderer.command -Scope 'project-local hyperframes-app directory' -Fallback 'Use another renderer that satisfies the same project and QA contracts.' -AutoExecutable $true -DownloadsCode $true
        }
        elseif ($renderer.action -eq 'install-prerequisites') {
          foreach ($name in @($renderer.missing)) {
            $source = if ($name -match 'Node|npm|npx') { 'https://nodejs.org/en/download' } else { 'https://ffmpeg.org/download.html' }
            $actions += New-DependencyAction -Id "install-$name" -Purpose $renderer.purpose -OfficialSource $source -Command '' -Scope 'system; follow the official installer for this operating system' -Fallback 'Use a compatible renderer on a machine where its prerequisites already exist.'
          }
        }
      }
    }
  }

  $status = if ($ready -and -not $degraded) { 'ready' } elseif ($ready -and $degraded) { 'degraded' } else { 'blocked' }
  return [ordered]@{
    stage = $SelectedStage
    status = $status
    ready = $ready
    degraded = $degraded
    askBeforeInstall = $true
    missing = @($missing | Select-Object -Unique)
    proposedActions = @($actions)
    fallbacks = @($fallbacks | Select-Object -Unique)
    details = $details
    toolRoot = $SelectedToolRoot
  }
}

function Invoke-DependencyAction {
  param(
    [string]$ActionId,
    [string]$SelectedProjectDir,
    [string]$SelectedWorkflowConfigPath,
    [string]$SelectedTtsConfigPath,
    [string]$SelectedToolRoot
  )

  if ([string]::IsNullOrWhiteSpace($SelectedToolRoot)) { $SelectedToolRoot = Get-DefaultToolRoot }
  $SelectedToolRoot = [IO.Path]::GetFullPath($SelectedToolRoot)
  New-Item -ItemType Directory -Force -Path $SelectedToolRoot | Out-Null

  if ($ActionId -eq 'agent-reach') {
    $python = if (Test-DependencyCommand 'python') { 'python' } elseif (Test-DependencyCommand 'py') { 'py' } else { throw 'Python is required before Agent Reach can be installed.' }
    $venv = Join-Path $SelectedToolRoot 'agent-reach-venv'
    if (-not (Test-Path -LiteralPath $venv -PathType Container)) {
      & $python -m venv $venv
      if ($LASTEXITCODE -ne 0) { throw 'Could not create the Agent Reach virtual environment.' }
    }
    $venvPython = Join-Path $venv 'Scripts\python.exe'
    $venvCommand = Join-Path $venv 'Scripts\agent-reach.exe'
    $archive = "https://github.com/Panniantong/agent-reach/archive/$($script:AgentReachCommit).zip"
    & $venvPython -m pip install $archive
    if ($LASTEXITCODE -ne 0) { throw 'Agent Reach package installation failed.' }
    & $venvCommand install --env=auto --safe
    if ($LASTEXITCODE -ne 0) { throw 'Agent Reach safe environment check failed.' }
    & $venvCommand doctor
    if ($LASTEXITCODE -ne 0) { throw 'Agent Reach doctor reported a failure.' }
    return
  }

  $ttsConfig = Read-OptionalJson -PathValue $SelectedTtsConfigPath
  $readiness = Get-ResolverIndexTtsReadiness -TtsConfig $ttsConfig -SelectedToolRoot $SelectedToolRoot
  $repo = if ([string]::IsNullOrWhiteSpace([string]$readiness.repo)) { Join-Path $SelectedToolRoot 'index-tts-v2' } else { [string]$readiness.repo }
  if ($ActionId -eq 'indextts-source') {
    if (-not (Test-DependencyCommand 'git')) { throw 'Git is required to fetch the pinned IndexTTS2 source.' }
    if (Test-Path -LiteralPath $repo) { throw "IndexTTS target already exists: $repo" }
    & git clone --branch $script:IndexTtsTag --depth 1 https://github.com/index-tts/index-tts.git $repo
    if ($LASTEXITCODE -ne 0) { throw 'IndexTTS2 source download failed.' }
    return
  }
  if ($ActionId -in @('indextts-runtime', 'indextts-model')) {
    if (-not (Test-Path -LiteralPath $repo -PathType Container)) { throw 'Install the pinned IndexTTS2 source first.' }
    if (-not (Test-DependencyCommand 'uv')) { throw 'uv is required for the approved IndexTTS2 action. Install it from https://docs.astral.sh/uv/ and rerun the resolver.' }
    Push-Location -LiteralPath $repo
    try {
      if ($ActionId -eq 'indextts-runtime') { & uv sync --all-extras }
      else { & uv run hf download IndexTeam/IndexTTS-2 --local-dir=checkpoints }
      if ($LASTEXITCODE -ne 0) { throw "$ActionId failed with exit code $LASTEXITCODE" }
    }
    finally { Pop-Location }
    return
  }
  if ($ActionId -eq 'hyperframes') {
    if ([string]::IsNullOrWhiteSpace($SelectedProjectDir)) { throw 'ProjectDir is required for the HyperFrames action.' }
    & (Join-Path $PSScriptRoot 'initialize-video-renderer.ps1') -ProjectDir $SelectedProjectDir -WorkflowConfigPath $SelectedWorkflowConfigPath -AcceptDownload
    if ($LASTEXITCODE -ne 0) { throw 'HyperFrames initialization failed.' }
    return
  }
  throw "Action is informational or unsupported for automatic execution: $ActionId"
}

if ($MyInvocation.InvocationName -ne '.') {
  $plan = Get-DependencyResolutionPlan -SelectedStage $Stage -SelectedProjectDir $ProjectDir -SelectedWorkflowConfigPath $WorkflowConfigPath -SelectedTtsConfigPath $TtsConfigPath -SelectedToolRoot $ToolRoot
  $execution = $null
  if (-not [string]::IsNullOrWhiteSpace($AcceptAction)) {
    $selected = @($plan.proposedActions | Where-Object { $_.id -eq $AcceptAction })
    if ($selected.Count -ne 1) { throw "The requested action is not proposed for the current stage: $AcceptAction" }
    if (-not $selected[0].autoExecutable) { throw "The requested action requires manual setup: $AcceptAction" }
    Invoke-DependencyAction -ActionId $AcceptAction -SelectedProjectDir $ProjectDir -SelectedWorkflowConfigPath $WorkflowConfigPath -SelectedTtsConfigPath $TtsConfigPath -SelectedToolRoot $ToolRoot
    $execution = [ordered]@{ action = $AcceptAction; status = 'completed'; rechecked = $true }
    $plan = Get-DependencyResolutionPlan -SelectedStage $Stage -SelectedProjectDir $ProjectDir -SelectedWorkflowConfigPath $WorkflowConfigPath -SelectedTtsConfigPath $TtsConfigPath -SelectedToolRoot $ToolRoot
  }
  $plan['execution'] = $execution

  if ($AsJson) { $plan | ConvertTo-Json -Depth 10 }
  else {
    Write-Host "Dependency stage: $($plan.stage)"
    Write-Host "Status: $($plan.status)"
    if (@($plan.missing).Count -gt 0) { Write-Host "Missing: $(@($plan.missing) -join ', ')" }
    foreach ($action in @($plan.proposedActions)) {
      Write-Host "- [$($action.id)] $($action.purpose)"
      if ($action.officialSource) { Write-Host "  Official source: $($action.officialSource)" }
      if ($action.command) { Write-Host "  Proposed command: $($action.command)" }
      Write-Host "  Fallback: $($action.fallback)"
    }
    if (@($plan.proposedActions).Count -gt 0 -and [string]::IsNullOrWhiteSpace($AcceptAction)) {
      Write-Host 'No download or installation was performed. After explicit approval, rerun with one exact -AcceptAction value.'
    }
  }
  if (-not $plan.ready) { exit 2 }
}
