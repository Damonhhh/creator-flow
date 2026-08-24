Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$validator = Join-Path $repoRoot "scripts\test-video-publish-copy.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zimeiti-publish-copy-test-" + [guid]::NewGuid().ToString("N"))
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$exampleRoot = Join-Path $repoRoot "open-source\examples\minimal-video-project"
if (-not (Test-Path -LiteralPath $exampleRoot -PathType Container)) {
  $exampleRoot = Join-Path $repoRoot "examples\minimal-video-project"
}

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Write-Utf8Text {
  param([string]$Path, [string]$Text)
  $parent = Split-Path -Parent $Path
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function Write-Utf8Json {
  param([string]$Path, [object]$Object)
  Write-Utf8Text -Path $Path -Text ($Object | ConvertTo-Json -Depth 12)
}

function Get-Sha256 {
  param([string]$Path)
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function New-Candidate {
  param([int]$Number, [string]$Angle)
  return [ordered]@{
    id = "T{0:D2}" -f $Number
    angle = $Angle
    text = if ($Number -eq 1) { "我把八个标题放在一起评分 最后留下了这一条" } else { "候选标题$Number 讲的是另一个具体角度" }
    promise = "看完知道标题为什么不能只做事件摘要"
    curiosityGap = "哪一种角度最后胜出"
    evidence = @("draft/final-script.md#payoff-$Number")
    scores = [ordered]@{
      hook = 4
      concreteness = 4
      audienceStake = 4
      curiosity = 4
      factualFidelity = 5
      payoffMatch = 5
    }
  }
}

function New-ValidFixture {
  param([string]$Name)
  $root = Join-Path $testRoot $Name
  foreach ($directory in @("draft\publish-copy", "draft", "review", "publish")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $root $directory) | Out-Null
  }
  Write-Utf8Text -Path (Join-Path $root "draft\final-script.md") -Text "最终脚本和兑现段落。"
  Write-Utf8Text -Path (Join-Path $root "publish\成片.mp4") -Text "fixture"
  Write-Utf8Text -Path (Join-Path $root "account-profile.md") -Text "账号受众。"
  Write-Utf8Text -Path (Join-Path $root "writing-style.md") -Text "账号写作风格。"
  Write-Utf8Text -Path (Join-Path $root "publish\标题.md") -Text "# 推荐标题`n`n我把八个标题放在一起评分 最后留下了这一条`n"
  Write-Utf8Text -Path (Join-Path $root "publish\正文.md") -Text "以前的发布包只检查文件在不在。这次把标题候选、承诺和兑现位置一起留下，再让另一次复核决定能不能发。"
  Write-Utf8Text -Path (Join-Path $root "publish\首评.md") -Text "先拿你最近一条标题试一次：删掉热点名后，它还给了观众什么点开理由？你的标题现在最缺事实 处境还是悬念？"
  Write-Utf8Text -Path (Join-Path $root "publish\标签.md") -Text "#自媒体 #标题 #工作流"
  Write-Utf8Text -Path (Join-Path $root "publish\发布包.md") -Text @"
## 标题

我把八个标题放在一起评分 最后留下了这一条

## 正文

以前的发布包只检查文件在不在。这次把标题候选、承诺和兑现位置一起留下，再让另一次复核决定能不能发。

## 首评

先拿你最近一条标题试一次：删掉热点名后，它还给了观众什么点开理由？你的标题现在最缺事实 处境还是悬念？

## 标签

#自媒体 #标题 #工作流
"@

  $scriptHash = Get-Sha256 -Path (Join-Path $root "draft\final-script.md")
  $renderHash = Get-Sha256 -Path (Join-Path $root "publish\成片.mp4")
  Write-Utf8Json -Path (Join-Path $root "review\latest-render.json") -Object ([ordered]@{
      project = $Name
      finalVideo = (Join-Path $root "publish\成片.mp4")
      publishVideo = (Join-Path $root "publish\成片.mp4")
      sha256 = $renderHash
    })
  Write-Utf8Json -Path (Join-Path $root "review\qa-stamp.json") -Object ([ordered]@{
      project = $Name
      status = "PASS"
      finalVideo = (Join-Path $root "publish\成片.mp4")
      finalVideoSha256 = $renderHash
    })

  $angles = @("concrete-result", "contradiction-change", "cost-risk", "opportunity-action")
  $candidates = @()
  for ($i = 1; $i -le 8; $i++) {
    $candidates += New-Candidate -Number $i -Angle $angles[($i - 1) % $angles.Count]
  }
  $plan = [ordered]@{
    schemaVersion = "publish-copy-plan-v1"
    source = [ordered]@{
      script = "draft/final-script.md"
      scriptSha256 = $scriptHash
      qaApprovedRender = "publish/成片.mp4"
      qaApprovedRenderSha256 = $renderHash
      accountProfile = "account-profile.md"
      writingStyle = "writing-style.md"
    }
    brief = [ordered]@{
      platforms = @("wechat-channels")
      audience = "已经做完视频但发布标题总像工作汇报的创作者"
      viewerMoment = "视频成片后准备发布"
      subject = "发布标题和正文的结构化生产"
      coreFact = "旧门槛只验证文件和复核标记"
      evidence = @("scripts/invoke-video-wrap-up.ps1:339")
      tension = "形式 PASS 仍可能放过陈述型标题"
      audienceStake = "发布前能否保住一次点击机会"
      promisedTakeaway = "一套可复用的标题矩阵和复核门槛"
      payoffInVideo = "脚本后半段展示完整工序"
      factualBoundary = "不承诺标题一定成为爆款"
    }
    titleCandidates = $candidates
    selection = [ordered]@{
      selectedTitleId = "T01"
      reason = "有具体动作和未揭示的选择结果"
      rejectedRisks = @("事件摘要", "提前说完结论")
    }
    bodyPlan = [ordered]@{
      openingJob = "继续标题里的复核问题"
      concreteValue = "说明旧门槛与新门槛的差别"
      videoReason = "完整矩阵和判断过程留在视频里"
    }
    firstCommentPlan = [ordered]@{
      addedValue = "给观众一个删掉热点名的自测动作"
      answerableQuestion = "你的标题现在最缺事实 处境还是悬念？"
    }
  }
  Write-Utf8Json -Path (Join-Path $root "draft\publish-copy\publish-copy-plan.json") -Object $plan

  $scorecard = [ordered]@{
    schemaVersion = "publish-copy-scorecard-v1"
    status = "PASS"
    method = "independent editorial review plus humanize-writing"
    reviewer = "fixture-reviewer"
    selectedTitleId = "T01"
    finalTitle = "我把八个标题放在一起评分 最后留下了这一条"
    sourceBinding = [ordered]@{
      script = "draft/final-script.md"
      scriptSha256 = $scriptHash
      qaApprovedRender = "publish/成片.mp4"
      qaApprovedRenderSha256 = $renderHash
    }
    scores = [ordered]@{
      bodyContinuation = 4
      bodyConcreteValue = 4
      firstCommentValue = 4
      voiceFit = 4
      platformFit = 4
    }
    hardChecks = [ordered]@{
      sourceFactsVerified = $true
      titlePromisePaidOff = $true
      titleDoesNotSpoilEntirePayoff = $true
      bodyContinuesSameLine = $true
      bodyAddsConcreteValue = $true
      firstCommentAddsNewValue = $true
      firstCommentQuestionIsAnswerable = $true
      humanizeWritingApplied = $true
      platformConstraintsChecked = $true
    }
  }
  Start-Sleep -Milliseconds 20
  Write-Utf8Json -Path (Join-Path $root "review\publish-copy-scorecard-v01.json") -Object $scorecard
  return $root
}

function Refresh-Scorecard {
  param([string]$Root)
  $path = Join-Path $Root "review\publish-copy-scorecard-v01.json"
  $scorecard = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
  Start-Sleep -Milliseconds 20
  Write-Utf8Json -Path $path -Object $scorecard
}

function Get-FailureMessage {
  param([string]$Root)
  try {
    & $validator -VideoDir $Root | Out-Null
    return ""
  }
  catch {
    return $_.Exception.Message
  }
}

try {
  $valid = New-ValidFixture -Name "valid"
  $validResult = (& $validator -VideoDir $valid) | ConvertFrom-Json
  Assert-True ($validResult.status -eq "PASS") "A complete publish-copy-v1 fixture must pass"
  Assert-True ($validResult.candidateCount -eq 8) "Expected all title candidates to be counted"
  Assert-True ($validResult.angleCount -eq 4) "Expected four angle families"
  Assert-True ($validResult.scriptSha256 -eq (Get-Sha256 -Path (Join-Path $valid "draft\final-script.md"))) "PASS output must expose the bound script hash"
  Assert-True ($validResult.qaApprovedRenderSha256 -eq (Get-Sha256 -Path (Join-Path $valid "publish\成片.mp4"))) "PASS output must expose the bound render hash"

  $repoLevelStyle = New-ValidFixture -Name "repo-level-style"
  $repoLevelPlanPath = Join-Path $repoLevelStyle "draft\publish-copy\publish-copy-plan.json"
  $repoLevelPlan = Get-Content -LiteralPath $repoLevelPlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $repoLevelPlan.source.accountProfile = Join-Path $exampleRoot "account-profile.example.md"
  $repoLevelPlan.source.writingStyle = Join-Path $exampleRoot "writing-style.example.md"
  Write-Utf8Json -Path $repoLevelPlanPath -Object $repoLevelPlan
  Refresh-Scorecard -Root $repoLevelStyle
  $repoLevelResult = (& $validator -VideoDir $repoLevelStyle) | ConvertFrom-Json
  Assert-True ($repoLevelResult.status -eq "PASS") "Repository-level account and writing-style sources must be allowed"

  $outsideScript = New-ValidFixture -Name "outside-script"
  $outsideScriptPlanPath = Join-Path $outsideScript "draft\publish-copy\publish-copy-plan.json"
  $outsideScriptPlan = Get-Content -LiteralPath $outsideScriptPlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $outsideScriptPlan.source.script = Join-Path $repoRoot "AGENTS.md"
  Write-Utf8Json -Path $outsideScriptPlanPath -Object $outsideScriptPlan
  Refresh-Scorecard -Root $outsideScript
  Assert-True ((Get-FailureMessage -Root $outsideScript).Contains("must stay inside the video project")) "Script and render sources must belong to the current video"

  $tooFew = New-ValidFixture -Name "too-few"
  $tooFewPlanPath = Join-Path $tooFew "draft\publish-copy\publish-copy-plan.json"
  $tooFewPlan = Get-Content -LiteralPath $tooFewPlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $tooFewPlan.titleCandidates = @($tooFewPlan.titleCandidates | Select-Object -First 7)
  Write-Utf8Json -Path $tooFewPlanPath -Object $tooFewPlan
  Refresh-Scorecard -Root $tooFew
  Assert-True ((Get-FailureMessage -Root $tooFew).Contains("at least 8 candidates")) "Too few title candidates must fail"

  $tooNarrow = New-ValidFixture -Name "too-narrow"
  $tooNarrowPlanPath = Join-Path $tooNarrow "draft\publish-copy\publish-copy-plan.json"
  $tooNarrowPlan = Get-Content -LiteralPath $tooNarrowPlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($candidate in $tooNarrowPlan.titleCandidates) { $candidate.angle = "topic-summary" }
  Write-Utf8Json -Path $tooNarrowPlanPath -Object $tooNarrowPlan
  Refresh-Scorecard -Root $tooNarrow
  Assert-True ((Get-FailureMessage -Root $tooNarrow).Contains("at least 4 distinct angle")) "One-angle synonym lists must fail"

  $titleMismatch = New-ValidFixture -Name "title-mismatch"
  Write-Utf8Text -Path (Join-Path $titleMismatch "publish\标题.md") -Text "# 推荐标题`n`n临时换了一个没有进候选池的标题`n"
  Refresh-Scorecard -Root $titleMismatch
  Assert-True ((Get-FailureMessage -Root $titleMismatch).Contains("must exactly match selected title")) "The final primary title must match the selected candidate"

  $lowFidelity = New-ValidFixture -Name "low-fidelity"
  $lowPlanPath = Join-Path $lowFidelity "draft\publish-copy\publish-copy-plan.json"
  $lowPlan = Get-Content -LiteralPath $lowPlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $lowPlan.titleCandidates[0].scores.factualFidelity = 3
  Write-Utf8Json -Path $lowPlanPath -Object $lowPlan
  Refresh-Scorecard -Root $lowFidelity
  Assert-True ((Get-FailureMessage -Root $lowFidelity).Contains("factualFidelity must be at least 4")) "Low factual fidelity must fail even when total score is high"

  $genericComment = New-ValidFixture -Name "generic-comment"
  $genericPlanPath = Join-Path $genericComment "draft\publish-copy\publish-copy-plan.json"
  $genericPlan = Get-Content -LiteralPath $genericPlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $genericPlan.firstCommentPlan.answerableQuestion = "你怎么看"
  Write-Utf8Json -Path $genericPlanPath -Object $genericPlan
  Write-Utf8Text -Path (Join-Path $genericComment "publish\首评.md") -Text "你怎么看"
  Refresh-Scorecard -Root $genericComment
  Assert-True ((Get-FailureMessage -Root $genericComment).Contains("generic engagement prompt")) "A generic first comment must fail"

  $stalePackage = New-ValidFixture -Name "stale-package"
  Write-Utf8Text -Path (Join-Path $stalePackage "publish\发布包.md") -Text "## 标题`n`n我把八个标题放在一起评分 最后留下了这一条`n`n## 正文`n`n这里还是上一版正文。`n`n## 首评`n`n这里还是上一版首评。"
  Refresh-Scorecard -Root $stalePackage
  Assert-True ((Get-FailureMessage -Root $stalePackage).Contains("does not contain the final 正文")) "A stale combined publish package must fail"

  $failedHardCheck = New-ValidFixture -Name "failed-hard-check"
  $failedScorecardPath = Join-Path $failedHardCheck "review\publish-copy-scorecard-v01.json"
  $failedScorecard = Get-Content -LiteralPath $failedScorecardPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $failedScorecard.hardChecks.titlePromisePaidOff = $false
  Write-Utf8Json -Path $failedScorecardPath -Object $failedScorecard
  Assert-True ((Get-FailureMessage -Root $failedHardCheck).Contains("titlePromisePaidOff must be boolean true")) "A failed promise/payoff hard check must block wrap-up"

  $missingPlanHash = New-ValidFixture -Name "missing-plan-hash"
  $missingPlanHashPath = Join-Path $missingPlanHash "draft\publish-copy\publish-copy-plan.json"
  $missingPlanHashValue = Get-Content -LiteralPath $missingPlanHashPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $missingPlanHashValue.source.PSObject.Properties.Remove("scriptSha256")
  Write-Utf8Json -Path $missingPlanHashPath -Object $missingPlanHashValue
  Refresh-Scorecard -Root $missingPlanHash
  Assert-True ((Get-FailureMessage -Root $missingPlanHash).Contains("plan.source.scriptSha256 must be a non-empty string")) "A plan without the final script hash must fail"

  $missingBinding = New-ValidFixture -Name "missing-scorecard-binding"
  $missingBindingPath = Join-Path $missingBinding "review\publish-copy-scorecard-v01.json"
  $missingBindingValue = Get-Content -LiteralPath $missingBindingPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $missingBindingValue.PSObject.Properties.Remove("sourceBinding")
  Write-Utf8Json -Path $missingBindingPath -Object $missingBindingValue
  Assert-True ((Get-FailureMessage -Root $missingBinding).Contains("scorecard.sourceBinding is missing")) "A scorecard without source hashes must fail"

  $scriptChanged = New-ValidFixture -Name "script-changed"
  Write-Utf8Text -Path (Join-Path $scriptChanged "draft\final-script.md") -Text "评分完成后被替换的脚本。"
  Assert-True ((Get-FailureMessage -Root $scriptChanged).Contains("plan.source.scriptSha256 does not match the actual file SHA-256")) "Replacing the final script after review must fail"

  $renderChanged = New-ValidFixture -Name "render-changed"
  Write-Utf8Text -Path (Join-Path $renderChanged "publish\成片.mp4") -Text "replacement-render"
  Assert-True ((Get-FailureMessage -Root $renderChanged).Contains("plan.source.qaApprovedRenderSha256 does not match the actual file SHA-256")) "Replacing the approved render after review must fail"

  $latestRenderMismatch = New-ValidFixture -Name "latest-render-mismatch"
  $latestRenderPath = Join-Path $latestRenderMismatch "review\latest-render.json"
  $latestRenderValue = Get-Content -LiteralPath $latestRenderPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $latestRenderValue.sha256 = ("0" * 64)
  Write-Utf8Json -Path $latestRenderPath -Object $latestRenderValue
  Assert-True ((Get-FailureMessage -Root $latestRenderMismatch).Contains("latest-render.sha256 does not match the actual file SHA-256")) "The render manifest must match the reviewed render"

  $qaStampMismatch = New-ValidFixture -Name "qa-stamp-mismatch"
  $qaStampPath = Join-Path $qaStampMismatch "review\qa-stamp.json"
  $qaStampValue = Get-Content -LiteralPath $qaStampPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $qaStampValue.finalVideoSha256 = ("F" * 64)
  Write-Utf8Json -Path $qaStampPath -Object $qaStampValue
  Assert-True ((Get-FailureMessage -Root $qaStampMismatch).Contains("qa-stamp.finalVideoSha256 does not match the actual file SHA-256")) "The QA stamp must match the reviewed render"

  $staleSource = New-ValidFixture -Name "stale-source"
  (Get-Item -LiteralPath (Join-Path $staleSource "draft\final-script.md")).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddMinutes(1)
  Assert-True ((Get-FailureMessage -Root $staleSource).Contains("scorecard is stale")) "Touching a bound source after review must make the scorecard stale even when its hash is unchanged"

  $stale = New-ValidFixture -Name "stale"
  $staleScorecardPath = Join-Path $stale "review\publish-copy-scorecard-v01.json"
  (Get-Item -LiteralPath $staleScorecardPath).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddMinutes(-10)
  Assert-True ((Get-FailureMessage -Root $stale).Contains("scorecard is stale")) "A stale scorecard must fail"

  Write-Host "video publish-copy tests passed"
}
finally {
  $resolvedTemp = [System.IO.Path]::GetFullPath($testRoot)
  $systemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
  if ($resolvedTemp.StartsWith($systemTemp, [System.StringComparison]::OrdinalIgnoreCase) -and
      (Test-Path -LiteralPath $resolvedTemp)) {
    Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
  }
}
