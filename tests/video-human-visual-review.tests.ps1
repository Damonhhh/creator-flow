Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$validator = Join-Path $repoRoot "scripts\test-video-human-visual-review.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zimeiti-human-review-test-" + [guid]::NewGuid().ToString("N"))

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Assert-Throws {
  param([scriptblock]$Action, [string]$Message)
  $threw = $false
  try { & $Action | Out-Null } catch { $threw = $true }
  if (-not $threw) { throw $Message }
}

try {
  $reviewDir = Join-Path $tempRoot "review"
  New-Item -ItemType Directory -Force -Path $reviewDir | Out-Null
  $videoPath = Join-Path $tempRoot "candidate.mp4"
  [System.IO.File]::WriteAllBytes($videoPath, [byte[]](1, 2, 3, 4, 5))
  $hash = (Get-FileHash -LiteralPath $videoPath -Algorithm SHA256).Hash
  $reviewPath = Join-Path $reviewDir "human-visual-review-v01.md"

  $review = @(
    "# Human Visual Review",
    "Status: PASS",
    "Candidate SHA256: $hash",
    "- First visible frame: PASS",
    "- Subtitle readability: PASS",
    "- Evidence readability: PASS",
    "- Visual-task coverage: PASS",
    "- Blank media slots: PASS",
    "- Transition artifacts: PASS",
    "- Static-card duration: PASS",
    "- Audio review: PASS",
    "- Closing beat: PASS",
    "- Evidence files opened: review/contact-sheet.jpg"
  ) -join "`n"
  Set-Content -LiteralPath $reviewPath -Value $review -Encoding UTF8

  $result = & $validator -VideoDir $tempRoot -VideoPath $videoPath | ConvertFrom-Json
  Assert-True ($result.status -eq "PASS") "Expected matching human visual review to pass"
  Assert-True ($result.reviewedVideoSha256 -eq $hash) "Expected validator to bind review to candidate hash"

  Set-Content -LiteralPath $reviewPath -Value ($review.Replace($hash, ("0" * 64))) -Encoding UTF8
  Assert-Throws { & $validator -VideoDir $tempRoot -VideoPath $videoPath } "Expected stale hash to fail"

  Set-Content -LiteralPath $reviewPath -Value ($review.Replace("- Closing beat: PASS", "")) -Encoding UTF8
  Assert-Throws { & $validator -VideoDir $tempRoot -VideoPath $videoPath } "Expected missing required check to fail"

  Write-Host "video human visual review tests passed"
}
finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
