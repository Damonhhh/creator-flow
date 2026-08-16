Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$validator = Join-Path $repoRoot "scripts\test-video-material-mix.ps1"
$generator = Join-Path $repoRoot "scripts\new-video-source-candidates.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zimeiti-visual-task-test-" + [guid]::NewGuid().ToString("N"))

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function New-VisualTaskFixture {
  param(
    [string]$Name,
    [ValidateSet("distinct", "shared-valid", "shared-action-mismatch", "shared-nonconsecutive", "missing-query", "missing-accepted-status")]
    [string]$Variant
  )

  $root = Join-Path $tempRoot $Name
  $web = Join-Path $root "draft\web-assets"
  $visual = Join-Path $root "draft\visual-plan"
  New-Item -ItemType Directory -Force -Path $web, $visual | Out-Null

  $candidateStatusLine = if ($Variant -eq "missing-accepted-status") { "- Status: pending" } else { "- Status: accepted" }
  @"
# Production Carryover
- Hook gives a take-away: Show one useful result before the first explanation starts.
- Proof appears before polish: Put the official product evidence inside the opening ten seconds.
- Abstract nouns become actions: Turn every abstract phrase into a visible state change.
- Invisible mechanisms get process visuals: Use a moving process path instead of a static label.
- Key terms and entities get anchors: Pair named entities with readable source or product anchors.
- Visual rhythm has breathing points: Insert a short visual reset between dense explanations.
- Closing thesis lands visually: End on one compact audience-facing action and hold it clearly.
- Publish package closes the loop: Prepare title, cover, subtitles, QA, copy, and sync evidence.
"@ | Set-Content -LiteralPath (Join-Path $root "draft\production-carryover.md") -Encoding UTF8

  $queryLine = if ($Variant -eq "missing-query") { "- Search query:" } else { "- Search query: official product workflow demonstration" }
  @"
# Internet Source Candidates
- Contract: agent-reach-material-v1
- External sourcing status: sourced
- Channel availability summary: agent-reach wrapper unavailable; mcporter Exa and gh available
- Search fallback: mcporter Exa -> gh -> local diagram

### 1. Official product source
- Source URL: https://example.com/source
- Platform / type: official page
- Spoken line ID / time: LINE01 00:00-00:08
- Visual task: prove
- Material role: prove
- Agent Reach route / command: mcporter call exa.web_search_exa
- Channel preflight: mcporter available
$queryLine
- Useful source timestamp / page region: hero product panel
- Matched visible subject / action: product input becomes visible result
- Why it aligns with the spoken sentence: the same product and result appear on screen
- Rights / provenance risk: short source quotation
- Local path / next action: assets/proof/source.png
- Fallback: local product capture
$candidateStatusLine

- Material role: prove
- Material role: explain
- Material role: explain
- Material role: advance
- Material role: advance
"@ | Set-Content -LiteralPath (Join-Path $web "source-candidates.md") -Encoding UTF8

  $line1Task = "VT01"
  $line2Task = if ($Variant -in @("shared-valid", "shared-action-mismatch")) { "VT01" } else { "VT02" }
  $line3Task = if ($Variant -eq "shared-nonconsecutive") { "VT01" } else { "VT03" }
  $line2Motion = if ($Variant -eq "shared-valid") {
    "motion job: enter; subject: product input; change: hidden input -> visible result; fallback: product capture with camera push"
  } elseif ($Variant -eq "shared-action-mismatch") {
    "motion job: highlight; subject: product input; change: hidden input -> visible result; fallback: product capture with camera push"
  } else {
    "motion job: highlight; subject: official result; change: full page -> cited detail; fallback: readable source crop"
  }

  @"
# Material Beat Map
- Contract: visual-task-v1; motion-job-v1.1

| Line ID | Time | Spoken sentence | Task ID | Visual Task | Job | Material | Motion Treatment | Fallback / next action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LINE01 | 00:00-00:08 | The product accepts one input and returns a result. | $line1Task | prove | advance + prove | official product video | motion job: enter; subject: product input; change: hidden input -> visible result; fallback: product capture with camera push | use local product capture |
| LINE02 | 00:08-00:16 | The result appears in the same product window. | $line2Task | prove | prove | official product video | $line2Motion | use readable source crop |
| LINE03 | 00:16-00:24 | The process separates the request into two steps. | $line3Task | explain | explain | animated process video | motion job: split; subject: request path; change: one request -> two visible steps; fallback: local process animation | use local process animation |
| LINE04 | 00:24-00:32 | A filing cabinet gives a physical comparison. | VT04 | analogize | explain | moving physical analogy video | motion job: compare; subject: two filing states; change: loose pages -> sorted folders; fallback: side-by-side reveal | use local analogy scene |
| LINE05 | 00:32-00:40 | Now move from the example to the checklist. | VT05 | transition | advance | animated transition video | motion job: connect; subject: example and checklist; change: example -> checklist; fallback: moving connector line | use connector transition |
| LINE06 | 00:40-00:48 | Save the checklist and test one real case. | VT06 | close | advance | closing checklist motion | motion job: compress; subject: action steps; change: scattered steps -> one action; fallback: sequential checklist highlight | use closing checklist |
"@ | Set-Content -LiteralPath (Join-Path $visual "material-beat-map.md") -Encoding UTF8

  @"
# Generated Motion Asset Plan
- Generation branch: not-needed
- Decision and reason: external and local assets cover every timed visual task.
"@ | Set-Content -LiteralPath (Join-Path $visual "generated-motion-asset-plan.md") -Encoding UTF8

  return $root
}

