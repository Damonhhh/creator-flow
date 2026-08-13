param(
  [string]$ProjectDir = '',

  [string]$WorkflowConfigPath = '',

  [switch]$AcceptDownload,

  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$script:RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Test-RendererCommand {
  param([string]$Name)
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-RendererEngine {
  param([string]$ConfigPath)
  if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $local = Join-Path $script:RepoRoot 'config\workflow.local.json'
    $example = Join-Path $script:RepoRoot 'config\workflow.example.json'
    $ConfigPath = if (Test-Path -LiteralPath $local -PathType Leaf) { $local } else { $example }
  }
  elseif (-not [IO.Path]::IsPathRooted($ConfigPath)) {
    $ConfigPath = Join-Path $script:RepoRoot $ConfigPath
  }
  if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { throw "Workflow config not found: $ConfigPath" }
  $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $renderer = $config.PSObject.Properties['renderer']
  if ($null -eq $renderer -or $null -eq $renderer.Value) { return 'hyperframes' }
  $engine = $renderer.Value.PSObject.Properties['engine']
  if ($null -eq $engine -or [string]::IsNullOrWhiteSpace([string]$engine.Value)) { return 'hyperframes' }
  return [string]$engine.Value
}

function Get-VideoRendererSetupPlan {
  param(
    [Parameter(Mandatory = $true)][string]$TargetProjectDir,
    [string]$Engine = 'hyperframes',
    [scriptblock]$CommandResolver = ${function:Test-RendererCommand},
    [string]$NodeVersion = ''
  )

  $project = [IO.Path]::GetFullPath($TargetProjectDir)
  if (-not (Test-Path -LiteralPath $project -PathType Container)) { throw "Project directory not found: $project" }
  if ($Engine -ne 'hyperframes') {
    return [ordered]@{
      ready = $false
      engine = $Engine
      action = 'configure-custom-renderer'
      consentRequired = $false
      missing = @('custom renderer command')
      message = 'The selected renderer is not scaffolded by this script. Add its command to workflow.local.json.'
    }
  }

  $appDir = Join-Path $project 'hyperframes-app'
  if (Test-Path -LiteralPath $appDir -PathType Container) {
    return [ordered]@{
      ready = $true
      engine = 'hyperframes'
      action = 'none'
      consentRequired = $false
      missing = @()
      projectPath = $appDir
      message = 'Renderer project already exists.'
    }
  }

  $missing = @()
  foreach ($command in @('node', 'npm', 'npx', 'ffmpeg')) {
    if (-not (& $CommandResolver $command)) { $missing += $command }
  }
  if (-not $missing.Contains('node')) {
    if ([string]::IsNullOrWhiteSpace($NodeVersion)) {
      try { $NodeVersion = (& node --version 2>$null | Select-Object -First 1) }
      catch { $NodeVersion = '' }
    }
    if ($NodeVersion -match 'v?(\d+)\.') {
      if ([int]$Matches[1] -lt 22) { $missing += 'Node.js >= 22' }
    }
    elseif ([string]::IsNullOrWhiteSpace($NodeVersion)) {
      $missing += 'Node.js >= 22'
    }
  }

  if ($missing.Count -gt 0) {
    return [ordered]@{
      ready = $false
      engine = 'hyperframes'
      action = 'install-prerequisites'
      consentRequired = $true
      missing = @($missing | Select-Object -Unique)
      purpose = 'Node.js/npm/npx initialize and check the renderer; FFmpeg processes media.'
      installSources = @('https://nodejs.org/en/download', 'https://ffmpeg.org/download.html')
      message = 'Explain the missing prerequisites and ask for permission before downloading or installing them.'
    }
  }

  return [ordered]@{
    ready = $false
    engine = 'hyperframes'
    action = 'scaffold-renderer'
    consentRequired = $true
    missing = @('hyperframes-app')
    purpose = 'Create the project-local renderer used during Assembly.'
    command = 'npx --yes hyperframes@0.7.55 init hyperframes-app --example blank --non-interactive'
    projectPath = $appDir
    message = 'This command may download an npm package. Ask for permission before running it.'
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  if ([string]::IsNullOrWhiteSpace($ProjectDir)) { throw 'ProjectDir is required.' }
  $project = [IO.Path]::GetFullPath($ProjectDir)
  $engine = Get-RendererEngine -ConfigPath $WorkflowConfigPath
  $plan = Get-VideoRendererSetupPlan -TargetProjectDir $project -Engine $engine

  if ($plan.action -eq 'scaffold-renderer' -and $AcceptDownload) {
    Push-Location -LiteralPath $project
    try {
      & npx --yes hyperframes@0.7.55 init hyperframes-app --example blank --non-interactive
      if ($LASTEXITCODE -ne 0) { throw "HyperFrames initialization failed with exit code $LASTEXITCODE" }
    }
    finally { Pop-Location }
    $plan = Get-VideoRendererSetupPlan -TargetProjectDir $project -Engine $engine
  }

  if ($AsJson) { $plan | ConvertTo-Json -Depth 6 }
  else {
    Write-Host $plan.message
    if ($plan.PSObject.Properties['missing'] -and @($plan.missing).Count -gt 0) {
      Write-Host "Missing: $(@($plan.missing) -join ', ')"
    }
    if ($plan.PSObject.Properties['command'] -and $plan.command) { Write-Host "Proposed command: $($plan.command)" }
  }
  if (-not $plan.ready) { exit 2 }
}
