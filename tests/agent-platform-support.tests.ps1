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
foreach ($needle in @('Codex', 'TRAE Work', 'Code Mode', 'docs/installation.md')) {
  Assert-True ($readme.Contains($needle)) "README does not expose agent platform support: $needle"
}

$installation = Read-RepoText -RelativePath 'docs/installation.md'
$normalizedInstallation = $installation.Replace('\', '/')
foreach ($needle in @(
    'TRAE Work',
    'Code Mode',
    'Settings',
    'Rule & Skills',
    'Skills',
    'Create',
    '.agents/skills/zimeiti-video-workflow/SKILL.md',
    '.agents/skills/zimeiti-video-wrap-up/SKILL.md',
    'https://www.trae.ai/blog/trae_tutorial_0115',
    '-AcceptDownload'
  )) {
  Assert-True ($normalizedInstallation.Contains($needle)) "Installation guide is missing TRAE Work guidance: $needle"
}

foreach ($skillPath in @(
    '.agents/skills/zimeiti-video-workflow/SKILL.md',
    '.agents/skills/zimeiti-video-wrap-up/SKILL.md'
  )) {
  $skill = Read-RepoText -RelativePath $skillPath
  Assert-True ($skill -match '(?ms)\A---\s*\r?\nname:\s*[^\r\n]+\r?\ndescription:\s*[^\r\n]+\r?\n---') "Skill does not use portable Agent Skills frontmatter: $skillPath"
}

Assert-True (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.trae') -PathType Container)) 'Do not fork CreatorFlow into a second TRAE-specific skill tree'

Write-Host 'agent platform support tests passed'
