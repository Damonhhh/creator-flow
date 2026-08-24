param(
  [string]$CreatorFlowRoot = '',
  [string]$StorageRoot = '',
  [ValidateSet('', 'indextts-source', 'indextts-runtime', 'indextts-model')][string]$AcceptAction = '',
  [switch]$OpenPrerequisitePages
)

. (Join-Path $PSScriptRoot 'creatorflow-pack-common.ps1')

$root = Resolve-CreatorFlowRoot -CreatorFlowRoot $CreatorFlowRoot
if ([string]::IsNullOrWhiteSpace($StorageRoot)) {
  $StorageRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.creatorflow'
  Write-Warning "StorageRoot was not provided. Using $StorageRoot. Models and caches may consume system-drive space."
}
$storage = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($StorageRoot))
$toolRoot = Join-Path $storage 'tools'
$cacheRoot = Join-Path $storage 'cache'

$env:HF_HOME = Join-Path $cacheRoot 'huggingface'
$env:HF_HUB_CACHE = Join-Path $env:HF_HOME 'hub'
$env:UV_CACHE_DIR = Join-Path $cacheRoot 'uv'
$env:PIP_CACHE_DIR = Join-Path $cacheRoot 'pip'
$env:MODELSCOPE_CACHE = Join-Path $cacheRoot 'modelscope'

Write-Host "CreatorFlow root: $root"
Write-Host "Tool root: $toolRoot"
Write-Host "Cache root: $cacheRoot"
if (-not [string]::IsNullOrWhiteSpace($AcceptAction)) {
  Write-Host "Approved single action: $AcceptAction"
}

if ($OpenPrerequisitePages) {
  Write-Host 'Opening the official Git and uv installation pages. No prerequisite is installed automatically.'
  Open-CreatorFlowOfficialPages -Urls @(
    'https://git-scm.com/download/win',
    'https://docs.astral.sh/uv/getting-started/installation/'
  )
}

$ttsConfig = Join-Path $PSScriptRoot 'tts.indextts2.example.json'
$exitCode = Invoke-CreatorFlowResolver -CreatorFlowRoot $root -Stage ScriptTTS -TtsConfigPath $ttsConfig -ToolRoot $toolRoot -AcceptAction $AcceptAction
exit $exitCode
