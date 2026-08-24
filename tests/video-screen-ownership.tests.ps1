Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$validator = Join-Path $repoRoot "scripts\test-video-screen-ownership.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zimeiti-screen-owner-test-" + [guid]::NewGuid().ToString("N"))

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Invoke-OwnershipCheck {
  param([string]$Root)
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $validator -VideoDir $Root 2>&1
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousPreference
  return [pscustomobject]@{ ExitCode = $exitCode; Output = (@($output) -join "`n") }
}

function Write-BeatMap {
  param(
    [string]$Body,
    [string]$Contract = "visual-task-v1; screen-owner-v1; presenter-led-mixed-media-v1; motion-job-v1.1"
  )
  $content = @"
# Material Beat Map
- Contract: $Contract
| Line ID | Time | Spoken sentence | Task ID | Visual Task | Owner | Presentation mode | Takeover | Provenance | Purpose | Handoff reason | Return to person | Evidence source | Job | Material | Motion action | Fallback / next action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
$Body
"@
  Set-Content -LiteralPath (Join-Path $tempRoot "draft\visual-plan\material-beat-map.md") -Value $content -Encoding UTF8
}

try {
  New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot "draft\visual-plan") | Out-Null

  Write-BeatMap -Body @"
| LINE01 | 00:00-00:03 | Why does this matter? | VT01 | transition | PERSON | avatar-talk | full | n/a | continue-listening | question | no | n/a | advance | assets/avatar/accepted-hook.mp4 | enter question | n/a |
| LINE02 | 00:03-00:12 | Official product page. | VT02 | prove | EVIDENCE | official-proof | full | first-party | belief | official-proof | required | https://example.test/official | prove | official page capture | highlight source | crop fallback |
| LINE03 | 00:12-00:16 | Here is the real change. | VT03 | transition | PERSON | avatar-talk | full | n/a | continue-listening | return-after-proof | no | n/a | advance | accepted-avatar judgment video | reclaim judgment | n/a |
| LINE04 | 00:16-00:25 | How the model connects. | VT04 | explain | EXPLAINER | explainer-animation | dominant | internal-animation | understanding | mechanism | recommended | n/a | explain | mechanism animation | route states | diagram fallback |
| LINE05 | 00:25-00:30 | This changes competition. | VT05 | transition | PERSON | avatar-talk | dominant | n/a | continue-listening | judgment | no | n/a | advance | latentsync judgment clip | state judgment | n/a |
| LINE06 | 00:30-00:40 | It enters real work. | VT06 | analogize | SCENE | real-footage | full | real-world | reality | enterprise-use | required | n/a | advance | licensed production footage | follow action | b-roll fallback |
| LINE07 | 00:40-00:45 | The battlefield moved. | VT07 | close | PERSON | avatar-talk | full | n/a | continue-listening | conclusion | no | n/a | advance | assets/avatar/accepted-close.webm | close | n/a |
"@
  $result = Invoke-OwnershipCheck -Root $tempRoot
  Assert-True ($result.ExitCode -eq 0) "Expected valid mixed-media sequence to pass: $($result.Output)"
  $json = $result.Output | ConvertFrom-Json
  Assert-True ($json.status -eq "PASS" -and @($json.warnings).Count -eq 0) "Expected positive sequence without warnings"
  Assert-True ($json.contracts -contains "presenter-led-mixed-media-v1") "Expected mixed-media contract in result"

  Write-BeatMap -Body @"
| LINE01 | 00:00-00:04 | Opening. | VT01 | transition | PERSON | avatar-talk | full | n/a | continue-listening | opening | no | n/a | advance | assets/avatar/static-portrait.png | enter | n/a |
"@
  $result = Invoke-OwnershipCheck -Root $tempRoot
  Assert-True ($result.ExitCode -ne 0 -and $result.Output -match "talking video") "Expected static avatar to fail"

  Write-BeatMap -Body @"
| LINE01 | 00:00-00:05 | Generated proof. | VT01 | prove | EVIDENCE | official-proof | full | generated | belief | official-proof | no | https://example.test/proof | prove | generated product page | hold | n/a |
"@
  $result = Invoke-OwnershipCheck -Root $tempRoot
  Assert-True ($result.ExitCode -ne 0 -and $result.Output -match "generated material cannot serve as EVIDENCE") "Expected generated evidence to fail"

  Write-BeatMap -Body @"
| LINE01 | 00:00-00:03 | Opening. | VT01 | transition | PERSON | avatar-talk | full | n/a | continue-listening | opening | no | n/a | advance | accepted-avatar opening video | enter | n/a |
| LINE02 | 00:03-00:06 | Item one. | VT02 | explain | EXPLAINER | support-card | bridge | internal-animation | understanding | mechanism | no | n/a | explain | support card one | reveal | n/a |
| LINE03 | 00:06-00:09 | Item two. | VT03 | explain | EXPLAINER | support-card | bridge | internal-animation | understanding | mechanism | no | n/a | explain | support card two | reveal | n/a |
| LINE04 | 00:09-00:12 | Item three. | VT04 | explain | EXPLAINER | support-card | bridge | internal-animation | understanding | mechanism | no | n/a | explain | support card three | reveal | n/a |
"@
  $result = Invoke-OwnershipCheck -Root $tempRoot
  Assert-True ($result.ExitCode -ne 0 -and $result.Output -match "PPT backbone") "Expected consecutive support cards to fail"

  Write-BeatMap -Contract "visual-task-v1; screen-owner-v1; motion-job-v1.1" -Body @"
| LINE01 | 00:00-00:04 | Opening. | VT01 | transition | PERSON | avatar-talk | full | n/a | continue-listening | opening | no | n/a | advance | presenter full-screen main frame | enter | n/a |
| LINE02 | 00:04-00:08 | Proof one. | VT02 | prove | EVIDENCE | official-proof | full | first-party | belief | official-proof | no | https://example.test/1 | prove | knowledge-card board | zoom number | n/a |
| LINE03 | 00:08-00:12 | Explain one. | VT03 | explain | EXPLAINER | support-card | bridge | internal-animation | understanding | mechanism | no | n/a | explain | knowledge-card slide | draw arrow | n/a |
| LINE04 | 00:12-00:16 | Proof two. | VT04 | prove | EVIDENCE | official-proof | full | first-party | belief | number | no | https://example.test/2 | prove | knowledge-card ppt | scale number | n/a |
| LINE05 | 00:16-00:20 | Explain two. | VT05 | explain | EXPLAINER | support-card | bridge | internal-animation | understanding | causal-chain | no | n/a | explain | knowledge-card board | draw arrow | n/a |
"@
  $result = Invoke-OwnershipCheck -Root $tempRoot
  Assert-True ($result.ExitCode -eq 0) "Expected ownership-only risk plan to warn, not fail: $($result.Output)"
  $json = $result.Output | ConvertFrom-Json
  $warningText = @($json.warnings) -join "`n"
  Assert-True ($warningText -match "only the opening") "Expected presenter-only-at-opening warning"
  Assert-True ($warningText -match "card/PPT") "Expected consecutive card/PPT warning"

  Write-BeatMap -Contract "visual-task-v1" -Body @"
| LINE01 | 00:00-00:05 | Legacy line. | VT01 | prove | EVIDENCE | official-proof | full | first-party | belief | official-proof | no | https://example.test | prove | source | hold | n/a |
"@
  $result = Invoke-OwnershipCheck -Root $tempRoot
  Assert-True ($result.ExitCode -eq 0 -and $result.Output -match "not-applicable") "Expected legacy map to remain not-applicable"

  Write-Host "video screen-ownership tests passed"
}
finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
