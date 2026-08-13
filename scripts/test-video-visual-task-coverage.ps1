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

$root = (Resolve-Path -LiteralPath $VideoDir -ErrorAction Stop).Path
$beatMapPath = Join-Path $root "draft\visual-plan\material-beat-map.md"
if (-not (Test-Path -LiteralPath $beatMapPath)) {
  throw "Missing material beat map: $beatMapPath"
}

$beatText = Get-Content -LiteralPath $beatMapPath -Raw -Encoding UTF8
if ($beatText -notmatch '(?i)visual-task-v1') {
  [ordered]@{ status = "not-applicable"; reason = "visual-task-v1 not declared" } | ConvertTo-Json
  exit 0
}

$lines = @($beatText -split "`r?`n")
$planned = @()
for ($i = 0; $i -lt ($lines.Count - 1); $i++) {
  if (-not $lines[$i].Trim().StartsWith("|")) { continue }
  if ($lines[$i + 1] -notmatch '^\s*\|?\s*:?-{3,}') { continue }
  $headers = @(Split-MarkdownRow $lines[$i])
  $lineIndex = Get-HeaderIndex -Headers $headers -Pattern '(?i)(line\s*id|sentence\s*id)'
  $taskIndex = Get-HeaderIndex -Headers $headers -Pattern '(?i)task\s*id'
  if ($lineIndex -lt 0 -or $taskIndex -lt 0) { continue }
  for ($j = $i + 2; $j -lt $lines.Count; $j++) {
    if (-not $lines[$j].Trim().StartsWith("|")) { break }
    $cells = @(Split-MarkdownRow $lines[$j])
    if ($cells.Count -le [math]::Max($lineIndex, $taskIndex)) { continue }
    if ($cells[$lineIndex] -match '(?i)^LINE\d{2,}$' -and $cells[$taskIndex] -match '(?i)^VT\d{2,}$') {
      $planned += [pscustomobject]@{
        LineId = $cells[$lineIndex].ToUpperInvariant()
        TaskId = $cells[$taskIndex].ToUpperInvariant()
      }
    }
  }
}

if ($planned.Count -eq 0) {
  throw "visual-task-v1 is declared but no LINE## -> VT## rows were parsed from $beatMapPath"
}

$manifestCandidates = @(
  (Join-Path $root "hyperframes-app\visual-task-coverage.json"),
  (Join-Path $root "remotion-app\visual-task-coverage.json"),
  (Join-Path $root "assembly\visual-task-coverage.json")
)
$manifestPath = @($manifestCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)
if ($manifestPath.Count -eq 0) {
  throw "Missing Assembly visual-task implementation manifest. Checked: $($manifestCandidates -join ', ')"
}
$manifestPath = $manifestPath[0]

try {
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
catch {
  throw "visual-task-coverage.json is invalid JSON: $manifestPath"
}

if ([string]$manifest.schemaVersion -ne "visual-task-coverage-v1") {
  throw "visual-task-coverage.json must declare schemaVersion visual-task-coverage-v1"
}

$tasks = @($manifest.tasks)
if ($tasks.Count -eq 0) {
  throw "visual-task-coverage.json has no task implementations"
}

$issues = New-Object System.Collections.Generic.List[string]
$duplicateManifestTasks = @($tasks | Group-Object { ([string]$_.taskId).ToUpperInvariant() } | Where-Object { $_.Name -and $_.Count -gt 1 })
if ($duplicateManifestTasks.Count -gt 0) {
  $issues.Add("Duplicate VT## entries in visual-task-coverage.json: $($duplicateManifestTasks.Name -join ', ')")
}

$plannedGroups = @($planned | Group-Object TaskId)
foreach ($group in $plannedGroups) {
  $taskId = $group.Name.ToUpperInvariant()
  $entry = @($tasks | Where-Object { ([string]$_.taskId).ToUpperInvariant() -eq $taskId } | Select-Object -First 1)
  if ($entry.Count -eq 0) {
    $issues.Add("Planned visual task $taskId is missing from visual-task-coverage.json")
    continue
  }

  $item = $entry[0]
  if ([string]$item.status -ne "implemented") {
    $issues.Add("Visual task $taskId must have status implemented")
  }
  if ([string]::IsNullOrWhiteSpace([string]$item.implementation)) {
    $issues.Add("Visual task $taskId is missing implementation description")
  }
  if ([string]::IsNullOrWhiteSpace([string]$item.ownerElement) -and [string]::IsNullOrWhiteSpace([string]$item.assetPath)) {
    $issues.Add("Visual task $taskId must name ownerElement or assetPath")
  }

  $start = 0.0
  $end = 0.0
  $hasStart = [double]::TryParse([string]$item.startSec, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$start)
  $hasEnd = [double]::TryParse([string]$item.endSec, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$end)
  if (-not $hasStart -or -not $hasEnd -or $end -le $start) {
    $issues.Add("Visual task $taskId must have numeric startSec/endSec with endSec > startSec")
  }

  $expectedLines = @($group.Group | ForEach-Object { $_.LineId } | Sort-Object -Unique)
  $actualLines = @($item.lineIds | ForEach-Object { ([string]$_).ToUpperInvariant() } | Sort-Object -Unique)
  $missingLines = @($expectedLines | Where-Object { $actualLines -notcontains $_ })
  if ($missingLines.Count -gt 0) {
    $issues.Add("Visual task $taskId is missing planned lines: $($missingLines -join ', ')")
  }
}

if ($issues.Count -gt 0) {
  throw ("Visual-task implementation QA failed:`n- " + ($issues -join "`n- "))
}

[ordered]@{
  status = "PASS"
  manifestPath = $manifestPath
  plannedTaskCount = $plannedGroups.Count
  implementedTaskCount = $tasks.Count
} | ConvertTo-Json -Depth 4
