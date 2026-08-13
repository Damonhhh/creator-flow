param(
  [Parameter(Mandatory = $true)]
  [string]$VideoDir,

  [string]$Collection = "",

  [string[]]$Platforms = @(),

  [string]$PublishConfigPath = "",

  [string]$OutputRoot = "",

  [string]$FinalVideo = "",

  [switch]$RunQa,

  [switch]$Force,

  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "lib\resolve-zimeiti-config.ps1")

$publishConfig = Get-ZimeitiConfig -RepoRoot $ProjectRoot -Name "publish" -ConfigPath $PublishConfigPath
if (-not $OutputRoot) {
  $OutputRoot = [string]$publishConfig.outputRoot
}
if (-not $OutputRoot) {
  throw "Missing required config key: outputRoot. See config/publish.example.json"
}
$OutputRoot = Resolve-ZimeitiConfigPath -RepoRoot $ProjectRoot -Value $OutputRoot
if (-not $Collection -and $publishConfig.collection) {
  $Collection = [string]$publishConfig.collection
}
if ($Platforms.Count -eq 0 -and $publishConfig.platforms) {
  $Platforms = @($publishConfig.platforms | ForEach-Object { [string]$_ })
}

$publishCopyConfig = $publishConfig.publishCopyPass
if (-not $publishCopyConfig) {
  throw "Missing required config key: publishCopyPass. See config/publish.example.json"
}
$publishCopyRecordPattern = [string]$publishCopyConfig.recordPattern
$publishCopyRequiredMarkers = @($publishCopyConfig.requiredMarkers | ForEach-Object { [string]$_ })
if (-not $publishCopyRecordPattern) {
  throw "Missing required config key: publishCopyPass.recordPattern. See config/publish.example.json"
}
if ($publishCopyRequiredMarkers.Count -eq 0) {
  throw "Missing required config key: publishCopyPass.requiredMarkers. See config/publish.example.json"
}

function Resolve-ExistingPath {
  param([string]$PathValue)
  if (-not $PathValue) { return $null }
  $expanded = [Environment]::ExpandEnvironmentVariables($PathValue.Trim().Trim('"', "'", '`'))
  if (Test-Path -LiteralPath $expanded) {
    return (Resolve-Path -LiteralPath $expanded).Path
  }
  return $null
}

function Get-FirstExistingFile {
  param([string[]]$Candidates)
  foreach ($candidate in $Candidates) {
    $resolved = Resolve-ExistingPath $candidate
    if ($resolved -and (Get-Item -LiteralPath $resolved).PSIsContainer -eq $false) {
      return $resolved
    }
  }
  return $null
}