function Invoke-MaterialCheck {
  param(
    [string]$Fixture,
    [switch]$NoStateUpdate
  )
  $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validator, "-VideoDir", $Fixture)
  if ($NoStateUpdate) { $arguments += "-NoStateUpdate" }
  $output = & powershell @arguments 2>&1
  return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = (@($output) -join "`n") }
}

function New-GeneratedReadinessFixture {
  param(
    [string]$Name,
    [ValidateSet("prompt-pack-ready", "awaiting-user-stills", "stills-received", "motion-planned", "motion-ready", "complete")]
    [string]$Readiness,
    [ValidateSet("pending", "local", "minimax", "grok")]
    [string]$MotionMode = "pending",
    [switch]$SkipPromptPack,
    [switch]$WriteIncoming,
    [switch]$WriteStillIntake,
    [switch]$WriteMotionIntake,
    [switch]$WriteGrokMetadata
  )

  $root = New-VisualTaskFixture -Name $Name -Variant "distinct"
  $visual = Join-Path $root "draft\visual-plan"
  $incoming = Join-Path $root "assets\generated\incoming"
  $accepted = Join-Path $root "assets\generated\accepted"
  $motionIncoming = Join-Path $root "assets\motion\incoming"
  $motionRaw = Join-Path $root "assets\motion\raw"
  New-Item -ItemType Directory -Force -Path $incoming, $accepted, $motionIncoming, $motionRaw | Out-Null

  $decision = if ($MotionMode -eq "pending") { "pending-after-intake" } elseif ($MotionMode -eq "local") { "local-motion" } else { "motion-required" }
  $owner = if ($MotionMode -eq "pending") { "pending" } elseif ($MotionMode -eq "local") { "HyperFrames" } elseif ($MotionMode -eq "minimax") { "local MiniMax H3" } else { "third-party Grok-compatible" }
  $motionPack = if ($MotionMode -in @("minimax", "grok")) { "draft\visual-plan\motion-video-prompt-pack.md" } elseif ($MotionMode -eq "local") { "not-needed" } else { "pending-after-still-intake" }
  $motionRows = if ($MotionMode -in @("minimax", "grok")) {
    $provider = if ($MotionMode -eq "minimax") { "local MiniMax H3" } else { "third-party Grok-compatible" }
    "| MOV01-scene | IMG01-scene | 00:16-00:24 | $provider | 4-6s | request path separates into two visible branches | final frame holds completed split for 0.5s | HyperFrames local split diagram | assets\motion\raw\MOV01-scene.mp4 |"
  } else { "" }

  @"
# Generated Image And Motion Asset Plan
- Contract: generated-material-readiness-v1
- Script status: locked
- Timed beat source: final SRT timing
- Generation branch: required
- Material readiness: $Readiness
- External material coverage: official proof covers prove beats; generated media is not used as proof
- Internal reusable asset coverage: local diagrams cover all but one mechanism beat
- Remaining uncovered beats: LINE03 mechanism scene
- Cardification risk: the mechanism would otherwise become a static label card
- Decision and reason: generate one primary scene plus two true alternatives before assembly
- Minimum coverage stills: 1
- Planned still prompts: 3
- Required surplus stills: 2
- Pre-intake motion exception: none
- Still-image prompt pack: draft\visual-plan\still-image-prompt-pack.md
- Motion-video prompt pack: $motionPack
- Returned stills folder: assets\generated\incoming\
- Accepted stills folder: assets\generated\accepted\
- Source-image intake map: draft\visual-plan\source-image-rename-map.md
- Returned motion folder: assets\motion\incoming\
- Accepted motion folder: assets\motion\raw\

## Material Coverage Gaps
| Beat / time | Visual need | External candidate | Internal candidate | Gap / cardification risk | Chosen path |
| --- | --- | --- | --- | --- | --- |
| LINE03 00:16-00:24 | visible request split | no semantically matching first-hand clip | local fallback diagram | static card risk | generated still with post-intake route decision |

## Generated Still Plan
| Image ID | Beat / time | Role | Coverage use | Visual job | Prompt source | Decision after intake | Motion owner | Acceptance check | Expected filename |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| IMG01-scene | LINE03 00:16-00:24 | explain | primary | request becomes two visible branches | still prompt pack | $decision | $owner | clear start and end states; no generated text | IMG01-scene.png |
| IMG02-scene-alt | LINE03 00:16-00:24 | explain | alternate-for: IMG01-scene | overhead alternate composition | still prompt pack | $(if ($MotionMode -eq 'pending') { 'pending-after-intake' } else { 'reject' }) | $(if ($MotionMode -eq 'pending') { 'pending' } else { 'none' }) | visibly different framing; same semantic job | IMG02-scene-alt.png |
| IMG03-scene-alt-two | LINE03 00:16-00:24 | explain | alternate-for: IMG01-scene | close alternate composition | still prompt pack | $(if ($MotionMode -eq 'pending') { 'pending-after-intake' } else { 'reject' }) | $(if ($MotionMode -eq 'pending') { 'pending' } else { 'none' }) | different depth and route layout; same semantic job | IMG03-scene-alt-two.png |

## Motion Clip Plan
| Motion ID | Source image | Beat / time | Provider | Duration | Visible action | End-state / tail frame | Fallback | Accepted path |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- |
$motionRows
"@ | Set-Content -LiteralPath (Join-Path $visual "generated-motion-asset-plan.md") -Encoding UTF8

  if (-not $SkipPromptPack) {
    @"
# Still Image Prompt Pack
- Contract: still-image-prompt-pack-v1
- Prompt pack status: ready
- Return folder: $incoming
- Accepted folder after inspection: $accepted
- Minimum coverage stills: 1
- Planned still prompts: 3
- Required surplus stills: 2

## Expected Files
| Image ID | Expected filename | Beat / task | Coverage use | Acceptance check |
| --- | --- | --- | --- | --- |
| IMG01-scene | IMG01-scene.png | LINE03 / VT03 / 00:16-00:24 | primary | clear request split; no generated text or logo |
| IMG02-scene-alt | IMG02-scene-alt.png | LINE03 / VT03 / 00:16-00:24 | alternate-for: IMG01-scene | overhead framing with a distinct route layout |
| IMG03-scene-alt-two | IMG03-scene-alt-two.png | LINE03 / VT03 / 00:16-00:24 | alternate-for: IMG01-scene | close framing with readable state separation |

## Prompt: IMG01-scene
Create a vertical action-ready scene where one request visibly separates into two branches, with a clean subtitle-safe lower area. No readable text, logo, watermark, poster layout, or fake UI.

## Prompt: IMG02-scene-alt
Create a genuinely different overhead composition of the same request splitting into two branches. Keep the lower subtitle area clear. No readable text, logo, watermark, poster layout, or fake UI.

## Prompt: IMG03-scene-alt-two
Create a closer composition with clear depth and two separated destination states. Keep the lower subtitle area clear. No readable text, logo, watermark, poster layout, or fake UI.
"@ | Set-Content -LiteralPath (Join-Path $visual "still-image-prompt-pack.md") -Encoding UTF8
  }

  if ($WriteIncoming) {
    foreach ($name in @("IMG01-scene.png", "IMG02-scene-alt.png", "IMG03-scene-alt-two.png")) {
      "fixture" | Set-Content -LiteralPath (Join-Path $incoming $name) -Encoding UTF8
    }
  }

  if ($WriteStillIntake) {
    "fixture" | Set-Content -LiteralPath (Join-Path $accepted "IMG01-scene.png") -Encoding UTF8
    @"
# Source Image Rename Map
| Image ID | Incoming source | Dimensions | Decision | Reason | Canonical path |
| --- | --- | --- | --- | --- | --- |
| IMG01-scene | assets/generated/incoming/IMG01-scene.png | 1080x1920 | accepted | strongest visible split | assets/generated/accepted/IMG01-scene.png |
| IMG02-scene-alt | assets/generated/incoming/IMG02-scene-alt.png | 1080x1920 | rejected | weaker route separation | none |
| IMG03-scene-alt-two | assets/generated/incoming/IMG03-scene-alt-two.png | 1080x1920 | rejected | subtitle safe area too small | none |
"@ | Set-Content -LiteralPath (Join-Path $visual "source-image-rename-map.md") -Encoding UTF8
  }

  if ($WriteMotionIntake) {
    $intakeProvider = if ($MotionMode -eq "minimax") { "local MiniMax H3" } else { "third-party Grok-compatible" }
    "MOV01-scene: one visible split, 4-6 seconds, stable final frame, $intakeProvider." | Set-Content -LiteralPath (Join-Path $visual "motion-video-prompt-pack.md") -Encoding UTF8
    "MOV01-scene -> assets/motion/raw/MOV01-scene.mp4; accepted after inspection." | Set-Content -LiteralPath (Join-Path $visual "source-motion-rename-map.md") -Encoding UTF8
    "MOV01-scene: ffprobe PASS, H.264 SDR, visual PASS, stable tail; provider is not the official xAI API." | Set-Content -LiteralPath (Join-Path $visual "motion-video-intake.md") -Encoding UTF8
    "fixture" | Set-Content -LiteralPath (Join-Path $motionRaw "MOV01-scene.mp4") -Encoding UTF8
  }

  if ($WriteGrokMetadata) {
    [ordered]@{
      provider = "third-party-grok-compatible"
      officialXaiApi = $false
      requestId = "req-fixture-001"
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $motionRaw "MOV01-scene.generation.json") -Encoding UTF8
  }

  return $root
}

