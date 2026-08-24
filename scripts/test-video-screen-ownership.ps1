param(
  [Parameter(Mandatory = $true)]
  [string]$VideoDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Split-MarkdownRow {
  param([string]$Line)
  $trimmed = $Line.Trim()
  if (-not $trimmed.StartsWith("|")) { return @() }
  return @(($trimmed.Trim("|") -split "\|") | ForEach-Object { $_.Trim() })
}

function Get-HeaderIndex {
  param([string[]]$Headers, [string]$Pattern)
  for ($i = 0; $i -lt $Headers.Count; $i++) {
    if ($Headers[$i] -match $Pattern) { return $i }
  }
  return -1
}

function Get-Cell {
  param([string[]]$Cells, [int]$Index)
  if ($Index -lt 0 -or $Index -ge $Cells.Count) { return "" }
  return ([string]$Cells[$Index]).Trim()
}

$root = (Resolve-Path -LiteralPath $VideoDir -ErrorAction Stop).Path
$beatMapPath = Join-Path $root "draft\visual-plan\material-beat-map.md"
if (-not (Test-Path -LiteralPath $beatMapPath)) {
  throw "Missing material beat map: $beatMapPath"
}

$beatText = Get-Content -LiteralPath $beatMapPath -Raw -Encoding UTF8
if ($beatText -notmatch '(?i)screen-owner-v1') {
  [ordered]@{ status = "not-applicable"; reason = "screen-owner-v1 not declared" } | ConvertTo-Json
  exit 0
}
$mixedMediaDeclared = $beatText -match '(?i)presenter-led-mixed-media-v1'

$lines = @($beatText -split "`r?`n")
$rows = @()
for ($i = 0; $i -lt ($lines.Count - 1); $i++) {
  if (-not $lines[$i].Trim().StartsWith("|")) { continue }
  if ($lines[$i + 1] -notmatch '^\s*\|?\s*:?-{3,}') { continue }
  $headers = @(Split-MarkdownRow $lines[$i])
  $indexes = [ordered]@{
    LineId = Get-HeaderIndex -Headers $headers -Pattern '(?i)(line\s*id|sentence\s*id)'
    TaskId = Get-HeaderIndex -Headers $headers -Pattern '(?i)task\s*id'
    Owner = Get-HeaderIndex -Headers $headers -Pattern '(?i)^owner$|screen\s*owner'
    Mode = Get-HeaderIndex -Headers $headers -Pattern '(?i)presentation\s*mode|media\s*mode'
    Takeover = Get-HeaderIndex -Headers $headers -Pattern '(?i)^takeover$|screen\s*takeover'
    Provenance = Get-HeaderIndex -Headers $headers -Pattern '(?i)^provenance$|source\s*tier'
    Purpose = Get-HeaderIndex -Headers $headers -Pattern '(?i)^purpose$'
    Handoff = Get-HeaderIndex -Headers $headers -Pattern '(?i)handoff\s*reason'
    Return = Get-HeaderIndex -Headers $headers -Pattern '(?i)return\s*to\s*person'
    Evidence = Get-HeaderIndex -Headers $headers -Pattern '(?i)evidence\s*source'
    Material = Get-HeaderIndex -Headers $headers -Pattern '(?i)^material$|^source material$|^asset$'
    Motion = Get-HeaderIndex -Headers $headers -Pattern '(?i)motion\s*(action|treatment)|design\s*note'
  }
  $requiredIndexes = @($indexes.LineId, $indexes.TaskId, $indexes.Owner, $indexes.Purpose, $indexes.Handoff, $indexes.Return, $indexes.Evidence, $indexes.Material, $indexes.Motion)
  if ($mixedMediaDeclared) {
    $requiredIndexes += @($indexes.Mode, $indexes.Takeover, $indexes.Provenance)
  }
  if (@($requiredIndexes | Where-Object { $_ -lt 0 }).Count -gt 0) { continue }

  for ($j = $i + 2; $j -lt $lines.Count; $j++) {
    if (-not $lines[$j].Trim().StartsWith("|")) { break }
    $cells = @(Split-MarkdownRow $lines[$j])
    $lineId = Get-Cell -Cells $cells -Index $indexes.LineId
    $taskId = Get-Cell -Cells $cells -Index $indexes.TaskId
    if ($lineId -notmatch '(?i)^LINE\d{2,}$' -or $taskId -notmatch '(?i)^VT\d{2,}$') { continue }
    $rows += [pscustomobject]@{
      LineId = $lineId.ToUpperInvariant()
      TaskId = $taskId.ToUpperInvariant()
      Owner = (Get-Cell -Cells $cells -Index $indexes.Owner).ToUpperInvariant()
      Mode = (Get-Cell -Cells $cells -Index $indexes.Mode).ToLowerInvariant()
      Takeover = (Get-Cell -Cells $cells -Index $indexes.Takeover).ToLowerInvariant()
      Provenance = (Get-Cell -Cells $cells -Index $indexes.Provenance).ToLowerInvariant()
      Purpose = (Get-Cell -Cells $cells -Index $indexes.Purpose).ToLowerInvariant()
      Handoff = (Get-Cell -Cells $cells -Index $indexes.Handoff).ToLowerInvariant()
      Return = (Get-Cell -Cells $cells -Index $indexes.Return).ToLowerInvariant()
      Evidence = Get-Cell -Cells $cells -Index $indexes.Evidence
      Material = Get-Cell -Cells $cells -Index $indexes.Material
      Motion = Get-Cell -Cells $cells -Index $indexes.Motion
    }
  }
}

if ($rows.Count -eq 0) {
  $requiredMessage = "Line ID, Task ID, Owner, Purpose, Handoff reason, Return to person, Evidence source, Material, Motion action"
  if ($mixedMediaDeclared) { $requiredMessage += ", Presentation mode, Takeover, Provenance" }
  throw "screen-owner-v1 is declared but no complete owner rows were parsed. Required columns: $requiredMessage."
}

$purposeByOwner = @{
  PERSON = 'continue-listening'
  EVIDENCE = 'belief'
  EXPLAINER = 'understanding'
  SCENE = 'reality'
}
$reasonsByOwner = @{
  PERSON = @('opening','chapter-open','question','reversal','judgment','emotion-lift','conclusion','return-after-proof','return-after-explainer','return-after-scene','complex-reset')
  EVIDENCE = @('official-proof','number','quote','demo')
  EXPLAINER = @('mechanism','causal-chain','abstract-concept')
  SCENE = @('workflow','production','enterprise-use','real-action')
}
$issues = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$allowedModes = @('avatar-talk','live-presenter','official-proof','product-demo','real-footage','kinetic-image','aigc-scene','explainer-animation','support-card')
$allowedTakeovers = @('full','dominant','bridge')
$allowedProvenance = @('first-party','real-world','generated','internal-animation','n/a')

foreach ($row in $rows) {
  if (-not $purposeByOwner.ContainsKey($row.Owner)) {
    $issues.Add("$($row.LineId) has invalid Owner '$($row.Owner)'")
    continue
  }
  if ($row.Purpose -ne $purposeByOwner[$row.Owner]) {
    $issues.Add("$($row.LineId) Owner $($row.Owner) requires Purpose '$($purposeByOwner[$row.Owner])', got '$($row.Purpose)'")
  }
  $standardReason = $reasonsByOwner[$row.Owner] -contains $row.Handoff
  $customReason = $row.Handoff -match '^custom:[a-z0-9][a-z0-9-]{1,48}$'
  if (-not $standardReason -and -not $customReason) {
    $issues.Add("$($row.LineId) Handoff reason '$($row.Handoff)' is incompatible with Owner $($row.Owner)")
  }
  if (@('required','recommended','no') -notcontains $row.Return) {
    $issues.Add("$($row.LineId) Return to person must be required, recommended, or no")
  }
  if ([string]::IsNullOrWhiteSpace($row.Motion)) {
    $issues.Add("$($row.LineId) is missing Motion action")
  }
  if ($row.Owner -eq 'EVIDENCE' -and ($row.Evidence -match '(?i)^(|n/?a|none|not-applicable|todo|tbd)$')) {
    $issues.Add("$($row.LineId) EVIDENCE owner requires a real Evidence source")
  }

  if ($mixedMediaDeclared) {
    if ($allowedModes -notcontains $row.Mode) {
      $issues.Add("$($row.LineId) has invalid Presentation mode '$($row.Mode)'")
      continue
    }
    if ($allowedTakeovers -notcontains $row.Takeover) {
      $issues.Add("$($row.LineId) has invalid Takeover '$($row.Takeover)'")
    }
    if ($allowedProvenance -notcontains $row.Provenance) {
      $issues.Add("$($row.LineId) has invalid Provenance '$($row.Provenance)'")
    }

    $modesByOwner = @{
      PERSON = @('avatar-talk','live-presenter')
      EVIDENCE = @('official-proof','product-demo')
      EXPLAINER = @('product-demo','kinetic-image','aigc-scene','explainer-animation','support-card')
      SCENE = @('real-footage','kinetic-image','aigc-scene','support-card')
    }
    if ($modesByOwner[$row.Owner] -notcontains $row.Mode) {
      $issues.Add("$($row.LineId) Presentation mode '$($row.Mode)' is incompatible with Owner $($row.Owner)")
    }
    if ($row.Mode -eq 'support-card' -and $row.Takeover -ne 'bridge') {
      $issues.Add("$($row.LineId) support-card must use Takeover 'bridge'")
    }
    if ($row.Mode -ne 'support-card' -and $row.Takeover -eq 'bridge') {
      $issues.Add("$($row.LineId) primary mode '$($row.Mode)' cannot be reduced to bridge takeover")
    }
    if ($row.Mode -eq 'aigc-scene' -and $row.Provenance -ne 'generated') {
      $issues.Add("$($row.LineId) aigc-scene requires Provenance 'generated'")
    }
    if ($row.Mode -eq 'real-footage' -and $row.Provenance -ne 'real-world') {
      $issues.Add("$($row.LineId) real-footage requires Provenance 'real-world'")
    }
    if ($row.Mode -in @('official-proof','product-demo') -and $row.Provenance -notin @('first-party','real-world')) {
      $issues.Add("$($row.LineId) $($row.Mode) requires first-party or real-world provenance")
    }
    if ($row.Mode -eq 'explainer-animation' -and $row.Provenance -notin @('internal-animation','generated')) {
      $issues.Add("$($row.LineId) explainer-animation requires internal-animation or generated provenance")
    }
    if ($row.Owner -eq 'EVIDENCE' -and $row.Provenance -eq 'generated') {
      $issues.Add("$($row.LineId) generated material cannot serve as EVIDENCE")
    }
    if ($row.Owner -eq 'PERSON') {
      $staticAvatar = $row.Material -match '(?i)\.(png|jpe?g|webp|gif)(?:\b|$)|\b(static|still|portrait|photo|master[- ]?image)\b'
      $movingAvatar = $row.Material -match '(?i)\.(mp4|mov|webm)(?:\b|$)|\b(talking[- ]?video|accepted[- ]?avatar|latentsync|heygen)\b'
      if ($staticAvatar -or -not $movingAvatar) {
        $issues.Add("$($row.LineId) PERSON must name a verified talking video; static or unspecified avatar material does not count")
      }
    }
  }
}

$taskGroups = @($rows | Group-Object TaskId)
foreach ($group in $taskGroups) {
  $owners = @($group.Group | ForEach-Object { $_.Owner } | Sort-Object -Unique)
  if ($owners.Count -gt 1) {
    $issues.Add("Shared task $($group.Name) has conflicting owners: $($owners -join ', ')")
  }
}

$beats = New-Object System.Collections.Generic.List[object]
$seenTasks = @{}
foreach ($row in $rows) {
  if (-not $seenTasks.ContainsKey($row.TaskId)) {
    $seenTasks[$row.TaskId] = $true
    $beats.Add($row)
  }
}

for ($i = 0; $i -lt $beats.Count; $i++) {
  $beat = $beats[$i]
  if ($beat.Return -eq 'required') {
    if ($i + 1 -ge $beats.Count -or $beats[$i + 1].Owner -ne 'PERSON') {
      $issues.Add("$($beat.TaskId) requires the next distinct beat to return to PERSON")
    }
  }
  elseif ($beat.Return -eq 'recommended') {
    $lookahead = @()
    if ($i + 1 -lt $beats.Count) { $lookahead += $beats[$i + 1] }
    if ($i + 2 -lt $beats.Count) { $lookahead += $beats[$i + 2] }
    if (@($lookahead | Where-Object { $_.Owner -eq 'PERSON' }).Count -eq 0) {
      $warnings.Add("$($beat.TaskId) recommends a PERSON return, but neither of the next two distinct beats returns to PERSON")
    }
  }
}

$personIndexes = @()
for ($i = 0; $i -lt $beats.Count; $i++) {
  if ($beats[$i].Owner -eq 'PERSON') { $personIndexes += $i }
}
if ($beats.Count -ge 4 -and $personIndexes.Count -eq 1 -and $personIndexes[0] -eq 0 -and @($beats | Where-Object { $_.Owner -in @('EVIDENCE','EXPLAINER') }).Count -ge 3) {
  if ($mixedMediaDeclared) {
    $issues.Add("PERSON owns only the opening; presenter-led mixed-media requires a meaningful narrative re-anchor after complex material")
  } else {
    $warnings.Add("PERSON owns only the opening; the remaining complex proof/explanation run has no narrative re-anchor")
  }
}

$complexRun = 0
$sameOwnerRun = 0
$lastOwner = ''
$cardRun = 0
$supportCardRun = 0
foreach ($beat in $beats) {
  if ($beat.Owner -in @('EVIDENCE','EXPLAINER')) { $complexRun++ } else { $complexRun = 0 }
  if ($complexRun -eq 3) {
    $warnings.Add("Three or more consecutive EVIDENCE/EXPLAINER beats appear without a PERSON or SCENE reset near $($beat.TaskId)")
  }

  if ($beat.Owner -eq $lastOwner -and $beat.Owner -ne 'PERSON') { $sameOwnerRun++ } else { $sameOwnerRun = 1 }
  $lastOwner = $beat.Owner
  if ($sameOwnerRun -eq 4) {
    $warnings.Add("Four or more consecutive beats keep the same non-PERSON owner $($beat.Owner) near $($beat.TaskId)")
  }

  # Keep executable regexes ASCII-only so Windows PowerShell 5.1 does not corrupt
  # UTF-8 source without a BOM when this script is launched as a child process.
  $cardLike = ($beat.Material + ' ' + $beat.Motion) -match '(?i)(knowledge-card|info-card|card-led|image-card|board|slide|ppt)'
  if ($beat.Owner -ne 'PERSON' -and $cardLike) { $cardRun++ } else { $cardRun = 0 }
  if ($cardRun -eq 3) {
    $warnings.Add("Three or more consecutive card/PPT-like beats appear without a PERSON or SCENE reset near $($beat.TaskId)")
  }

  if ($mixedMediaDeclared -and $beat.Mode -eq 'support-card') { $supportCardRun++ } else { $supportCardRun = 0 }
  if ($mixedMediaDeclared -and $supportCardRun -eq 3) {
    $issues.Add("Three or more consecutive support-card beats form a PPT backbone near $($beat.TaskId)")
  }

  if ($beat.Owner -eq 'PERSON') {
    $layoutText = $beat.Material + ' ' + $beat.Motion
    $looksCorner = $layoutText -match '(?i)(pip|corner|small[- ]?window|side[- ]?by[- ]?side)'
    $looksPrimary = $layoutText -match '(?i)(full[- ]?screen|main[- ]?frame|primary|dominant|narrative[- ]?anchor)'
    if ($looksCorner -and -not $looksPrimary) {
      $warnings.Add("$($beat.TaskId) assigns PERSON but describes a corner/side-by-side treatment; verify that the person truly owns the frame")
    }
  }
}

if ($mixedMediaDeclared) {
  $nonPersonBeats = @($beats | Where-Object { $_.Owner -ne 'PERSON' })
  if ($nonPersonBeats.Count -gt 0 -and @($nonPersonBeats | Where-Object { $_.Mode -ne 'support-card' }).Count -eq 0) {
    $issues.Add("All non-PERSON beats use support-card; no proof, Demo, real footage, kinetic image, or explanatory scene takes over the screen")
  }
  $distinctPrimaryModes = @($beats | Where-Object { $_.Mode -ne 'support-card' } | ForEach-Object { $_.Mode } | Sort-Object -Unique)
  if ($beats.Count -ge 5 -and $distinctPrimaryModes.Count -lt 3) {
    $warnings.Add("Presenter-led mixed-media plan uses fewer than three distinct primary presentation modes; review material variety")
  }
}

if ($issues.Count -gt 0) {
  throw ("Screen-ownership QA failed:`n- " + ($issues -join "`n- "))
}

[ordered]@{
  status = 'PASS'
  contracts = @('screen-owner-v1') + $(if ($mixedMediaDeclared) { @('presenter-led-mixed-media-v1') } else { @() })
  beatCount = $beats.Count
  ownerCounts = [ordered]@{
    PERSON = @($beats | Where-Object { $_.Owner -eq 'PERSON' }).Count
    EVIDENCE = @($beats | Where-Object { $_.Owner -eq 'EVIDENCE' }).Count
    EXPLAINER = @($beats | Where-Object { $_.Owner -eq 'EXPLAINER' }).Count
    SCENE = @($beats | Where-Object { $_.Owner -eq 'SCENE' }).Count
  }
  mediaModeCounts = $(if ($mixedMediaDeclared) {
    [ordered]@{
      'avatar-talk' = @($beats | Where-Object { $_.Mode -eq 'avatar-talk' }).Count
      'live-presenter' = @($beats | Where-Object { $_.Mode -eq 'live-presenter' }).Count
      'official-proof' = @($beats | Where-Object { $_.Mode -eq 'official-proof' }).Count
      'product-demo' = @($beats | Where-Object { $_.Mode -eq 'product-demo' }).Count
      'real-footage' = @($beats | Where-Object { $_.Mode -eq 'real-footage' }).Count
      'kinetic-image' = @($beats | Where-Object { $_.Mode -eq 'kinetic-image' }).Count
      'aigc-scene' = @($beats | Where-Object { $_.Mode -eq 'aigc-scene' }).Count
      'explainer-animation' = @($beats | Where-Object { $_.Mode -eq 'explainer-animation' }).Count
      'support-card' = @($beats | Where-Object { $_.Mode -eq 'support-card' }).Count
    }
  } else { $null })
  warnings = @($warnings | Select-Object -Unique)
} | ConvertTo-Json -Depth 5
