Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Read-RepoText {
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  $path = Join-Path $repoRoot $RelativePath
  Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Missing file: $RelativePath"
  return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

$readme = Read-RepoText -RelativePath 'README.md'
foreach ($needle in @('Codex', 'TRAE Work', 'Claude Code', 'OpenClaw', 'Hermes', 'docs/installation.md')) {
  Assert-True ($readme.Contains($needle)) "README does not expose agent platform support: $needle"
}
Assert-True ($readme -match '(?m)^.*Codex.*TRAE Work.*Claude Code.*OpenClaw.*Hermes') 'README does not provide the compact supported-platform row'
foreach ($heading in @('### 交给 Codex', '### 交给 TRAE Work', '### 交给 Claude Code', '### 交给 OpenClaw', '### 交给 Hermes')) {
  Assert-True (-not $readme.Contains($heading)) "README should not duplicate installation guides by platform: $heading"
}

$installation = Read-RepoText -RelativePath 'docs/installation.md'
$normalizedInstallation = $installation.Replace('\', '/')
foreach ($needle in @(
    'Codex',
    'TRAE Work',
    'Claude Code',
    'OpenClaw',
    'Hermes',
    '.agents/skills/',
    'resolve-workflow-dependencies.ps1',
    '-AcceptAction'
  )) {
  Assert-True ($normalizedInstallation.Contains($needle)) "Installation guide is missing portable Agent guidance: $needle"
}

foreach ($skillPath in @(
    '.agents/skills/zimeiti-video-workflow/SKILL.md',
    '.agents/skills/zimeiti-video-wrap-up/SKILL.md'
  )) {
  $skill = Read-RepoText -RelativePath $skillPath
  Assert-True ($skill -match '(?ms)\A---\s*\r?\nname:\s*[^\r\n]+\r?\ndescription:\s*[^\r\n]+\r?\n---') "Skill does not use portable Agent Skills frontmatter: $skillPath"
}

$claudeAdapters = @(
  '.claude/skills/zimeiti-video-workflow/SKILL.md',
  '.claude/skills/zimeiti-video-wrap-up/SKILL.md'
)
foreach ($adapterPath in $claudeAdapters) {
  $adapter = Read-RepoText -RelativePath $adapterPath
  Assert-True ($adapter -match '(?ms)\A---\s*\r?\nname:\s*[^\r\n]+\r?\ndescription:\s*[^\r\n]+\r?\n---') "Claude adapter has invalid Agent Skills frontmatter: $adapterPath"
  Assert-True ($adapter.Contains('../../../.agents/skills/')) "Claude adapter does not point to the canonical skill tree: $adapterPath"
  Assert-True (@($adapter -split "`r?`n").Count -lt 25) "Claude adapter should remain thin: $adapterPath"
}

Assert-True (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.trae') -PathType Container)) 'Do not fork CreatorFlow into a second TRAE-specific skill tree'

Write-Host 'agent platform support tests passed'