try {
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

  $generated = Join-Path $tempRoot "generated-template"
  New-Item -ItemType Directory -Force -Path $generated | Out-Null
  & $generator -VideoDir $generated -Topic "visual task fixture" | Out-Null
  $generatedSource = Get-Content -LiteralPath (Join-Path $generated "draft\web-assets\source-candidates.md") -Raw -Encoding UTF8
  $generatedJson = Get-Content -LiteralPath (Join-Path $generated "draft\web-assets\source-candidates.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  $generatedState = Get-Content -LiteralPath (Join-Path $generated "project-state.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($generatedSource -match "Agent Reach route=(available|unavailable)") "Expected generated source template to record the real Agent Reach preflight"
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$generatedJson.channelAvailabilitySummary)) "Expected generated JSON route availability"
  Assert-True ($generatedState.currentStage -eq "Material" -and $generatedState.stageStatus -eq "in_progress") "Expected generator to initialize Material project state"
  Assert-True ((Get-Content -LiteralPath (Join-Path $generated "draft\visual-plan\generated-motion-asset-plan.md") -Raw -Encoding UTF8) -match "generated-material-readiness-v1") "Expected generated readiness contract"
  Assert-True ((Get-Content -LiteralPath (Join-Path $generated "draft\visual-plan\still-image-prompt-pack.md") -Raw -Encoding UTF8) -match "still-image-prompt-pack-v1") "Expected still prompt-pack template"
  Assert-True (Test-Path -LiteralPath (Join-Path $generated "assets\generated\incoming")) "Expected stable generated incoming folder"
  Assert-True (Test-Path -LiteralPath (Join-Path $generated "assets\generated\accepted")) "Expected stable generated accepted folder"

  $distinct = New-VisualTaskFixture -Name "distinct" -Variant "distinct"
  $result = Invoke-MaterialCheck -Fixture $distinct
  Assert-True ($result.ExitCode -eq 0) "Expected distinct VT tasks to pass: $($result.Output)"
  $state = Get-Content -LiteralPath (Join-Path $distinct "project-state.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($state.currentStage -eq "Material" -and $state.stageStatus -eq "complete") "Expected Material complete state after PASS"

  $shared = New-VisualTaskFixture -Name "shared-valid" -Variant "shared-valid"
  $result = Invoke-MaterialCheck -Fixture $shared
  Assert-True ($result.ExitCode -eq 0) "Expected continuous shared VT task to pass: $($result.Output)"

  $legacy = New-VisualTaskFixture -Name "legacy-compatible" -Variant "distinct"
  $legacyMapPath = Join-Path $legacy "draft\visual-plan\material-beat-map.md"
  $legacyPlanPath = Join-Path $legacy "draft\visual-plan\generated-motion-asset-plan.md"
  ((Get-Content -LiteralPath $legacyMapPath -Raw -Encoding UTF8).Replace("visual-task-v1; ", "") + "`n- Jimeng / Seedance not required; native HyperFrames motion is used.`n") | Set-Content -LiteralPath $legacyMapPath -Encoding UTF8
  (Get-Content -LiteralPath $legacyPlanPath -Raw -Encoding UTF8).Replace("Generation branch: not-needed", "Generation branch: not-assessed") | Set-Content -LiteralPath $legacyPlanPath -Encoding UTF8
  $result = Invoke-MaterialCheck -Fixture $legacy
  Assert-True ($result.ExitCode -eq 0) "Expected legacy project without visual-task-v1 to ignore unassessed generated branch: $($result.Output)"

  $actionMismatch = New-VisualTaskFixture -Name "shared-action-mismatch" -Variant "shared-action-mismatch"
  $result = Invoke-MaterialCheck -Fixture $actionMismatch
  Assert-True ($result.ExitCode -ne 0 -and $result.Output -match "same explicit visible action and subject") "Expected shared VT action mismatch to fail"
  $blockedState = Get-Content -LiteralPath (Join-Path $actionMismatch "project-state.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($blockedState.stageStatus -eq "blocked") "Expected Material blocked state after FAIL"

  $nonconsecutive = New-VisualTaskFixture -Name "shared-nonconsecutive" -Variant "shared-nonconsecutive"
  $result = Invoke-MaterialCheck -Fixture $nonconsecutive
  Assert-True ($result.ExitCode -ne 0 -and $result.Output -match "consecutive LINE## rows") "Expected nonconsecutive shared VT task to fail"

  $missingQuery = New-VisualTaskFixture -Name "missing-query" -Variant "missing-query"
  $result = Invoke-MaterialCheck -Fixture $missingQuery
  Assert-True ($result.ExitCode -ne 0 -and $result.Output -match "search query") "Expected sourced candidate without query to fail"

  $missingAccepted = New-VisualTaskFixture -Name "missing-accepted-status" -Variant "missing-accepted-status"
  $result = Invoke-MaterialCheck -Fixture $missingAccepted
  Assert-True ($result.ExitCode -ne 0 -and $result.Output -match "at least one candidate block") "Expected sourced status without an accepted candidate to fail"

  $strictNotNeeded = New-VisualTaskFixture -Name "strict-not-needed" -Variant "distinct"
  @"
# Generated Image And Motion Asset Plan
- Contract: generated-material-readiness-v1
- Script status: locked
- Generation branch: not-needed
- Material readiness: complete
- External material coverage: accepted first-hand assets cover every timed beat
- Internal reusable asset coverage: local diagrams cover the remaining explain tasks
- Remaining uncovered beats: none
- Cardification risk: none
- Decision and reason: no generated media is required
"@ | Set-Content -LiteralPath (Join-Path $strictNotNeeded "draft\visual-plan\generated-motion-asset-plan.md") -Encoding UTF8
  $result = Invoke-MaterialCheck -Fixture $strictNotNeeded
  Assert-True ($result.ExitCode -eq 0) "Expected strict not-needed readiness to pass: $($result.Output)"
  $strictStatePath = Join-Path $strictNotNeeded "project-state.json"
  $strictState = Get-Content -LiteralPath $strictStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
  $strictState.currentStage = "Publish Wrap Up"
  $strictState.stageStatus = "pending_manual_publish"
  $strictState | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $strictStatePath -Encoding UTF8
  $stateHashBeforeAudit = (Get-FileHash -LiteralPath $strictStatePath -Algorithm SHA256).Hash
  $result = Invoke-MaterialCheck -Fixture $strictNotNeeded -NoStateUpdate
  $stateHashAfterAudit = (Get-FileHash -LiteralPath $strictStatePath -Algorithm SHA256).Hash
  Assert-True ($result.ExitCode -eq 0 -and $stateHashBeforeAudit -eq $stateHashAfterAudit) "Expected -NoStateUpdate audit mode to preserve project state"

  $missingPrompt = New-GeneratedReadinessFixture -Name "required-missing-prompt" -Readiness "prompt-pack-ready" -MotionMode "pending" -SkipPromptPack
  $result = Invoke-MaterialCheck -Fixture $missingPrompt
  Assert-True ($result.ExitCode -ne 0 -and $result.Output -match "still-image-prompt-pack.md") "Expected required branch without still prompt pack to fail"

  $awaitingStills = New-GeneratedReadinessFixture -Name "awaiting-user-stills" -Readiness "awaiting-user-stills" -MotionMode "pending"
  $result = Invoke-MaterialCheck -Fixture $awaitingStills
  Assert-True ($result.ExitCode -ne 0 -and $result.Output -match "awaiting-user-stills") "Expected awaiting-user-stills to remain a clear Material blocker"
  $awaitingState = Get-Content -LiteralPath (Join-Path $awaitingStills "project-state.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($awaitingState.stageStatus -eq "blocked" -and $awaitingState.nextAction -match "IMG##") "Expected awaiting-user-stills next action in project state"

  $returnedNoIntake = New-GeneratedReadinessFixture -Name "returned-no-intake" -Readiness "motion-planned" -MotionMode "local" -WriteIncoming
  $result = Invoke-MaterialCheck -Fixture $returnedNoIntake
  Assert-True ($result.ExitCode -ne 0 -and $result.Output -match "source-image-rename-map.md") "Expected returned stills without intake map to fail"

  $localComplete = New-GeneratedReadinessFixture -Name "local-motion-complete" -Readiness "complete" -MotionMode "local" -WriteIncoming -WriteStillIntake
  $result = Invoke-MaterialCheck -Fixture $localComplete
  Assert-True ($result.ExitCode -eq 0) "Expected accepted stills with HyperFrames local motion to pass: $($result.Output)"

  $grokMissingProvenance = New-GeneratedReadinessFixture -Name "grok-missing-provenance" -Readiness "complete" -MotionMode "grok" -WriteIncoming -WriteStillIntake -WriteMotionIntake
  $result = Invoke-MaterialCheck -Fixture $grokMissingProvenance
  Assert-True ($result.ExitCode -ne 0 -and $result.Output -match "generation.json") "Expected Grok motion without provenance metadata to fail"

  $richComplete = New-GeneratedReadinessFixture -Name "rich-material-complete" -Readiness "complete" -MotionMode "grok" -WriteIncoming -WriteStillIntake -WriteMotionIntake -WriteGrokMetadata
  $result = Invoke-MaterialCheck -Fixture $richComplete
  Assert-True ($result.ExitCode -eq 0) "Expected full surplus-still and Grok-intake flow to pass: $($result.Output)"

  $minimaxComplete = New-GeneratedReadinessFixture -Name "minimax-material-complete" -Readiness "complete" -MotionMode "minimax" -WriteIncoming -WriteStillIntake -WriteMotionIntake
  $result = Invoke-MaterialCheck -Fixture $minimaxComplete
  Assert-True ($result.ExitCode -eq 0) "Expected full local MiniMax H3 intake flow to pass: $($result.Output)"

  Write-Host "video material visual-task tests passed"
}
finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
