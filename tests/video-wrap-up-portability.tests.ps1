Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "scripts\invoke-video-wrap-up.ps1"
$publicConfigPath = Join-Path $repoRoot "open-source\config\publish.example.json"
if (-not (Test-Path -LiteralPath $publicConfigPath -PathType Leaf)) {
  $publicConfigPath = Join-Path $repoRoot "config\publish.example.json"
}
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("zimeiti-wrap-test-" + [guid]::NewGuid().ToString("N"))

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

try {
  $scriptText = Get-Content -LiteralPath $scriptPath -Raw -Encoding UTF8
  Assert-True ($scriptText.Contains('[string]$PublishConfigPath')) "Wrap-up must expose PublishConfigPath"
  Assert-True ($scriptText.Contains('[string]$OutputRoot')) "Wrap-up must expose OutputRoot"
  Assert-True ($scriptText.Contains('[string[]]$Platforms = @()')) "Platforms must default through config"
  Assert-True ($scriptText.Contains('publishCopyPass = $publishCopyPass.path')) "Manifest must expose publishCopyPass"

  $publicConfig = Get-Content -LiteralPath $publicConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True (@($publicConfig.platforms).Count -eq 0) "Public config must not select upload platforms"
  Assert-True ($publicConfig.publishCopyPass.recordPattern -eq 'publish-copy-pass-v*.md') "Unexpected public review record pattern"

  $tokens = $null
  $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
  Assert-True ($errors.Count -eq 0) "Wrap-up script must parse cleanly"
  $functionAst = $ast.Find({
      param($node)
      $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-PublishCopyPass'
    }, $true)
  Assert-True ($null -ne $functionAst) "Missing Test-PublishCopyPass"
  Invoke-Expression $functionAst.Extent.Text

  $reviewDir = Join-Path $testRoot 'review'
  New-Item -ItemType Directory -Force -Path $reviewDir | Out-Null
  [IO.File]::WriteAllText(
    (Join-Path $reviewDir 'publish-copy-pass-v01.md'),
    "status: PASS`nmethod: human review`n",
    [Text.UTF8Encoding]::new($false)
  )
  $result = Test-PublishCopyPass -ReviewDir $reviewDir -RecordPattern 'publish-copy-pass-v*.md' -RequiredMarkers @('status: PASS', 'method:')
  Assert-True ($result.path.EndsWith('publish-copy-pass-v01.md')) "Expected the generic review record"

  [IO.File]::WriteAllText(
    (Join-Path $reviewDir 'publish-copy-pass-v02.md'),
    "status: PASS`nmethod:`n",
    [Text.UTF8Encoding]::new($false)
  )
  $message = ''
  try {
    Test-PublishCopyPass -ReviewDir $reviewDir -RecordPattern 'publish-copy-pass-v*.md' -RequiredMarkers @('status: PASS', 'method:') | Out-Null
  }
  catch { $message = $_.Exception.Message }
  Assert-True ($message.Contains('non-empty marker')) "An empty method must fail"

  Write-Host "video wrap-up portability tests passed"
}
finally {
  if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}