function Get-LatestFile {
  param(
    [string]$Root,
    [string[]]$Patterns
  )
  $files = @()
  foreach ($pattern in $Patterns) {
    $files += @(Get-ChildItem -LiteralPath $Root -Filter $pattern -File -ErrorAction SilentlyContinue)
  }
  return @($files | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
}

function Get-Sha256 {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-VideoProbe {
  param([string]$Path)
  $lines = & ffprobe -v error -select_streams v:0 -show_entries stream=width,height,avg_frame_rate -show_entries format=duration,size -of default=noprint_wrappers=1:nokey=0 $Path
  if ($LASTEXITCODE -ne 0 -or -not $lines) {
    throw "ffprobe failed for $Path"
  }
  $map = @{}
  foreach ($line in $lines) {
    if ($line -match "^(?<k>[^=]+)=(?<v>.*)$") {
      $map[$Matches.k] = $Matches.v
    }
  }
  return [ordered]@{
    width = [int]$map["width"]
    height = [int]$map["height"]
    avg_frame_rate = $map["avg_frame_rate"]
    duration = [double]::Parse($map["duration"], [System.Globalization.CultureInfo]::InvariantCulture)
    size = [int64]$map["size"]
  }
}

function Get-ImageSize {
  param([string]$Path)
  Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
  $img = [System.Drawing.Image]::FromFile($Path)
  try {
    return [ordered]@{ width = $img.Width; height = $img.Height }
  }
  finally {
    $img.Dispose()
  }
}

function Copy-IfChanged {
  param(
    [string]$Source,
    [string]$Destination
  )
  $srcItem = Get-Item -LiteralPath $Source
  if (Test-Path -LiteralPath $Destination) {
    $srcResolved = (Resolve-Path -LiteralPath $Source).Path
    $destResolved = (Resolve-Path -LiteralPath $Destination).Path
    if ([string]::Equals($srcResolved, $destResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
      return "skip-same:$Destination"
    }
  }
  if ((Test-Path -LiteralPath $Destination) -and -not $Force) {
    $destItem = Get-Item -LiteralPath $Destination
    if ($destItem.Length -eq $srcItem.Length) {
      $srcHash = Get-Sha256 $Source
      $destHash = Get-Sha256 $Destination
      if ($srcHash -and $destHash -and $srcHash -eq $destHash) {
        return "skip:$Destination"
      }
    }
  }
  if ($DryRun) {
    return "dry-copy:$Source -> $Destination"
  }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
  Copy-Item -LiteralPath $Source -Destination $Destination -Force
  return "copy:$Destination"
}

function Read-JsonIfExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Infer-Collection {
  param(
    [string]$VideoRoot,
    [string]$ProjectName,
    [string]$ProvidedCollection
  )
  if ($ProvidedCollection) { return $ProvidedCollection }

  $existingManifest = Join-Path $VideoRoot "publish\sync-manifest.json"
  $manifest = Read-JsonIfExists $existingManifest
  if ($manifest) {
    if ($manifest.PSObject.Properties.Name -contains "collection" -and $manifest.collection) {
      return [string]$manifest.collection
    }
    if ($manifest.PSObject.Properties.Name -contains "destinations") {
      $destinationValues = @()
      if ($manifest.destinations -is [array]) {
        $destinationValues = @($manifest.destinations)
      }
      else {
        foreach ($prop in $manifest.destinations.PSObject.Properties) {
          $destinationValues += [string]$prop.Value
        }
      }
      foreach ($dest in $destinationValues) {
        if ($dest -match "01-按合集\\(?<name>[^\\]+)\\") {
          return $Matches.name
        }
      }
    }
  }

  throw "Cannot infer collection for $ProjectName. Re-run with -Collection."
}

function Find-FinalVideo {
  param(
    [string]$VideoRoot,
    [string]$ProvidedFinalVideo
  )
  $provided = Resolve-ExistingPath $ProvidedFinalVideo
  if ($provided) { return $provided }

  $publish = Join-Path $VideoRoot "publish"
  $final = Join-Path $VideoRoot "final"
  $review = Join-Path $VideoRoot "review"

  $direct = Get-FirstExistingFile @(
    (Join-Path $publish "成片.mp4"),
    (Join-Path $publish "最终成片.mp4")
  )
  if ($direct) { return $direct }

  foreach ($root in @($publish, $final, $review)) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $latest = @(Get-LatestFile -Root $root -Patterns @("*final*.mp4", "成片*.mp4", "*.mp4"))
    if ($latest.Count -gt 0) { return $latest[0].FullName }
  }

  throw "Could not find final mp4. Re-run with -FinalVideo."
}

function Find-Subtitle {
  param([string]$VideoRoot)
  $publish = Join-Path $VideoRoot "publish"
  $direct = Get-FirstExistingFile @(
    (Join-Path $publish "字幕.srt"),
    (Join-Path $VideoRoot "hyperframes-app\assets\narration.srt"),
    (Join-Path $VideoRoot "hyperframes-app\assets\audio\narration.srt")
  )
  if ($direct) { return $direct }

  $voice = Join-Path $VideoRoot "assets\voice"
  if (Test-Path -LiteralPath $voice) {
    $latest = Get-ChildItem -LiteralPath $voice -Recurse -File -Include "*display.srt", "*realigned*.srt", "*.srt" -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTimeUtc -Descending |
      Select-Object -First 1
    if ($latest) { return $latest.FullName }
  }
  return $null
}

function Test-Subtitle {
  param([string]$Path)
  if (-not $Path) { return [ordered]@{ exists = $false; cueCount = 0; mojibakeLikeLines = 0; maxTextLength = 0 } }
  $lines = Get-Content -LiteralPath $Path -Encoding UTF8
  $cueCount = @($lines | Where-Object { $_ -match "^\d+$" }).Count
  $bad = @($lines | Where-Object { $_ -match "�|锟" }).Count
  $maxText = 0
  foreach ($line in $lines) {
    if ($line -match "^\d+$" -or $line -match "-->" -or -not $line.Trim()) { continue }
    if ($line.Length -gt $maxText) { $maxText = $line.Length }
  }
  if ($bad -gt 0) { throw "Subtitle has mojibake-like lines: $Path" }
  return [ordered]@{ exists = $true; cueCount = $cueCount; mojibakeLikeLines = $bad; maxTextLength = $maxText }
}

function Find-Cover {
  param(
    [string]$PublishDir,
    [ValidateSet("vertical", "horizontal")]
    [string]$Kind
  )
  if (-not (Test-Path -LiteralPath $PublishDir)) { return $null }
  $patterns = if ($Kind -eq "vertical") {
    @("*竖版*.png", "*竖版*.jpg", "*9x16*.png", "*vertical*.png")
  }
  else {
    @("*横版*.png", "*横版*.jpg", "*4x3*.png", "*horizontal*.png")
  }
  $files = @()
  foreach ($pattern in $patterns) {
    $files += @(Get-ChildItem -LiteralPath $PublishDir -Filter $pattern -File -ErrorAction SilentlyContinue | Where-Object {
      $_.Name -notmatch "thumbnail|thumb|预览|小图"
    })
  }
  return @($files | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
}

function Test-Covers {
  param([string]$PublishDir)
  $vertical = Find-Cover -PublishDir $PublishDir -Kind vertical
  $horizontal = Find-Cover -PublishDir $PublishDir -Kind horizontal
  if (-not $vertical) { throw "Missing vertical cover in publish/: 封面图-竖版*.png/jpg" }
  if (-not $horizontal) { throw "Missing horizontal cover in publish/: 封面图-横版*.png/jpg" }

  $vSize = Get-ImageSize $vertical.FullName
  $hSize = Get-ImageSize $horizontal.FullName
  if ($vSize.width -ne 1080 -or $vSize.height -ne 1920) {
    throw "Vertical cover must be 1080x1920. Actual: $($vSize.width)x$($vSize.height) $($vertical.FullName)"
  }
  $ratio = [double]$hSize.width / [double]$hSize.height
  if ([math]::Abs($ratio - (4.0 / 3.0)) -gt 0.03) {
    throw "Horizontal cover should be near 4:3. Actual: $($hSize.width)x$($hSize.height) $($horizontal.FullName)"
  }

  $defaultCover = Get-FirstExistingFile @(
    (Join-Path $PublishDir "封面图.png"),
    (Join-Path $PublishDir "封面图.jpg")
  )
  return [ordered]@{
    vertical = $vertical.FullName
    verticalSize = $vSize
    horizontal = $horizontal.FullName
    horizontalSize = $hSize
    default = $defaultCover
  }
}

function Test-PublishPackage {
  param([string]$PublishDir)
  $required = @(
    "标题.md",
    "正文.md",
    "封面文案.md",
    "封面图.md",
    "标签.md",
    "首评.md",
    "平台说明.md",
    "发布检查清单.md",
    "发布包.md"
  )
  $missing = @()
  foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $PublishDir $file))) {
      $missing += $file
    }
  }
  if ($missing.Count -gt 0) {
    throw "Publish package is incomplete. Missing: $($missing -join ', ')"
  }
}

