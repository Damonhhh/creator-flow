param(
  [string]$CreatorFlowRoot = '',
  [switch]$OpenOfficialDownloads
)

. (Join-Path $PSScriptRoot 'creatorflow-pack-common.ps1')

$root = Resolve-CreatorFlowRoot -CreatorFlowRoot $CreatorFlowRoot
Write-Host "CreatorFlow root: $root"
$exitCode = Invoke-CreatorFlowResolver -CreatorFlowRoot $root -Stage Core

if ($OpenOfficialDownloads) {
  Write-Host 'Opening official download pages. You still control downloads, installation, and PATH changes.'
  Open-CreatorFlowOfficialPages -Urls @(
    'https://www.python.org/downloads/windows/',
    'https://ffmpeg.org/download.html',
    'https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows'
  )
}

exit $exitCode
