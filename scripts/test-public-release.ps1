param(
  [string]$PackageRoot = '',

  [ValidateSet('Core', 'Full')]
  [string]$Profile = 'Core',

  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

if ([string]::IsNullOrWhiteSpace($PackageRoot)) {
  $PackageRoot = Join-Path $PSScriptRoot '..'
}

function Resolve-PublicPackagePath {
  param([string]$Root, [string]$RelativePath)
  if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
    throw "Unsafe package path: $RelativePath"
  }
  $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
  $resolved = [IO.Path]::GetFullPath((Join-Path $resolvedRoot ($RelativePath -replace '/', '\')))
  if (-not $resolved.StartsWith($resolvedRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Package path escapes root: $RelativePath"
  }
  return $resolved
}

function Read-PublicReleaseManifest {
  param([Parameter(Mandatory = $true)][string]$PackageRoot)
  $path = Join-Path ([IO.Path]::GetFullPath($PackageRoot)) 'public-export-manifest.json'
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing public-export-manifest.json: $path"
  }
  $manifest = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($manifest.schemaVersion -ne 1 -or $manifest.repository -ne 'creator-flow' -or $manifest.license -ne 'MIT') {
    throw 'Unexpected public release manifest identity'
  }
  if (@($manifest.files).Count -eq 0) { throw 'Public release manifest has no files' }
  return $manifest
}

function Get-PublicCanonicalSha256 {
  param(
    [Parameter(Mandatory = $true)][string]$PathValue,
    [ValidateSet('LF', 'CRLF')][string]$TextLineEnding = 'LF'
  )
  $textExtensions = @('', '.md', '.txt', '.json', '.jsonl', '.ps1', '.psm1', '.py', '.mjs', '.js', '.ts', '.tsx', '.css', '.html', '.yml', '.yaml', '.toml', '.gitignore')
  $extension = [IO.Path]::GetExtension($PathValue).ToLowerInvariant()
  $isText = $textExtensions -contains $extension -or (Split-Path -Leaf $PathValue) -eq '.gitignore'
  if (-not $isText) {
    return (Get-FileHash -LiteralPath $PathValue -Algorithm SHA256).Hash.ToLowerInvariant()
  }

  $inputBytes = [IO.File]::ReadAllBytes($PathValue)
  $normalized = New-Object IO.MemoryStream
  try {
    for ($index = 0; $index -lt $inputBytes.Length; $index++) {
      $byte = $inputBytes[$index]
      if ($byte -eq 13 -and $index + 1 -lt $inputBytes.Length -and $inputBytes[$index + 1] -eq 10) {
        if ($TextLineEnding -eq 'CRLF') { $normalized.WriteByte(13) }
        $normalized.WriteByte(10)
        $index++
        continue
      }
      if ($byte -eq 10 -and $TextLineEnding -eq 'CRLF') { $normalized.WriteByte(13) }
      $normalized.WriteByte($byte)
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
      return ([BitConverter]::ToString($sha.ComputeHash($normalized.ToArray()))).Replace('-', '').ToLowerInvariant()
    }
    finally { $sha.Dispose() }
  }
  finally { $normalized.Dispose() }
}

function Test-PublicManifestIntegrity {
  param(
    [Parameter(Mandatory = $true)][string]$PackageRoot,
    [Parameter(Mandatory = $true)][object]$Manifest
  )
  $destinations = @{}
  $checked = 0
  foreach ($entry in @($Manifest.files)) {
    $relative = ([string]$entry.destination) -replace '\\', '/'
    if ([string]::IsNullOrWhiteSpace($relative)) { throw 'Manifest entry has no destination' }
    $key = $relative.ToLowerInvariant()
    if ($destinations.ContainsKey($key)) { throw "Duplicate manifest destination: $relative" }
    $destinations[$key] = $true
    $path = Resolve-PublicPackagePath -Root $PackageRoot -RelativePath $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing manifest file: $relative" }

    if ($relative -eq 'public-export-manifest.json') {
      if ($null -ne $entry.PSObject.Properties['sha256']) {
        throw 'public-export-manifest.json must not contain a self-referential SHA256'
      }
      continue
    }
    $hashProperty = $entry.PSObject.Properties['sha256']
    if ($null -eq $hashProperty -or [string]$hashProperty.Value -notmatch '^[a-fA-F0-9]{64}$') {
      throw "Missing or invalid SHA256 for manifest file: $relative"
    }
    $expected = ([string]$hashProperty.Value).ToLowerInvariant()
    $actualHashes = @(
      (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant(),
      (Get-PublicCanonicalSha256 -PathValue $path -TextLineEnding LF),
      (Get-PublicCanonicalSha256 -PathValue $path -TextLineEnding CRLF)
    ) | Select-Object -Unique
    if ($actualHashes -notcontains $expected) {
      throw "SHA256 mismatch for manifest file: $relative"
    }
    $checked++
  }
  return [pscustomobject]@{ CheckedFiles = $checked; Destinations = @($destinations.Keys) }
}

function Test-PublicGitState {
  param(
    [Parameter(Mandatory = $true)][string]$PackageRoot,
    [Parameter(Mandatory = $true)][object]$Manifest
  )
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git is required for the release audit' }
  $root = [IO.Path]::GetFullPath($PackageRoot)
  $inside = (& git -C $root rev-parse --is-inside-work-tree 2>$null | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $inside -ne 'true') { throw "Package is not a Git worktree: $root" }
  $status = @(& git -C $root status --porcelain --untracked-files=all 2>$null)
  if ($LASTEXITCODE -ne 0) { throw 'Could not inspect Git status' }
  if ($status.Count -gt 0) { throw "Git worktree is not clean:`n$($status -join "`n")" }

  $tracked = @(& git -C $root ls-files 2>$null | ForEach-Object { ($_ -replace '\\', '/').Trim() } | Where-Object { $_ })
  if ($LASTEXITCODE -ne 0) { throw 'Could not list tracked files' }
  $expected = @($Manifest.files | ForEach-Object { ([string]$_.destination -replace '\\', '/').Trim() })
  $extra = @($tracked | Where-Object { $expected -notcontains $_ })
  $missing = @($expected | Where-Object { $tracked -notcontains $_ })
  if ($extra.Count -gt 0 -or $missing.Count -gt 0) {
    throw "Tracked files do not equal the export manifest. Extra=[$($extra -join ', ')] Missing=[$($missing -join ', ')]"
  }
  return [pscustomobject]@{ TrackedFiles = $tracked.Count; Clean = $true }
}

function Test-PublicRequiredLayout {
  param([Parameter(Mandatory = $true)][string]$PackageRoot)
  $required = @(
    'README.md', 'LICENSE',
    'config/workflow.example.json', 'config/tts.example.json', 'config/providers.example.json', 'config/publish.example.json',
    '.agents/skills/zimeiti-video-workflow/SKILL.md', '.agents/skills/zimeiti-video-wrap-up/SKILL.md',
    '.claude/skills/zimeiti-video-workflow/SKILL.md', '.claude/skills/zimeiti-video-wrap-up/SKILL.md',
    '.agents/skills/zimeiti-video-workflow/references/stage-topic.md',
    '.agents/skills/zimeiti-video-workflow/references/stage-script-tts.md',
    '.agents/skills/zimeiti-video-workflow/references/stage-material.md',
    '.agents/skills/zimeiti-video-workflow/references/stage-assembly.md',
    '.agents/skills/zimeiti-video-workflow/references/stage-qa.md',
    '.agents/skills/zimeiti-video-workflow/references/stage-publish-wrap-up.md',
    '.agents/skills/zimeiti-video-workflow/references/visual-task-coverage-contract.md',
    'examples/ai-mainline-topic/README.md', 'examples/minimal-video-project/README.md',
    'scripts/test-workflow-capabilities.ps1', 'scripts/initialize-video-renderer.ps1',
    'scripts/test-video-orientation-decision.ps1', 'scripts/test-narration-pacing.ps1',
    'scripts/export-trae-work-brand-package.ps1', 'scripts/test-trae-work-package.ps1',
    'packaging/trae-work/README.md', 'packaging/trae-work/installation.md',
    'scripts/test-public-release.ps1',
    'tests/video-renderer-initializer.tests.ps1',
    'tests/agent-platform-support.tests.ps1',
    'tests/trae-work-brand-package.tests.ps1',
    'tests/public-network-boundary.tests.ps1',
    'tests/public-release.tests.ps1'
  )
  $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Resolve-PublicPackagePath -Root $PackageRoot -RelativePath $_) -PathType Leaf) })
  if ($missing.Count -gt 0) { throw "Required public release files are missing: $($missing -join ', ')" }
  return [pscustomobject]@{ RequiredFiles = $required.Count }
}

function Invoke-ReleaseProcess {
  param([string]$FilePath, [string[]]$Arguments = @(), [string]$WorkingDirectory)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  Push-Location -LiteralPath $WorkingDirectory
  try {
    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  }
  finally {
    Pop-Location
    $ErrorActionPreference = $previous
  }
  return [pscustomobject]@{ ExitCode = $exitCode; Output = (($output | Out-String).Trim()) }
}

function Invoke-PowerShellReleaseTest {
  param([string]$PackageRoot, [string]$RelativePath)
  $path = Resolve-PublicPackagePath -Root $PackageRoot -RelativePath $RelativePath
  $result = Invoke-ReleaseProcess -FilePath 'powershell' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $path) -WorkingDirectory $PackageRoot
  if ($result.ExitCode -ne 0) { throw "Release test failed: $RelativePath`n$($result.Output)" }
  return [pscustomobject]@{ Test = $RelativePath; Status = 'PASS' }
}

function Invoke-PythonReleaseTests {
  param([string]$PackageRoot, [string[]]$RelativePaths)
  $results = @()
  foreach ($relativePath in $RelativePaths) {
    $path = Resolve-PublicPackagePath -Root $PackageRoot -RelativePath $relativePath
    $result = Invoke-ReleaseProcess -FilePath 'python' -Arguments @($path) -WorkingDirectory $PackageRoot
    if ($result.ExitCode -ne 0) { throw "Python release test failed: $relativePath`n$($result.Output)" }
    $results += [pscustomobject]@{ Test = $relativePath; Status = 'PASS' }
  }
  return $results
}

function Get-MissingFullRequirements {
  param([string]$PackageRoot, [object]$Capabilities)
  $missing = @()
  foreach ($property in $Capabilities.capabilities.PSObject.Properties) {
    if ($property.Value.required -and -not $property.Value.available) { $missing += $property.Name }
  }
  if (-not $env:ZIMEITI_FULL_RELEASE_VIDEO_DIR -or -not (Test-Path -LiteralPath $env:ZIMEITI_FULL_RELEASE_VIDEO_DIR -PathType Container)) {
    $missing += 'ZIMEITI_FULL_RELEASE_VIDEO_DIR'
  }
  if (-not $env:ZIMEITI_FULL_RELEASE_PUBLISH_CONFIG -or -not (Test-Path -LiteralPath $env:ZIMEITI_FULL_RELEASE_PUBLISH_CONFIG -PathType Leaf)) {
    $missing += 'ZIMEITI_FULL_RELEASE_PUBLISH_CONFIG'
  }
  return @($missing | Select-Object -Unique)
}

function Invoke-PublicReleaseAudit {
  param([string]$PackageRoot, [ValidateSet('Core', 'Full')][string]$Profile)
  $root = [IO.Path]::GetFullPath($PackageRoot)
  $manifest = Read-PublicReleaseManifest -PackageRoot $root
  $integrity = Test-PublicManifestIntegrity -PackageRoot $root -Manifest $manifest
  $git = Test-PublicGitState -PackageRoot $root -Manifest $manifest
  $layout = Test-PublicRequiredLayout -PackageRoot $root

  $scan = Invoke-ReleaseProcess -FilePath 'powershell' -Arguments @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $root 'scripts\export-public-workflow.ps1'),
    '-ManifestPath', (Join-Path $root 'public-export-manifest.json'), '-ScanOnly'
  ) -WorkingDirectory $root
  if ($scan.ExitCode -ne 0) { throw "Privacy scan failed:`n$($scan.Output)" }

  $capabilityResult = Invoke-ReleaseProcess -FilePath 'powershell' -Arguments @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $root 'scripts\test-workflow-capabilities.ps1'),
    '-Profile', $Profile, '-AsJson'
  ) -WorkingDirectory $root
  $capabilities = $capabilityResult.Output | ConvertFrom-Json

  if ($Profile -eq 'Full') {
    $missingFull = Get-MissingFullRequirements -PackageRoot $root -Capabilities $capabilities
    if ($missingFull.Count -gt 0) {
      throw "Full release audit is BLOCKED. Missing required capabilities or fixtures: $($missingFull -join ', ')"
    }
  }
  elseif (-not $capabilities.ready) {
    throw 'Core capability preflight failed'
  }

  $powershellTests = @(
    'tests/public-export-manifest.tests.ps1',
    'tests/public-export.tests.ps1',
    'tests/workflow-config.tests.ps1',
    'tests/tts-portability.tests.ps1',
    'tests/ai-mainline-public-example.tests.ps1',
    'tests/minimal-video-project.tests.ps1',
    'tests/video-wrap-up-portability.tests.ps1',
    'tests/workflow-capabilities.tests.ps1',
    'tests/video-renderer-initializer.tests.ps1',
    'tests/agent-platform-support.tests.ps1',
    'tests/trae-work-brand-package.tests.ps1',
    'tests/public-doc-links.tests.ps1',
    'tests/public-network-boundary.tests.ps1',
    'tests/video-workflow-contract.tests.ps1',
    'tests/video-project-state.tests.ps1',
    'tests/video-visual-task-coverage.tests.ps1',
    'tests/video-human-visual-review.tests.ps1',
    'tests/video-material-visual-task.tests.ps1',
    'tests/public-release.tests.ps1'
  )
  $testResults = @()
  foreach ($test in $powershellTests) {
    $testResults += Invoke-PowerShellReleaseTest -PackageRoot $root -RelativePath $test
  }
  $testResults += Invoke-PythonReleaseTests -PackageRoot $root -RelativePaths @(
    'tests/test_workflow_config.py',
    'tests/test_tts_portability.py',
    'tests/generate_mainline_topic_decision.tests.py'
  )

  if ($Profile -eq 'Full') {
    $videoDir = (Resolve-Path -LiteralPath $env:ZIMEITI_FULL_RELEASE_VIDEO_DIR).Path
    $appDir = Join-Path $videoDir 'hyperframes-app'
    if (-not (Test-Path -LiteralPath $appDir -PathType Container)) { throw "Full fixture has no hyperframes-app: $videoDir" }
    $npmCheck = Invoke-ReleaseProcess -FilePath 'npm' -Arguments @('run', 'check') -WorkingDirectory $appDir
    if ($npmCheck.ExitCode -ne 0) { throw "Full renderer check failed:`n$($npmCheck.Output)" }
    $qa = Invoke-ReleaseProcess -FilePath 'powershell' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $root 'scripts\run-video-draft-qa.ps1'), '-VideoDir', $videoDir) -WorkingDirectory $root
    if ($qa.ExitCode -ne 0) { throw "Full draft QA failed:`n$($qa.Output)" }
    $wrap = Invoke-ReleaseProcess -FilePath 'powershell' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $root 'scripts\invoke-video-wrap-up.ps1'), '-VideoDir', $videoDir, '-PublishConfigPath', $env:ZIMEITI_FULL_RELEASE_PUBLISH_CONFIG, '-DryRun') -WorkingDirectory $root
    if ($wrap.ExitCode -ne 0) { throw "Full wrap-up DryRun failed:`n$($wrap.Output)" }
  }

  return [ordered]@{
    profile = $Profile
    status = 'PASS'
    manifestFiles = @($manifest.files).Count
    hashedFiles = $integrity.CheckedFiles
    trackedFiles = $git.TrackedFiles
    requiredLayoutFiles = $layout.RequiredFiles
    privacyScan = 'PASS'
    capabilities = $capabilities
    tests = $testResults
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  try {
    $result = Invoke-PublicReleaseAudit -PackageRoot $PackageRoot -Profile $Profile
    if ($AsJson) { $result | ConvertTo-Json -Depth 8 }
    else {
      Write-Host "Public release audit: PASS ($Profile)"
      Write-Host "- Manifest files: $($result.manifestFiles)"
      Write-Host "- SHA256 verified: $($result.hashedFiles)"
      Write-Host "- Tracked files: $($result.trackedFiles)"
      Write-Host "- Privacy scan: PASS"
      Write-Host "- Tests: $(@($result.tests).Count) PASS"
    }
    exit 0
  }
  catch {
    if ($AsJson) {
      [ordered]@{ profile = $Profile; status = 'FAIL'; error = $_.Exception.Message } | ConvertTo-Json -Depth 4
    }
    else {
      Write-Error $_.Exception.Message
    }
    exit 1
  }
}