function Test-PublishCopyPass {
  param(
    [string]$ReviewDir,
    [string]$RecordPattern,
    [string[]]$RequiredMarkers
  )
  if (-not (Test-Path -LiteralPath $ReviewDir)) {
    throw "Review directory missing; cannot verify publish-copy pass: $ReviewDir"
  }

  $records = @(Get-ChildItem -LiteralPath $ReviewDir -Filter $RecordPattern -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTimeUtc -Descending)
  if ($records.Count -eq 0) {
    throw "Missing publish-copy pass record matching: review\$RecordPattern"
  }

  $latest = $records[0]
  $text = Get-Content -LiteralPath $latest.FullName -Encoding UTF8 -Raw
  foreach ($marker in $RequiredMarkers) {
    if ($marker.EndsWith(":")) {
      $valuePattern = "(?im)^\s*" + [regex]::Escape($marker) + "\s*\S+"
      if ($text -notmatch $valuePattern) {
        throw "Publish-copy pass record is missing a non-empty marker: $marker"
      }
      continue
    }
    if ($text.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
      throw "Publish-copy pass record is missing required marker: $marker"
    }
  }

  return [ordered]@{
    path = $latest.FullName
    lastWriteTime = $latest.LastWriteTime.ToString("o")
  }
}

function Test-CoverVisualQaPass {
  param([string]$ReviewDir)
  if (-not (Test-Path -LiteralPath $ReviewDir)) {
    throw "Review directory missing; cannot verify cover visual QA: $ReviewDir"
  }

  $records = @(Get-ChildItem -LiteralPath $ReviewDir -Filter "cover-qa-v*.md" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTimeUtc -Descending)
  if ($records.Count -eq 0) {
    throw "Missing cover visual QA record: review\cover-qa-vNN.md"
  }

  $latest = $records[0]
  $text = Get-Content -LiteralPath $latest.FullName -Encoding UTF8 -Raw
  if ($text -match "(?im)^\s*(REJECTED|FAIL|FAILED|SUPERSEDED)\b") {
    throw "Latest cover visual QA is not passing: $($latest.FullName)"
  }
  if ($text -notmatch "(?im)\bPASS\b|通过") {
    throw "Cover visual QA record does not contain PASS: $($latest.FullName)"
  }
  if ($text -notmatch "zimeiti-cover-system-v1|Cover System|封面系统") {
    throw "Cover visual QA record does not name the cover system checks: $($latest.FullName)"
  }
  if ($text -notmatch "thumbnail|缩略图") {
    throw "Cover visual QA record does not mention thumbnail inspection: $($latest.FullName)"
  }
  if ($text -notmatch "opened|actual PNG|目检|打开|实际") {
    throw "Cover visual QA record does not prove actual image inspection: $($latest.FullName)"
  }

  return [ordered]@{
    path = $latest.FullName
    lastWriteTime = $latest.LastWriteTime.ToString("o")
  }
}

