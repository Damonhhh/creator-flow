Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $repoRoot 'public-export-manifest.json'

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Get-PublicDocumentText {
  param([Parameter(Mandatory = $true)][string]$Destination)
  $entry = $manifest.files | Where-Object { [string]$_.destination -eq $Destination } | Select-Object -First 1
  Assert-True ($null -ne $entry) "Missing public document in manifest: $Destination"
  $path = Join-Path $repoRoot ([string]$entry.source)
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    $path = Join-Path $repoRoot ([string]$entry.destination)
  }
  Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Missing public document file: $Destination"
  return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$destinationSet = @{}
foreach ($entry in $manifest.files) {
  $destinationSet[([string]$entry.destination).Replace('\', '/')] = $true
}

$markdownEntries = @($manifest.files | Where-Object { [string]$_.destination -match '\.md$' })
$forbidden = @(
  'videos/WORKFLOW.md',
  'videos\WORKFLOW.md',
  'docs/video-production-memory.md',
  'docs\video-production-memory.md'
)

foreach ($entry in $markdownEntries) {
  $sourcePath = Join-Path $repoRoot ([string]$entry.source)
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    $sourcePath = Join-Path $repoRoot ([string]$entry.destination)
  }
  Assert-True (Test-Path -LiteralPath $sourcePath -PathType Leaf) "Missing Markdown source or exported destination: $($entry.source)"
  $text = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
  foreach ($needle in $forbidden) {
    Assert-True (-not $text.Contains($needle)) "Private or legacy reference '$needle' in $($entry.source)"
  }
  Assert-True ($text -notmatch '(?i)[a-z]:\\users\\[^\\/]+' ) "Absolute user profile path in $($entry.source)"
  Assert-True ($text -notmatch '(?i)[a-z]:\\ai\\' ) "Private workspace path in $($entry.source)"

  $destinationDir = Split-Path -Parent ([string]$entry.destination)
  foreach ($match in [regex]::Matches($text, '\[[^\]]+\]\(([^)]+)\)')) {
    $target = $match.Groups[1].Value.Trim().Split('#')[0]
    if (-not $target -or $target -match '^(https?://|mailto:)') { continue }
    $combined = if ($destinationDir) { Join-Path $destinationDir $target } else { $target }
    $normalized = [IO.Path]::GetFullPath((Join-Path $repoRoot $combined)).Substring($repoRoot.Length).TrimStart('\').Replace('\', '/')
    Assert-True $destinationSet.ContainsKey($normalized) "Unexported Markdown link '$target' in $($entry.destination)"
  }

  foreach ($referenceMatch in [regex]::Matches($text, '(?i)(?:\.agents[\\/]|scripts[\\/]|tests[\\/]|config[\\/]|docs[\\/]|examples[\\/])[a-z0-9_.<>-]+(?:[\\/][a-z0-9_.<>-]+)*\.(?:md|ps1|py|json|mjs)')) {
    $reference = $referenceMatch.Value.Replace('\', '/')
    if ($reference.Contains('<') -or $reference.Contains('>')) { continue }
    if ($reference -match '(?i)\.local\.json$') { continue }
    Assert-True $destinationSet.ContainsKey($reference) "Unexported repository reference '$reference' in $($entry.destination)"
  }
}

$stageEntries = @($manifest.files | Where-Object { [string]$_.destination -match '^\.agents/skills/zimeiti-video-workflow/references/stage-[^/]+\.md$' })
Assert-True ($stageEntries.Count -eq 6) 'Expected exactly six public workflow stages'
foreach ($entry in $stageEntries) {
  $stagePath = Join-Path $repoRoot ([string]$entry.source)
  if (-not (Test-Path -LiteralPath $stagePath -PathType Leaf)) {
    $stagePath = Join-Path $repoRoot ([string]$entry.destination)
  }
  $text = Get-Content -LiteralPath $stagePath -Raw -Encoding UTF8
  Assert-True ($text.Contains('failure-pattern-index.md')) "Stage must route through failure-pattern-index.md: $($entry.destination)"
}

$qaEntry = $stageEntries | Where-Object { [string]$_.destination -like '*stage-qa.md' } | Select-Object -First 1
Assert-True ($null -ne $qaEntry) 'Missing public QA stage'
$qaPath = Join-Path $repoRoot ([string]$qaEntry.source)
if (-not (Test-Path -LiteralPath $qaPath -PathType Leaf)) {
  $qaPath = Join-Path $repoRoot ([string]$qaEntry.destination)
}
$qaText = Get-Content -LiteralPath $qaPath -Raw -Encoding UTF8
Assert-True ($qaText -match 'human|by eye') 'QA stage must require human visual review'
Assert-True ($qaText -match 'SHA256') 'QA stage must bind review to render SHA256'

$readmeText = Get-PublicDocumentText -Destination 'README.md'
foreach ($needle in @(
    'CreatorFlow',
    'Codex',
    'topic-ranking.json',
    'project-state.json',
    'publish\',
    'examples/ai-mainline-topic/README.md',
    'examples/minimal-video-project/README.md',
    'account-profile.md',
    'writing-style.md',
    'knowledge-sources.md',
    'Script TTS',
    'Publish Wrap Up',
    'human-visual-review',
    'human-visual-review-vNN.md',
    'docs/installation.md'
  )) {
  Assert-True ($readmeText.Contains($needle)) "README product entry is missing: $needle"
}
Assert-True (-not $readmeText.Contains('one-click fully automated account machine')) 'README must not make the one-click automation claim'
Assert-True ($readmeText.Contains('-AcceptDownload')) 'README must explain consent-gated renderer setup'

$installationText = Get-PublicDocumentText -Destination 'docs/installation.md'
foreach ($needle in @(
    'test-workflow-capabilities.ps1',
    'workflow.local.json',
    'tts.local.json',
    'providers.local.json',
    'publish.local.json',
    'new-video-project.ps1',
    'initialize-video-renderer.ps1',
    'run-video-draft-qa.ps1',
    'invoke-video-wrap-up.ps1',
    'account-profile.md',
    'writing-style.md',
    'knowledge-sources.md',
    'Script TTS',
    'Publish Wrap Up',
    'human-visual-review',
    '-AcceptDownload'
  )) {
  Assert-True ($installationText.Contains($needle)) "Installation guide is missing: $needle"
}

$dependencyText = Get-PublicDocumentText -Destination 'docs/dependency-matrix.md'
foreach ($dependency in @('PowerShell', 'Python', 'FFmpeg', 'ffprobe', 'Node.js', 'npm', 'HyperFrames', 'IndexTTS2', 'ASR', 'Grok', 'MiniMax', 'Uploader')) {
  Assert-True ($dependencyText.Contains($dependency)) "Dependency matrix is missing: $dependency"
}
Assert-True (-not $dependencyText.Contains('https://api.apikey.fun/v1')) 'Public docs must not bake in a third-party API endpoint'

$troubleshootingText = Get-PublicDocumentText -Destination 'docs/troubleshooting.md'
foreach ($needle in @('Core', 'Full', '.local.json', 'ffmpeg', 'human review')) {
  Assert-True ($troubleshootingText.Contains($needle)) "Troubleshooting guide is missing: $needle"
}

Write-Host 'public doc link tests passed'
