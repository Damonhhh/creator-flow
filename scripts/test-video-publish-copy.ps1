param(
  [Parameter(Mandatory = $true)]
  [string]$VideoDir,

  [string]$ScorecardPattern = "publish-copy-scorecard-v*.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path (Join-Path $PSScriptRoot 'lib') 'creatorflow-platform.ps1')
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$videoRoot = (Resolve-Path -LiteralPath $VideoDir -ErrorAction Stop).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$planPath = Join-CreatorFlowPath -BasePath $videoRoot -RelativePath "draft/publish-copy/publish-copy-plan.json"
$reviewDir = Join-Path $videoRoot "review"
$publishDir = Join-Path $videoRoot "publish"
$latestRenderPath = Join-Path $reviewDir "latest-render.json"
$qaStampPath = Join-Path $reviewDir "qa-stamp.json"
$issues = [System.Collections.Generic.List[string]]::new()

function Add-Issue {
  param([string]$Message)
  $script:issues.Add($Message)
}

function Get-PropertyValue {
  param(
    [object]$Object,
    [string]$Name
  )
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Get-RequiredText {
  param(
    [object]$Object,
    [string]$Name,
    [string]$Label
  )
  $value = Get-PropertyValue -Object $Object -Name $Name
  if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
    Add-Issue "$Label must be a non-empty string"
    return ""
  }
  $text = ([string]$value).Trim()
  if ($text -match '(?i)\bTODO\b|\bTBC\b|待补|待填写|这里填写|\{\{.+\}\}') {
    Add-Issue "$Label still contains a placeholder"
  }
  return $text
}

function Get-RequiredSha256 {
  param(
    [object]$Object,
    [string]$Name,
    [string]$Label
  )
  $text = Get-RequiredText -Object $Object -Name $Name -Label $Label
  if (-not $text) { return "" }
  if ($text -notmatch '^[0-9a-fA-F]{64}$') {
    Add-Issue "$Label must be a 64-character SHA-256"
    return ""
  }
  return $text.ToUpperInvariant()
}

function Get-Sha256 {
  param([string]$Path)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Test-Sha256Match {
  param(
    [string]$Declared,
    [string]$Actual,
    [string]$Label
  )
  if ($Declared -and $Actual -and $Declared -cne $Actual) {
    Add-Issue "$Label does not match the actual file SHA-256"
  }
}

function Read-JsonFile {
  param(
    [string]$Path,
    [string]$Label
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Add-Issue "$Label is missing: $Path"
    return $null
  }
  try {
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
  }
  catch {
    Add-Issue "$Label is invalid JSON: $Path ($($_.Exception.Message))"
    return $null
  }
}

function Test-IsPathWithinRoot {
  param(
    [string]$Path,
    [string]$Root
  )
  $normalizedRoot = $Root.TrimEnd('\', '/')
  $prefix = $normalizedRoot + [System.IO.Path]::DirectorySeparatorChar
  $comparison = Get-CreatorFlowPathComparison
  return $Path.Equals($normalizedRoot, $comparison) -or
    $Path.StartsWith($prefix, $comparison)
}

function Resolve-AllowedFile {
  param(
    [string]$RelativeOrAbsolutePath,
    [string]$Label,
    [string[]]$AllowedRoots,
    [string]$BoundaryLabel
  )
  if ([string]::IsNullOrWhiteSpace($RelativeOrAbsolutePath)) {
    return $null
  }
  try {
    $candidate = if ([System.IO.Path]::IsPathRooted($RelativeOrAbsolutePath)) {
      [System.IO.Path]::GetFullPath($RelativeOrAbsolutePath)
    }
    else {
      [System.IO.Path]::GetFullPath((Join-Path $videoRoot $RelativeOrAbsolutePath))
    }
  }
  catch {
    Add-Issue "$Label is not a valid path: $RelativeOrAbsolutePath"
    return $null
  }

  $insideAllowedRoot = $false
  foreach ($allowedRoot in $AllowedRoots) {
    if (Test-IsPathWithinRoot -Path $candidate -Root $allowedRoot) {
      $insideAllowedRoot = $true
      break
    }
  }
  if (-not $insideAllowedRoot) {
    Add-Issue "$Label must stay inside $BoundaryLabel`: $RelativeOrAbsolutePath"
    return $null
  }
  if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
    Add-Issue "$Label does not exist: $candidate"
    return $null
  }
  return $candidate
}

function Get-Score {
  param(
    [object]$Scores,
    [string]$Name,
    [string]$Label,
    [double]$Minimum = 1
  )
  $value = Get-PropertyValue -Object $Scores -Name $Name
  if ($null -eq $value) {
    Add-Issue "$Label.$Name is missing"
    return $null
  }
  try {
    $number = [double]$value
  }
  catch {
    Add-Issue "$Label.$Name must be numeric"
    return $null
  }
  if ($number -lt $Minimum -or $number -gt 5) {
    Add-Issue "$Label.$Name must be between $Minimum and 5; actual: $number"
  }
  return $number
}

function Get-PrimaryMarkdownValue {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
  foreach ($rawLine in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
    $line = $rawLine.Trim()
    if (-not $line -or $line.StartsWith('#') -or $line.StartsWith('>')) { continue }
    if ($line -match '^(?:[-*]\s*)?\*{0,2}(?:推荐标题|主标题|标题)\*{0,2}\s*[:：]\s*(.+)$') {
      $line = $Matches[1].Trim()
    }
    elseif ($line -match '^(?:备选标题|短标题)\s*[:：]') {
      continue
    }
    else {
      $line = $line -replace '^(?:[-*]|\d+[.)、])\s*', ''
    }
    $line = $line.Trim().Trim('*', '_', '`')
    if ($line) { return $line }
  }
  return ""
}

function Get-MarkdownDocumentBody {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
  $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
  $firstContentIndex = -1
  for ($index = 0; $index -lt $lines.Count; $index++) {
    if (-not [string]::IsNullOrWhiteSpace($lines[$index])) {
      $firstContentIndex = $index
      break
    }
  }
  if ($firstContentIndex -lt 0) { return "" }
  if ($lines[$firstContentIndex].Trim().StartsWith('#')) {
    $firstContentIndex++
  }
  if ($firstContentIndex -ge $lines.Count) { return "" }
  return (($lines[$firstContentIndex..($lines.Count - 1)] -join "`n").Trim())
}

function Get-NormalizedText {
  param([string]$Text)
  if (-not $Text) { return "" }
  return ([regex]::Replace($Text.ToLowerInvariant(), '\s+', '')).Trim()
}

$requiredPublishFiles = @(
  "标题.md",
  "正文.md",
  "首评.md",
  "标签.md",
  "发布包.md"
)
$publishPaths = [ordered]@{}
foreach ($name in $requiredPublishFiles) {
  $path = Join-Path $publishDir $name
  $publishPaths[$name] = $path
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Issue "Final publish-copy file is missing: $path"
    continue
  }
  $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($text)) {
    Add-Issue "Final publish-copy file is empty: $path"
  }
  elseif ($text -match '(?i)\bTODO\b|\bTBC\b|待补|待填写|这里填写|\{\{.+\}\}') {
    Add-Issue "Final publish-copy file contains a placeholder: $path"
  }
}

