Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path (Join-Path $repoRoot 'scripts') (Join-Path 'lib' 'creatorflow-platform.ps1'))

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

$shell = Get-CreatorFlowPowerShellCommand
$tempBase = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { [IO.Path]::GetTempPath() } else { $env:RUNNER_TEMP }
$testRoot = Join-Path $tempBase ("creatorflow-macos-core-{0}" -f [guid]::NewGuid().ToString('N'))

try {
  New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

  $joined = Join-CreatorFlowPath -BasePath $testRoot -RelativePath 'draft\visual-plan/material-beat-map.md'
  $expectedSuffix = @('draft', 'visual-plan', 'material-beat-map.md') -join [IO.Path]::DirectorySeparatorChar
  Assert-True -Condition ($joined.EndsWith($expectedSuffix)) -Message "Cross-platform path join failed: $joined"

  $capabilityJson = & $shell -NoProfile -File (Join-Path (Join-Path $repoRoot 'scripts') 'test-workflow-capabilities.ps1') -Profile Core -AsJson
  Assert-True -Condition ($LASTEXITCODE -eq 0) -Message 'Core capability preflight failed.'
  $capabilities = (@($capabilityJson) -join "`n") | ConvertFrom-Json
  Assert-True -Condition ([bool]$capabilities.ready) -Message "Core capabilities are not ready: $(@($capabilities.missingRequired) -join ', ')"

  $projectJson = & $shell -NoProfile -File (Join-Path (Join-Path $repoRoot 'scripts') 'new-video-project.ps1') -Name 'mac-smoke' -Destination $testRoot
  Assert-True -Condition ($LASTEXITCODE -eq 0) -Message 'Project creation failed.'
  $project = (@($projectJson) -join "`n") | ConvertFrom-Json
  $projectRoot = [string]$project.projectRoot
  foreach ($relativePath in @(
    'project-state.json',
    'draft/visual-plan/material-beat-map.md',
    'draft/web-assets/source-candidates.md'
  )) {
    $path = Join-CreatorFlowPath -BasePath $projectRoot -RelativePath $relativePath
    Assert-True -Condition (Test-Path -LiteralPath $path -PathType Leaf) -Message "Created project is missing: $relativePath"
  }

  & $shell -NoProfile -File (Join-Path (Join-Path $repoRoot 'scripts') 'new-video-source-candidates.ps1') -VideoDir $projectRoot -Topic 'macOS Core smoke' -Force -ForceBeatMap | Out-Null
  Assert-True -Condition ($LASTEXITCODE -eq 0) -Message 'Material scaffold failed.'
  foreach ($relativePath in @('assets/generated/incoming', 'assets/generated/accepted', 'assets/motion/incoming', 'assets/motion/raw')) {
    $path = Join-CreatorFlowPath -BasePath $projectRoot -RelativePath $relativePath
    Assert-True -Condition (Test-Path -LiteralPath $path -PathType Container) -Message "Material scaffold is missing: $relativePath"
  }

  $dependencyJson = & $shell -NoProfile -File (Join-Path (Join-Path $repoRoot 'scripts') 'resolve-workflow-dependencies.ps1') -Stage Core -AsJson
  Assert-True -Condition ($LASTEXITCODE -eq 0) -Message 'Core dependency resolver failed.'
  $dependencyPlan = (@($dependencyJson) -join "`n") | ConvertFrom-Json
  Assert-True -Condition ([bool]$dependencyPlan.ready) -Message 'Core dependency resolver did not return ready.'

  $rendererOutput = & $shell -NoProfile -File (Join-Path (Join-Path $repoRoot 'scripts') 'initialize-video-renderer.ps1') -ProjectDir $projectRoot -AsJson 2>&1
  $rendererExit = $LASTEXITCODE
  Assert-True -Condition ($rendererExit -eq 2) -Message "Renderer proposal should stop for consent with exit 2, got: $rendererExit"
  $rendererPlan = (@($rendererOutput) -join "`n") | ConvertFrom-Json
  Assert-True -Condition ($rendererPlan.action -eq 'scaffold-renderer') -Message "Unexpected renderer action: $($rendererPlan.action)"
  Assert-True -Condition ([bool]$rendererPlan.consentRequired) -Message 'Online renderer setup must require consent.'

  Write-Host "macOS Core smoke: PASS ($((Get-CreatorFlowPlatform)))"
}
finally {
  if (Test-Path -LiteralPath $testRoot -PathType Container) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}

# The renderer consent probe intentionally returns 2. Do not leak that expected
# child-process status as this smoke test's own exit code.
exit 0
