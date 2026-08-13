Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$decisionScript = Join-Path $repoRoot "scripts\run-mainline-topic-decision.ps1"
$chainScript = Join-Path $repoRoot "scripts\run-ai-daily-topic-chain.ps1"
$sourceExampleRoot = Join-Path $repoRoot "open-source\examples\ai-mainline-topic"
$exampleRoot = if (Test-Path -LiteralPath $sourceExampleRoot -PathType Container) {
  $sourceExampleRoot
} else {
  Join-Path $repoRoot "examples\ai-mainline-topic"
}
$inputPath = Join-Path $exampleRoot "candidates.example.json"
$rubricPath = Join-Path $exampleRoot "rubric.example.json"

function Assert-True {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zimeiti-public-topic-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
  $preflight = & $decisionScript `
    -WorkspaceRoot $repoRoot `
    -InputPath $inputPath `
    -RubricPath $rubricPath `
    -OutputRoot $tempRoot `
    -Preflight

  Assert-True $preflight.Success "Expected offline topic preflight to succeed"
  Assert-True ($preflight.CandidateCount -eq 5) "Expected exactly five fixed example candidates"

  $result = & $chainScript `
    -WorkspaceRoot $repoRoot `
    -InputPath $inputPath `
    -RubricPath $rubricPath `
    -OutputRoot $tempRoot

  Assert-True $result.Success "Expected offline topic chain to succeed"
  Assert-True ($result.RankedCandidates.Count -eq 5) "Expected all candidates in the ranking"
  Assert-True ($result.SelectedTopic.title -eq "AI meeting notes with a human acceptance gate") "Expected the highest-scoring topic to win"
  Assert-True ([double]$result.SelectedTopic.totalScore -eq 90.0) "Expected deterministic selected-topic score"
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$result.SelectedTopic.scoreExplanation)) "Expected a score explanation"
  Assert-True (Test-Path -LiteralPath $result.RankingPath) "Expected ranking JSON to be written"
  Assert-True (Test-Path -LiteralPath $result.DecisionPath) "Expected decision Markdown to be written"

  $ranking = Get-Content -LiteralPath $result.RankingPath -Raw | ConvertFrom-Json
  Assert-True ($ranking.rankedCandidates[0].title -eq $result.SelectedTopic.title) "Expected ranking file and result to agree"
  Assert-True ($ranking.rankedCandidates[0].totalScore -gt $ranking.rankedCandidates[1].totalScore) "Expected descending score order"

  $losers = @($ranking.rankedCandidates | Select-Object -Skip 1)
  $missingRejectionReasons = @($losers | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.rejectionReason) })
  Assert-True ($missingRejectionReasons.Count -eq 0) "Expected every rejected topic to include a reason"

  Write-Host "ai-mainline-public-example tests passed"
} finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
