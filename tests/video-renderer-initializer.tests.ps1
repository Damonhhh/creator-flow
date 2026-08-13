Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$scriptPath = Join-Path $repoRoot 'scripts\initialize-video-renderer.ps1'

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

. $scriptPath

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('renderer-init-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
  $allCommands = { param($name) return $name -in @('node', 'npm', 'npx', 'ffmpeg') }
  $plan = Get-VideoRendererSetupPlan -TargetProjectDir $tempRoot -CommandResolver $allCommands -NodeVersion 'v22.14.0'
  Assert-True (-not $plan.ready) 'A project without a renderer must not be reported ready'
  Assert-True ($plan.action -eq 'scaffold-renderer') 'Expected a scaffold action'
  Assert-True $plan.consentRequired 'Scaffolding may download a package and must require consent'
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $tempRoot 'hyperframes-app'))) 'A plan must not create or download anything'

  $missingCommands = { param($name) return $name -eq 'ffmpeg' }
  $blocked = Get-VideoRendererSetupPlan -TargetProjectDir $tempRoot -CommandResolver $missingCommands
  Assert-True ($blocked.action -eq 'install-prerequisites') 'Missing commands must produce an install-prerequisites action'
  Assert-True (@($blocked.installSources).Count -eq 2) 'Missing prerequisites must include official install sources'

  New-Item -ItemType Directory -Path (Join-Path $tempRoot 'hyperframes-app') | Out-Null
  $ready = Get-VideoRendererSetupPlan -TargetProjectDir $tempRoot -CommandResolver $allCommands -NodeVersion 'v22.14.0'
  Assert-True $ready.ready 'An existing renderer project should be ready'
  Assert-True (-not $ready.consentRequired) 'An existing renderer must not ask to download again'
}
finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force
}

Write-Host 'video renderer initializer tests passed'