$plan = Read-JsonFile -Path $planPath -Label "Publish-copy plan"
$selectedTitleId = ""
$selectedTitle = ""
$candidateCount = 0
$angleCount = 0
$resolvedSourceScriptPath = $null
$resolvedSourceRenderPath = $null
$actualScriptSha256 = ""
$actualRenderSha256 = ""
$planScriptSha256 = ""
$planRenderSha256 = ""

if ($null -ne $plan) {
  $schemaVersion = Get-RequiredText -Object $plan -Name "schemaVersion" -Label "plan.schemaVersion"
  if ($schemaVersion -and $schemaVersion -ne "publish-copy-plan-v1") {
    Add-Issue "plan.schemaVersion must be publish-copy-plan-v1; actual: $schemaVersion"
  }

  $source = Get-PropertyValue -Object $plan -Name "source"
  if ($null -eq $source) {
    Add-Issue "plan.source is missing"
  }
  else {
    $scriptSourceValue = Get-RequiredText -Object $source -Name "script" -Label "plan.source.script"
    if ($scriptSourceValue) {
      $resolvedSourceScriptPath = Resolve-AllowedFile -RelativeOrAbsolutePath $scriptSourceValue -Label "plan.source.script" -AllowedRoots @($videoRoot) -BoundaryLabel "the video project"
    }
    $renderSourceValue = Get-RequiredText -Object $source -Name "qaApprovedRender" -Label "plan.source.qaApprovedRender"
    if ($renderSourceValue) {
      $resolvedSourceRenderPath = Resolve-AllowedFile -RelativeOrAbsolutePath $renderSourceValue -Label "plan.source.qaApprovedRender" -AllowedRoots @($videoRoot) -BoundaryLabel "the video project"
    }

    $planScriptSha256 = Get-RequiredSha256 -Object $source -Name "scriptSha256" -Label "plan.source.scriptSha256"
    $planRenderSha256 = Get-RequiredSha256 -Object $source -Name "qaApprovedRenderSha256" -Label "plan.source.qaApprovedRenderSha256"
    if ($resolvedSourceScriptPath) {
      $actualScriptSha256 = Get-Sha256 -Path $resolvedSourceScriptPath
      Test-Sha256Match -Declared $planScriptSha256 -Actual $actualScriptSha256 -Label "plan.source.scriptSha256"
    }
    if ($resolvedSourceRenderPath) {
      $actualRenderSha256 = Get-Sha256 -Path $resolvedSourceRenderPath
      Test-Sha256Match -Declared $planRenderSha256 -Actual $actualRenderSha256 -Label "plan.source.qaApprovedRenderSha256"
    }
    foreach ($field in @("accountProfile", "writingStyle")) {
      $sourceValue = Get-RequiredText -Object $source -Name $field -Label "plan.source.$field"
      if ($sourceValue) {
        Resolve-AllowedFile -RelativeOrAbsolutePath $sourceValue -Label "plan.source.$field" -AllowedRoots @($videoRoot, $repoRoot) -BoundaryLabel "the video project or zimeiti repository" | Out-Null
      }
    }
  }

  $brief = Get-PropertyValue -Object $plan -Name "brief"
  if ($null -eq $brief) {
    Add-Issue "plan.brief is missing"
  }
  else {
    foreach ($field in @(
        "audience",
        "viewerMoment",
        "subject",
        "coreFact",
        "tension",
        "audienceStake",
        "promisedTakeaway",
        "payoffInVideo",
        "factualBoundary"
      )) {
      Get-RequiredText -Object $brief -Name $field -Label "plan.brief.$field" | Out-Null
    }
    $platforms = @((Get-PropertyValue -Object $brief -Name "platforms") | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($platforms.Count -eq 0) {
      Add-Issue "plan.brief.platforms must contain at least one platform"
    }
    $briefEvidence = @((Get-PropertyValue -Object $brief -Name "evidence") | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($briefEvidence.Count -eq 0) {
      Add-Issue "plan.brief.evidence must contain at least one source or payoff anchor"
    }
  }

  $candidates = @((Get-PropertyValue -Object $plan -Name "titleCandidates"))
  if ($candidates.Count -eq 1 -and $null -eq $candidates[0]) { $candidates = @() }
  $candidateCount = $candidates.Count
  if ($candidateCount -lt 8) {
    Add-Issue "plan.titleCandidates needs at least 8 candidates; actual: $candidateCount"
  }

  $candidateById = @{}
  $seenText = @{}
  $angles = @{}
  $candidateScores = @{}
  foreach ($candidate in $candidates) {
    $id = Get-RequiredText -Object $candidate -Name "id" -Label "title candidate id"
    $angle = Get-RequiredText -Object $candidate -Name "angle" -Label "title candidate $id angle"
    $textValue = Get-RequiredText -Object $candidate -Name "text" -Label "title candidate $id text"
    Get-RequiredText -Object $candidate -Name "promise" -Label "title candidate $id promise" | Out-Null
    Get-RequiredText -Object $candidate -Name "curiosityGap" -Label "title candidate $id curiosityGap" | Out-Null
    $evidence = @((Get-PropertyValue -Object $candidate -Name "evidence") | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($evidence.Count -eq 0) {
      Add-Issue "title candidate $id must cite at least one evidence or payoff anchor"
    }

    if ($id) {
      if ($candidateById.ContainsKey($id)) {
        Add-Issue "Duplicate title candidate id: $id"
      }
      else {
        $candidateById[$id] = $candidate
      }
    }
    if ($angle) { $angles[$angle.ToLowerInvariant()] = $true }
    $normalized = Get-NormalizedText -Text $textValue
    if ($normalized) {
      if ($seenText.ContainsKey($normalized)) {
        Add-Issue "Duplicate title candidate text: $textValue"
      }
      else {
        $seenText[$normalized] = $true
      }
    }

    $scores = Get-PropertyValue -Object $candidate -Name "scores"
    $scoreTotal = 0.0
    $scoreComplete = $true
    foreach ($scoreName in @("hook", "concreteness", "audienceStake", "curiosity", "factualFidelity", "payoffMatch")) {
      $score = Get-Score -Scores $scores -Name $scoreName -Label "title candidate $id scores"
      if ($null -eq $score) {
        $scoreComplete = $false
      }
      else {
        $scoreTotal += $score
      }
    }
    if ($id -and $scoreComplete) { $candidateScores[$id] = $scoreTotal }
  }
  $angleCount = $angles.Count
  if ($angleCount -lt 4) {
    Add-Issue "plan.titleCandidates needs at least 4 distinct angle families; actual: $angleCount"
  }

  $selection = Get-PropertyValue -Object $plan -Name "selection"
  if ($null -eq $selection) {
    Add-Issue "plan.selection is missing"
  }
  else {
    $selectedTitleId = Get-RequiredText -Object $selection -Name "selectedTitleId" -Label "plan.selection.selectedTitleId"
    Get-RequiredText -Object $selection -Name "reason" -Label "plan.selection.reason" | Out-Null
    $rejectedRisks = @((Get-PropertyValue -Object $selection -Name "rejectedRisks") | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($rejectedRisks.Count -eq 0) {
      Add-Issue "plan.selection.rejectedRisks must record at least one rejected title risk"
    }
  }

  if ($selectedTitleId) {
    if (-not $candidateById.ContainsKey($selectedTitleId)) {
      Add-Issue "Selected title id does not exist in titleCandidates: $selectedTitleId"
    }
    else {
      $selectedCandidate = $candidateById[$selectedTitleId]
      $selectedTitle = [string](Get-PropertyValue -Object $selectedCandidate -Name "text")
      if ($candidateScores.ContainsKey($selectedTitleId) -and [double]$candidateScores[$selectedTitleId] -lt 24) {
        Add-Issue "Selected title must score at least 24/30; actual: $($candidateScores[$selectedTitleId])"
      }
      $selectedScores = Get-PropertyValue -Object $selectedCandidate -Name "scores"
      foreach ($coreScore in @("factualFidelity", "payoffMatch")) {
        $value = Get-PropertyValue -Object $selectedScores -Name $coreScore
        if ($null -ne $value -and [double]$value -lt 4) {
          Add-Issue "Selected title $coreScore must be at least 4; actual: $value"
        }
      }
    }
  }

  $bodyPlan = Get-PropertyValue -Object $plan -Name "bodyPlan"
  if ($null -eq $bodyPlan) {
    Add-Issue "plan.bodyPlan is missing"
  }
  else {
    foreach ($field in @("openingJob", "concreteValue", "videoReason")) {
      Get-RequiredText -Object $bodyPlan -Name $field -Label "plan.bodyPlan.$field" | Out-Null
    }
  }

  $firstCommentPlan = Get-PropertyValue -Object $plan -Name "firstCommentPlan"
  $answerableQuestion = ""
  if ($null -eq $firstCommentPlan) {
    Add-Issue "plan.firstCommentPlan is missing"
  }
  else {
    Get-RequiredText -Object $firstCommentPlan -Name "addedValue" -Label "plan.firstCommentPlan.addedValue" | Out-Null
    $answerableQuestion = Get-RequiredText -Object $firstCommentPlan -Name "answerableQuestion" -Label "plan.firstCommentPlan.answerableQuestion"
  }

  $titlePath = [string]$publishPaths["标题.md"]
  $primaryTitle = Get-PrimaryMarkdownValue -Path $titlePath
  if (-not $primaryTitle) {
    Add-Issue "publish\标题.md has no readable primary title"
  }
  elseif ($selectedTitle -and $primaryTitle -cne $selectedTitle) {
    Add-Issue "The first visible title in publish\标题.md must exactly match selected title $selectedTitleId"
  }

  $firstCommentPath = [string]$publishPaths["首评.md"]
  if (Test-Path -LiteralPath $firstCommentPath -PathType Leaf) {
    $firstCommentText = Get-Content -LiteralPath $firstCommentPath -Raw -Encoding UTF8
    $normalizedComment = Get-NormalizedText -Text $firstCommentText
    $genericCommentPatterns = @("你怎么看", "大家怎么看", "你觉得呢", "欢迎评论", "评论区聊聊")
    foreach ($generic in $genericCommentPatterns) {
      if ($normalizedComment -eq (Get-NormalizedText -Text $generic)) {
        Add-Issue "publish\首评.md is only a generic engagement prompt: $generic"
      }
    }
    if ($answerableQuestion -and $firstCommentText.IndexOf($answerableQuestion, [System.StringComparison]::Ordinal) -lt 0) {
      Add-Issue "publish\首评.md must contain plan.firstCommentPlan.answerableQuestion exactly"
    }
  }

  $packagePath = [string]$publishPaths["发布包.md"]
  if (Test-Path -LiteralPath $packagePath -PathType Leaf) {
    $packageText = Get-Content -LiteralPath $packagePath -Raw -Encoding UTF8
    $normalizedPackage = Get-NormalizedText -Text $packageText
    if ($selectedTitle -and -not $normalizedPackage.Contains((Get-NormalizedText -Text $selectedTitle))) {
      Add-Issue "publish\发布包.md does not contain the selected title"
    }
    foreach ($copyFile in @("正文.md", "首评.md")) {
      $copyPath = [string]$publishPaths[$copyFile]
      $copyBody = Get-MarkdownDocumentBody -Path $copyPath
      if (-not $copyBody) {
        Add-Issue "publish\$copyFile has no readable copy body"
      }
      elseif (-not $normalizedPackage.Contains((Get-NormalizedText -Text $copyBody))) {
        $copyLabel = [System.IO.Path]::GetFileNameWithoutExtension($copyFile)
        Add-Issue "publish\发布包.md does not contain the final $copyLabel"
      }
    }
  }
}

$latestRender = Read-JsonFile -Path $latestRenderPath -Label "Latest-render manifest"
if ($null -ne $latestRender) {
  $latestRenderSha256 = Get-RequiredSha256 -Object $latestRender -Name "sha256" -Label "latest-render.sha256"
  Test-Sha256Match -Declared $latestRenderSha256 -Actual $actualRenderSha256 -Label "latest-render.sha256"
}

$qaStamp = Read-JsonFile -Path $qaStampPath -Label "QA stamp"
if ($null -ne $qaStamp) {
  $qaStatus = Get-RequiredText -Object $qaStamp -Name "status" -Label "qa-stamp.status"
  if ($qaStatus -and $qaStatus.ToUpperInvariant() -ne "PASS") {
    Add-Issue "qa-stamp.status must be PASS; actual: $qaStatus"
  }
  $qaRenderSha256 = Get-RequiredSha256 -Object $qaStamp -Name "finalVideoSha256" -Label "qa-stamp.finalVideoSha256"
  Test-Sha256Match -Declared $qaRenderSha256 -Actual $actualRenderSha256 -Label "qa-stamp.finalVideoSha256"
}

$scorecard = $null
$scorecardFile = $null
if (-not (Test-Path -LiteralPath $reviewDir -PathType Container)) {
  Add-Issue "Review directory is missing: $reviewDir"
}
else {
  $scorecards = @(Get-ChildItem -LiteralPath $reviewDir -Filter $ScorecardPattern -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTimeUtc -Descending)
  if ($scorecards.Count -eq 0) {
    Add-Issue "Missing publish-copy scorecard matching review\$ScorecardPattern"
  }
  else {
    $scorecardFile = $scorecards[0]
    $scorecard = Read-JsonFile -Path $scorecardFile.FullName -Label "Publish-copy scorecard"
  }
}

if ($null -ne $scorecard) {
  $scorecardSchema = Get-RequiredText -Object $scorecard -Name "schemaVersion" -Label "scorecard.schemaVersion"
  if ($scorecardSchema -and $scorecardSchema -ne "publish-copy-scorecard-v1") {
    Add-Issue "scorecard.schemaVersion must be publish-copy-scorecard-v1; actual: $scorecardSchema"
  }
  $status = Get-RequiredText -Object $scorecard -Name "status" -Label "scorecard.status"
  if ($status -and $status.ToUpperInvariant() -ne "PASS") {
    Add-Issue "scorecard.status must be PASS; actual: $status"
  }
  Get-RequiredText -Object $scorecard -Name "method" -Label "scorecard.method" | Out-Null
  Get-RequiredText -Object $scorecard -Name "reviewer" -Label "scorecard.reviewer" | Out-Null
  $reviewedTitleId = Get-RequiredText -Object $scorecard -Name "selectedTitleId" -Label "scorecard.selectedTitleId"
  $reviewedFinalTitle = Get-RequiredText -Object $scorecard -Name "finalTitle" -Label "scorecard.finalTitle"
  if ($selectedTitleId -and $reviewedTitleId -and $reviewedTitleId -cne $selectedTitleId) {
    Add-Issue "scorecard.selectedTitleId does not match the plan selection"
  }
  if ($selectedTitle -and $reviewedFinalTitle -and $reviewedFinalTitle -cne $selectedTitle) {
    Add-Issue "scorecard.finalTitle does not match the selected title text"
  }

  $sourceBinding = Get-PropertyValue -Object $scorecard -Name "sourceBinding"
  if ($null -eq $sourceBinding) {
    Add-Issue "scorecard.sourceBinding is missing"
  }
  else {
    $reviewedScriptValue = Get-RequiredText -Object $sourceBinding -Name "script" -Label "scorecard.sourceBinding.script"
    $reviewedRenderValue = Get-RequiredText -Object $sourceBinding -Name "qaApprovedRender" -Label "scorecard.sourceBinding.qaApprovedRender"
    $reviewedScriptPath = $null
    $reviewedRenderPath = $null
    if ($reviewedScriptValue) {
      $reviewedScriptPath = Resolve-AllowedFile -RelativeOrAbsolutePath $reviewedScriptValue -Label "scorecard.sourceBinding.script" -AllowedRoots @($videoRoot) -BoundaryLabel "the video project"
    }
    if ($reviewedRenderValue) {
      $reviewedRenderPath = Resolve-AllowedFile -RelativeOrAbsolutePath $reviewedRenderValue -Label "scorecard.sourceBinding.qaApprovedRender" -AllowedRoots @($videoRoot) -BoundaryLabel "the video project"
    }
    if ($reviewedScriptPath -and $resolvedSourceScriptPath -and
        -not $reviewedScriptPath.Equals($resolvedSourceScriptPath, (Get-CreatorFlowPathComparison))) {
      Add-Issue "scorecard.sourceBinding.script does not match plan.source.script"
    }
    if ($reviewedRenderPath -and $resolvedSourceRenderPath -and
        -not $reviewedRenderPath.Equals($resolvedSourceRenderPath, (Get-CreatorFlowPathComparison))) {
      Add-Issue "scorecard.sourceBinding.qaApprovedRender does not match plan.source.qaApprovedRender"
    }

    $reviewedScriptSha256 = Get-RequiredSha256 -Object $sourceBinding -Name "scriptSha256" -Label "scorecard.sourceBinding.scriptSha256"
    $reviewedRenderSha256 = Get-RequiredSha256 -Object $sourceBinding -Name "qaApprovedRenderSha256" -Label "scorecard.sourceBinding.qaApprovedRenderSha256"
    Test-Sha256Match -Declared $reviewedScriptSha256 -Actual $actualScriptSha256 -Label "scorecard.sourceBinding.scriptSha256"
    Test-Sha256Match -Declared $reviewedRenderSha256 -Actual $actualRenderSha256 -Label "scorecard.sourceBinding.qaApprovedRenderSha256"
    if ($reviewedScriptSha256 -and $planScriptSha256 -and $reviewedScriptSha256 -cne $planScriptSha256) {
      Add-Issue "scorecard.sourceBinding.scriptSha256 does not match plan.source.scriptSha256"
    }
    if ($reviewedRenderSha256 -and $planRenderSha256 -and $reviewedRenderSha256 -cne $planRenderSha256) {
      Add-Issue "scorecard.sourceBinding.qaApprovedRenderSha256 does not match plan.source.qaApprovedRenderSha256"
    }
  }

  $finalScores = Get-PropertyValue -Object $scorecard -Name "scores"
  foreach ($scoreName in @("bodyContinuation", "bodyConcreteValue", "firstCommentValue", "voiceFit", "platformFit")) {
    Get-Score -Scores $finalScores -Name $scoreName -Label "scorecard.scores" -Minimum 4 | Out-Null
  }

  $hardChecks = Get-PropertyValue -Object $scorecard -Name "hardChecks"
  foreach ($checkName in @(
      "sourceFactsVerified",
      "titlePromisePaidOff",
      "titleDoesNotSpoilEntirePayoff",
      "bodyContinuesSameLine",
      "bodyAddsConcreteValue",
      "firstCommentAddsNewValue",
      "firstCommentQuestionIsAnswerable",
      "humanizeWritingApplied",
      "platformConstraintsChecked"
    )) {
    $checkValue = Get-PropertyValue -Object $hardChecks -Name $checkName
    if ($checkValue -isnot [bool] -or -not $checkValue) {
      Add-Issue "scorecard.hardChecks.$checkName must be boolean true"
    }
  }

  if ($null -ne $scorecardFile) {
    $inputsToReview = @($planPath)
    foreach ($path in $publishPaths.Values) { $inputsToReview += [string]$path }
    if ($resolvedSourceScriptPath) { $inputsToReview += $resolvedSourceScriptPath }
    if ($resolvedSourceRenderPath) { $inputsToReview += $resolvedSourceRenderPath }
    foreach ($inputPath in $inputsToReview) {
      if (Test-Path -LiteralPath $inputPath -PathType Leaf) {
        $inputFile = Get-Item -LiteralPath $inputPath
        if ($scorecardFile.LastWriteTimeUtc -lt $inputFile.LastWriteTimeUtc) {
          Add-Issue "Publish-copy scorecard is stale; review again after updating: $inputPath"
        }
      }
    }
  }
}

if ($issues.Count -gt 0) {
  $message = "publish-copy-v1 FAIL ($($issues.Count) issue(s)):`n- " + ($issues -join "`n- ")
  throw $message
}

[ordered]@{
  status = "PASS"
  contract = "publish-copy-v1"
  planPath = $planPath
  scorecardPath = $scorecardFile.FullName
  selectedTitleId = $selectedTitleId
  selectedTitle = $selectedTitle
  candidateCount = $candidateCount
  angleCount = $angleCount
  scriptSha256 = $actualScriptSha256
  qaApprovedRenderSha256 = $actualRenderSha256
  reviewedAt = $scorecardFile.LastWriteTime.ToString("o")
} | ConvertTo-Json -Depth 6
