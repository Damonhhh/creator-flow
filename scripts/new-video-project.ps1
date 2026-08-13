param(
  [Parameter(Mandatory = $true)]
  [string]$Name,

  [Parameter(Mandatory = $true)]
  [string]$Destination,

  [string]$Template = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Template)) {
  $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
  $packageTemplate = Join-Path $repoRoot "examples\minimal-video-project"
  $sourceTemplate = Join-Path $repoRoot "open-source\examples\minimal-video-project"
  $Template = if (Test-Path -LiteralPath $packageTemplate -PathType Container) { $packageTemplate } else { $sourceTemplate }
}

if ([string]::IsNullOrWhiteSpace($Name) -or $Name -in @(".", "..") -or [System.IO.Path]::IsPathRooted($Name) -or $Name.IndexOfAny([char[]]@('\', '/')) -ge 0) {
  throw "Name must be one project-folder name without path separators. Actual: $Name"
}

$templateRoot = (Resolve-Path -LiteralPath $Template -ErrorAction Stop).Path
$requiredTemplateFiles = [ordered]@{
  "README.md" = "README.md"
  "account-profile.example.md" = "account-profile.md"
  "writing-style.example.md" = "writing-style.md"
  "knowledge-sources.example.md" = "knowledge-sources.md"
  "source-content.md" = "source-content.md"
  "project-state.json" = "project-state.json"
  "draft\visual-plan\material-beat-map.md" = "draft\visual-plan\material-beat-map.md"
  "draft\web-assets\source-candidates.md" = "draft\web-assets\source-candidates.md"
}

foreach ($relativePath in $requiredTemplateFiles.Keys) {
  $sourcePath = Join-Path $templateRoot $relativePath
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Template is incomplete. Missing: $sourcePath"
  }
}

if (-not (Test-Path -LiteralPath $Destination)) {
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}
$destinationRoot = (Resolve-Path -LiteralPath $Destination -ErrorAction Stop).Path
$projectRoot = Join-Path $destinationRoot $Name
if (Test-Path -LiteralPath $projectRoot) {
  throw "Project already exists; refusing to overwrite: $projectRoot"
}

New-Item -ItemType Directory -Path $projectRoot | Out-Null
foreach ($directory in @("draft\visual-plan", "draft\web-assets", "assets", "review", "publish")) {
  New-Item -ItemType Directory -Path (Join-Path $projectRoot $directory) -Force | Out-Null
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
foreach ($entry in $requiredTemplateFiles.GetEnumerator()) {
  $sourcePath = Join-Path $templateRoot $entry.Key
  $targetPath = Join-Path $projectRoot $entry.Value
  $content = [System.IO.File]::ReadAllText($sourcePath)
  if ($entry.Key -eq "project-state.json") {
    $content = $content.Replace("__PROJECT_NAME__", $Name)
    $content = $content.Replace("__PROJECT_PATH__", ($projectRoot -replace '\\', '\\'))
    $content = $content.Replace("__CREATED_AT__", (Get-Date).ToString("o"))
  }
  [System.IO.File]::WriteAllText($targetPath, $content, $utf8NoBom)
}

[ordered]@{
  success = $true
  projectRoot = $projectRoot
  state = "topic_ready"
  nextStep = "Fill account-profile.md, writing-style.md, and knowledge-sources.md; confirm source-content.md, then enter the Script TTS stage."
} | ConvertTo-Json -Depth 4