function Test-QaReport {
  param([string]$ReportPath)
  if (-not (Test-Path -LiteralPath $ReportPath)) {
    throw "QA report missing: $ReportPath"
  }
  $text = Get-Content -LiteralPath $ReportPath -Encoding UTF8 -Raw
  if ($text -notmatch "(?m)^-\s*PASS\s*$" -and $text -notmatch "QA：通过|草稿 QA：通过|QA passed") {
    throw "QA report does not contain PASS: $ReportPath"
  }
}

function Test-HumanVisualReviewPass {
  param(
    [string]$VideoRoot,
    [string]$VideoPath
  )

  $validator = Join-Path $ProjectRoot "scripts\test-video-human-visual-review.ps1"
  if (-not (Test-Path -LiteralPath $validator)) {
    throw "Missing human visual review validator: $validator"
  }

  $json = & $validator -VideoDir $VideoRoot -VideoPath $VideoPath
  if (-not $json) {
    throw "Human visual review validator returned no result: $validator"
  }
  return (@($json) -join "`n") | ConvertFrom-Json
}

function Write-Utf8Json {
  param(
    [object]$Object,
    [string]$Path
  )
  if ($DryRun) {
    Write-Host "dry-json:$Path"
    return
  }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
  $Object | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Write-Utf8Text {
  param(
    [string]$Text,
    [string]$Path
  )
  if ($DryRun) {
    Write-Host "dry-text:$Path"
    return
  }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
  $Text | Set-Content -LiteralPath $Path -Encoding UTF8
}

$resolvedVideoDir = Resolve-ExistingPath $VideoDir
if (-not $resolvedVideoDir) { throw "VideoDir not found: $VideoDir" }
$projectName = Split-Path -Leaf $resolvedVideoDir
$publishDir = Join-Path $resolvedVideoDir "publish"
$reviewDir = Join-Path $resolvedVideoDir "review"
New-Item -ItemType Directory -Force -Path $publishDir, $reviewDir | Out-Null

$finalVideoPath = Find-FinalVideo -VideoRoot $resolvedVideoDir -ProvidedFinalVideo $FinalVideo
$videoProbe = Get-VideoProbe $finalVideoPath
$videoHash = Get-Sha256 $finalVideoPath

$qaReport = Join-Path $reviewDir "draft-qa-report.md"
if ($RunQa) {
  $qaScript = Join-Path $ProjectRoot "scripts\run-video-draft-qa.ps1"
  if ($DryRun) {
    Write-Host "dry-run-qa:$qaScript -VideoDir $resolvedVideoDir"
  }
  else {
    & $qaScript -VideoDir $resolvedVideoDir
  }
}
if (-not (Test-Path -LiteralPath $qaReport)) {
  $qaReport = Get-FirstExistingFile @(
    (Join-Path $publishDir "draft-qa-report.md"),
    (Join-Path $publishDir "QA报告.md")
  )
}
Test-QaReport $qaReport
$humanVisualReview = Test-HumanVisualReviewPass -VideoRoot $resolvedVideoDir -VideoPath $finalVideoPath

$publishVideo = Join-Path $publishDir "成片.mp4"
Copy-IfChanged -Source $finalVideoPath -Destination $publishVideo | Write-Host
$publishQa = Join-Path $publishDir "draft-qa-report.md"
Copy-IfChanged -Source $qaReport -Destination $publishQa | Write-Host

$subtitlePath = Find-Subtitle -VideoRoot $resolvedVideoDir
$subtitleInfo = Test-Subtitle $subtitlePath
$publishSubtitle = $null
$subtitleHash = $null
if ($subtitlePath) {
  $publishSubtitle = Join-Path $publishDir "字幕.srt"
  Copy-IfChanged -Source $subtitlePath -Destination $publishSubtitle | Write-Host
  $subtitleHash = Get-Sha256 $publishSubtitle
}

$coverInfo = Test-Covers -PublishDir $publishDir
Test-PublishPackage -PublishDir $publishDir
$coverVisualQa = Test-CoverVisualQaPass -ReviewDir $reviewDir
$publishCopyPass = Test-PublishCopyPass `
  -ReviewDir $reviewDir `
  -RecordPattern $publishCopyRecordPattern `
  -RequiredMarkers $publishCopyRequiredMarkers

$collectionName = Infer-Collection -VideoRoot $resolvedVideoDir -ProjectName $projectName -ProvidedCollection $Collection
$destinations = [ordered]@{
  "待发布" = Join-Path (Join-Path $OutputRoot "03-待发布") $projectName
  "合集-$collectionName" = Join-Path (Join-Path (Join-Path $OutputRoot "01-按合集") $collectionName) $projectName
}
foreach ($platform in $Platforms) {
  $destinations["平台-$platform"] = Join-Path (Join-Path (Join-Path $OutputRoot "02-按平台") $platform) $projectName
}

$publishSyncExclusions = @(Get-ChildItem -LiteralPath $publishDir -File | Where-Object {
  $_.Name -match "^published-to-.*\.json$" -or
  (($_.Extension -ieq ".mp4") -and ($_.Name -ne "成片.mp4"))
})
$skippedItems = @(
  [ordered]@{ item = "auto_upload"; reason = "待人工发布，本次只做发布交接" }
)
foreach ($file in $publishSyncExclusions) {
  if ($file.Name -match "^published-to-.*\.json$") {
    continue
  }
  $skippedItems += [ordered]@{
    item = "publish_hygiene_extra_file:$($file.Name)"
    reason = "publish 顶层额外 MP4 / staging 文件不进入待发布同步；请保留规范成片 成片.mp4"
  }
}

$latestRender = [ordered]@{
  project = $projectName
  generatedAt = (Get-Date).ToString("o")
  finalVideo = $finalVideoPath
  publishVideo = $publishVideo
  sha256 = $videoHash
  probe = $videoProbe
}
Write-Utf8Json -Object $latestRender -Path (Join-Path $reviewDir "latest-render.json")

$qaStamp = [ordered]@{
  project = $projectName
  generatedAt = (Get-Date).ToString("o")
  status = "PASS"
  finalVideo = $finalVideoPath
  finalVideoSha256 = $videoHash
  qaReport = $qaReport
  publishQaReport = $publishQa
  humanVisualReview = $humanVisualReview.reviewPath
  humanVisualReviewSha256 = $humanVisualReview.reviewedVideoSha256
  subtitle = $publishSubtitle
  subtitleInfo = $subtitleInfo
}
Write-Utf8Json -Object $qaStamp -Path (Join-Path $reviewDir "qa-stamp.json")

$manifest = [ordered]@{
  project = $projectName
  status = "pending_manual_publish"
  generatedAt = (Get-Date).ToString("o")
  collection = $collectionName
  platforms = $Platforms
  finalVideo = $publishVideo
  sourceFinalVideo = $finalVideoPath
  subtitles = $publishSubtitle
  covers = [ordered]@{
    vertical = $coverInfo.vertical
    verticalSize = $coverInfo.verticalSize
    horizontal = $coverInfo.horizontal
    horizontalSize = $coverInfo.horizontalSize
    default = $coverInfo.default
  }
  publishPackage = Join-Path $publishDir "发布包.md"
  coverVisualQa = $coverVisualQa.path
  publishCopyPass = $publishCopyPass.path
  qaReport = $publishQa
  humanVisualReview = $humanVisualReview.reviewPath
  latestRender = Join-Path $reviewDir "latest-render.json"
  qaStamp = Join-Path $reviewDir "qa-stamp.json"
  destinations = $destinations
  hashes = [ordered]@{
    finalVideoSha256 = $videoHash
    subtitlesSha256 = $subtitleHash
    verticalCoverSha256 = Get-Sha256 $coverInfo.vertical
    horizontalCoverSha256 = Get-Sha256 $coverInfo.horizontal
  }
  skipped = $skippedItems
}
Write-Utf8Json -Object $manifest -Path (Join-Path $publishDir "publish-manifest.json")
Write-Utf8Json -Object $manifest -Path (Join-Path $publishDir "sync-manifest.json")

$statusLines = @(
  "# 收尾状态",
  "",
  "## 状态",
  "",
  "已完成发布交接，当前为待人工发布。",
  "",
  "## 最终资产",
  "",
  "- 最终成片：``$publishVideo``",
  "- 字幕：``$publishSubtitle``",
  "- 竖版封面：``$($coverInfo.vertical)``",
  "- 横版封面：``$($coverInfo.horizontal)``",
  "- 封面视觉 QA：``$($coverVisualQa.path)``",
  "- 发布包：``$(Join-Path $publishDir '发布包.md')``",
  "- 发布文案复核：``$($publishCopyPass.path)``",
  "- QA：``$publishQa``",
  "- 人工画面复核：``$($humanVisualReview.reviewPath)``",
  "",
  "## 验证",
  "",
  "- 成片：$($videoProbe.width)x$($videoProbe.height)，$($videoProbe.avg_frame_rate)，$([math]::Round($videoProbe.duration, 3))s。",
  "- QA：PASS。",
  "- 人工画面复核：PASS，且 SHA256 与当前成片一致。",
  "- 字幕：$($subtitleInfo.cueCount) 条 cue，乱码特征行 $($subtitleInfo.mojibakeLikeLines)。",
  "- 竖版封面：$($coverInfo.verticalSize.width)x$($coverInfo.verticalSize.height)。",
  "- 横版封面：$($coverInfo.horizontalSize.width)x$($coverInfo.horizontalSize.height)。",
  "- 封面视觉 QA：PASS。",
  "",
  "## 同步目录",
  ""
)
foreach ($entry in $destinations.GetEnumerator()) {
  $statusLines += "- $($entry.Key)：``$($entry.Value)``"
}
$statusLines += @(
  "",
  "## 跳过项",
  ""
)
foreach ($item in $skippedItems) {
  $statusLines += "- $($item.item)：$($item.reason)"
}
Write-Utf8Text -Text ($statusLines -join "`n") -Path (Join-Path $publishDir "收尾状态.md")

$publishFiles = @(Get-ChildItem -LiteralPath $publishDir -File | Where-Object {
  $_.Name -notmatch "^published-to-.*\.json$" -and
  -not (($_.Extension -ieq ".mp4") -and ($_.Name -ne "成片.mp4"))
})
foreach ($destination in $destinations.Values) {
  if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
  }
  foreach ($file in $publishFiles) {
    Copy-IfChanged -Source $file.FullName -Destination (Join-Path $destination $file.Name) | Write-Host
  }
}

if (-not $DryRun) {
  $stateScript = Join-Path $ProjectRoot "scripts\update-video-project-state.ps1"
  if (Test-Path -LiteralPath $stateScript) {
    & $stateScript `
      -VideoDir $resolvedVideoDir `
      -CurrentStage "Publish Wrap Up" `
      -StageStatus "pending_manual_publish" `
      -NextAction "Publish the synced package manually on the selected platforms." `
      -LatestRender $publishVideo `
      -AutomatedQa "PASS" `
      -AutomatedQaReport $publishQa `
      -HumanVisualReview $humanVisualReview.reviewPath `
      -Source "invoke-video-wrap-up.ps1" | Out-Null
  }
}

$result = [ordered]@{
  project = $projectName
  publishDir = $publishDir
  finalVideo = $publishVideo
  verticalCover = $coverInfo.vertical
  horizontalCover = $coverInfo.horizontal
  publishPackage = Join-Path $publishDir "发布包.md"
  publishCopyPass = $publishCopyPass.path
  humanVisualReview = $humanVisualReview.reviewPath
  waitingPublishDir = $destinations["待发布"]
  collection = $collectionName
  platforms = $Platforms
}

$result | ConvertTo-Json -Depth 6



