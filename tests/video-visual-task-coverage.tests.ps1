Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$validator = Join-Path $repoRoot "scripts\test-video-visual-task-coverage.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zimeiti-vt-coverage-test-" + [guid]::NewGuid().ToString("N"))

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Invoke-CoverageCheck {
  param([string]$Root)
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $validator -VideoDir $Root 2>&1
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousPreference
  return [pscustomobject]@{ ExitCode = $exitCode; Output = (@($output) -join "`n") }
}

try {
  $visual = Join-Path $tempRoot "draft\visual-plan"
  $app = Join-Path $tempRoot "hyperframes-app"
  New-Item -ItemType Directory -Force -Path $visual, $app | Out-Null

  @"
# Material Beat Map
- Contract: visual-task-v1
| Line ID | Time | Spoken sentence | Task ID | Visual Task | Job | Material | Motion Treatment | Fallback / next action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LINE01 | 00:00-00:05 | First line. | VT01 | prove | prove | source video | zoom | fallback still |
| LINE02 | 00:05-00:10 | Second line. | VT01 | prove | prove | source video | zoom | fallback still |
| LINE03 | 00:10-00:15 | Third line. | VT02 | close | advance | closing scene | highlight | closing card |
"@ | Set-Content -LiteralPath (Join-Path $visual "material-beat-map.md") -Encoding UTF8

  $passManifest = [ordered]@{
    schemaVersion = "visual-task-coverage-v1"
    tasks = @(
      [ordered]@{ taskId="VT01"; lineIds=@("LINE01","LINE02"); startSec=0; endSec=10; status="implemented"; implementation="official source window with moving highlight"; ownerElement="scene-vt01" },
      [ordered]@{ taskId="VT02"; lineIds=@("LINE03"); startSec=10; endSec=15; status="implemented"; implementation="closing action card"; ownerElement="scene-vt02" }
    )
  }
  $manifestPath = Join-Path $app "visual-task-coverage.json"
  $passManifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
  $result = Invoke-CoverageCheck -Root $tempRoot
  Assert-True ($result.ExitCode -eq 0) "Expected complete visual-task coverage to pass: $($result.Output)"

  $missingLineManifest = [ordered]@{
    schemaVersion = "visual-task-coverage-v1"
    tasks = @(
      [ordered]@{ taskId="VT01"; lineIds=@("LINE01"); startSec=0; endSec=10; status="implemented"; implementation="source window"; ownerElement="scene-vt01" },
      [ordered]@{ taskId="VT02"; lineIds=@("LINE03"); startSec=10; endSec=15; status="implemented"; implementation="closing card"; ownerElement="scene-vt02" }
    )
  }
  $missingLineManifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
  $result = Invoke-CoverageCheck -Root $tempRoot
  Assert-True ($result.ExitCode -ne 0 -and $result.Output -match "LINE02") "Expected missing shared LINE## coverage to fail"

  $missingTaskManifest = [ordered]@{
    schemaVersion = "visual-task-coverage-v1"
    tasks = @(
      [ordered]@{ taskId="VT01"; lineIds=@("LINE01","LINE02"); startSec=0; endSec=10; status="implemented"; implementation="source window"; ownerElement="scene-vt01" }
    )
  }
  $missingTaskManifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
  $result = Invoke-CoverageCheck -Root $tempRoot
  Assert-True ($result.ExitCode -ne 0 -and $result.Output -match "VT02") "Expected missing VT## implementation to fail"

  Write-Host "video visual-task coverage tests passed"
}
finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
