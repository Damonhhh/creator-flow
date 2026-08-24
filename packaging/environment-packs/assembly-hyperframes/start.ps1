param(
  [string]$CreatorFlowRoot = '',
  [Parameter(Mandatory = $true)][string]$ProjectDir,
  [ValidateSet('', 'hyperframes')][string]$AcceptAction = '',
  [switch]$OpenPrerequisitePages
)

. (Join-Path $PSScriptRoot 'creatorflow-pack-common.ps1')

$root = Resolve-CreatorFlowRoot -CreatorFlowRoot $CreatorFlowRoot
$project = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($ProjectDir))
if (-not (Test-Path -LiteralPath $project -PathType Container)) {
  throw "Video project directory does not exist: $project"
}

Write-Host "CreatorFlow root: $root"
Write-Host "Video project: $project"
if (-not [string]::IsNullOrWhiteSpace($AcceptAction)) {
  Write-Host 'Approved action: download and initialize HyperFrames inside this video project.'
}

if ($OpenPrerequisitePages) {
  Write-Host 'Opening the official Node.js and FFmpeg pages. No system prerequisite is installed automatically.'
  Open-CreatorFlowOfficialPages -Urls @(
    'https://nodejs.org/en/download',
    'https://ffmpeg.org/download.html'
  )
}

$exitCode = Invoke-CreatorFlowResolver -CreatorFlowRoot $root -Stage Assembly -ProjectDir $project -AcceptAction $AcceptAction
exit $exitCode
