param(
  [Parameter(Mandatory = $true)]
  [string]$VideoDir,

  [Parameter(Mandatory = $true)]
  [string]$VideoPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$videoRoot = (Resolve-Path -LiteralPath $VideoDir -ErrorAction Stop).Path
$resolvedVideo = (Resolve-Path -LiteralPath $VideoPath -ErrorAction Stop).Path
$reviewDir = Join-Path $videoRoot "review"
if (-not (Test-Path -LiteralPath $reviewDir)) {
  throw "Review directory missing: $reviewDir"
}

$records = @(Get-ChildItem -LiteralPath $reviewDir -Filter "human-visual-review-v*.md" -File -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTimeUtc -Descending)
if ($records.Count -eq 0) {
  throw "Missing human visual review: review\human-visual-review-vNN.md"
}

$latest = $records[0]
$text = Get-Content -LiteralPath $latest.FullName -Raw -Encoding UTF8
if ($text -match "(?im)^\s*(?:status|review result)\s*:\s*(?:\*\*)?(?:REJECTED|FAIL|FAILED|SUPERSEDED)\b") {
  throw "Latest human visual review is not passing: $($latest.FullName)"
}
if ($text -notmatch "(?im)^\s*(?:status|review result)\s*:\s*(?:\*\*)?PASS\b") {
  throw "Human visual review must contain an explicit 'Status: PASS': $($latest.FullName)"
}

$videoHash = (Get-FileHash -LiteralPath $resolvedVideo -Algorithm SHA256).Hash
if ($text -notmatch [regex]::Escape($videoHash)) {
  throw "Human visual review is stale or belongs to another render. Expected SHA256 $videoHash in $($latest.FullName)"
}

$requiredChecks = @(
  "First visible frame",
  "Subtitle readability",
  "Evidence readability",
  "Visual-task coverage",
  "Blank media slots",
  "Transition artifacts",
  "Static-card duration",
  "Audio review",
  "Closing beat"
)
foreach ($check in $requiredChecks) {
  if ($text -notmatch [regex]::Escape($check)) {
    throw "Human visual review is missing required check '$check': $($latest.FullName)"
  }
}

if ($text -notmatch "(?i)\.(png|jpe?g)\b") {
  throw "Human visual review must cite opened frame or contact-sheet image evidence: $($latest.FullName)"
}
if ($text -notmatch "(?i)opened|inspected|目检|打开|查看") {
  throw "Human visual review must state that the cited image evidence was actually inspected: $($latest.FullName)"
}

[ordered]@{
  status = "PASS"
  reviewPath = $latest.FullName
  reviewedVideo = $resolvedVideo
  reviewedVideoSha256 = $videoHash
  reviewedAt = $latest.LastWriteTime.ToString("o")
} | ConvertTo-Json -Depth 4
