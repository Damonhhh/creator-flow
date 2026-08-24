param(
  [string]$CreatorFlowRoot = '',
  [ValidateSet('', 'agent-reach')][string]$AcceptAction = '',
  [string]$ToolRoot = ''
)

. (Join-Path $PSScriptRoot 'creatorflow-pack-common.ps1')

$root = Resolve-CreatorFlowRoot -CreatorFlowRoot $CreatorFlowRoot
Write-Host "CreatorFlow root: $root"
if (-not [string]::IsNullOrWhiteSpace($AcceptAction)) {
  Write-Host 'Approved action: download and run the pinned Agent Reach version. Login and credential setup are not included.'
}
$exitCode = Invoke-CreatorFlowResolver -CreatorFlowRoot $root -Stage Material -ToolRoot $ToolRoot -AcceptAction $AcceptAction
exit $exitCode
