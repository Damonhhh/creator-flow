Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$exporterPath = Join-Path $repoRoot "scripts\export-public-workflow.ps1"
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("zimeiti-public-export-test-" + [guid]::NewGuid().ToString("N"))

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Write-Utf8 {
  param([string]$Path, [string]$Content)
  $parent = Split-Path -Parent $Path
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function New-Fixture {
  param([string]$Name, [string]$Readme = "# Fixture`n")
  $root = Join-Path $testRoot $Name
  Write-Utf8 -Path (Join-Path $root "open-source\README.md") -Content $Readme
  Write-Utf8 -Path (Join-Path $root "open-source\LICENSE") -Content "MIT License`n"
  Write-Utf8 -Path (Join-Path $root "open-source\.gitignore") -Content "config/*.local.json`n"
  $manifest = [ordered]@{
    schemaVersion = 1
    repository = "zimeiti-video-workflow"
    license = "MIT"
    files = @(
      [ordered]@{ source = "open-source/README.md"; destination = "README.md" },
      [ordered]@{ source = "open-source/LICENSE"; destination = "LICENSE" },
      [ordered]@{ source = "open-source/.gitignore"; destination = ".gitignore" },
      [ordered]@{ source = "public-export-manifest.json"; destination = "public-export-manifest.json" }
    )
  }
  Write-Utf8 -Path (Join-Path $root "public-export-manifest.json") -Content ($manifest | ConvertTo-Json -Depth 8)
  return $root
}

function Invoke-ExporterProcess {
  param([string[]]$Arguments)
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $exporterPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousPreference
  }
  return [ordered]@{ ExitCode = $exitCode; Output = (($output | Out-String).Trim()) }
}

try {
  Assert-True (Test-Path -LiteralPath $exporterPath) "Missing scripts/export-public-workflow.ps1"
  New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

  $happyRoot = New-Fixture -Name "happy"
  $happyDestination = Join-Path $testRoot "happy-destination"
  $happyResult = Invoke-ExporterProcess -Arguments @(
    "-ManifestPath", (Join-Path $happyRoot "public-export-manifest.json"),
    "-Destination", $happyDestination
  )
  Assert-True ($happyResult.ExitCode -eq 0) "Expected successful export: $($happyResult.Output)"
  Assert-True (Test-Path -LiteralPath (Join-Path $happyDestination "README.md")) "README was not exported"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $happyDestination "open-source"))) "Source wrapper directory leaked into destination"
  $publishedManifest = Get-Content -LiteralPath (Join-Path $happyDestination "public-export-manifest.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  $publishedReadme = @($publishedManifest.files | Where-Object { $_.destination -eq 'README.md' })[0]
  Assert-True ($publishedReadme.sha256 -eq (Get-FileHash -LiteralPath (Join-Path $happyDestination "README.md") -Algorithm SHA256).Hash.ToLowerInvariant()) "Exported manifest did not record the README SHA256"
  $publishedManifestEntry = @($publishedManifest.files | Where-Object { $_.destination -eq 'public-export-manifest.json' })[0]
  Assert-True ($null -eq $publishedManifestEntry.PSObject.Properties['sha256']) "The manifest must not contain a self-referential SHA256"

  $packageScan = Invoke-ExporterProcess -Arguments @(
    "-ManifestPath", (Join-Path $happyDestination "public-export-manifest.json"),
    "-ScanOnly"
  )
  Assert-True ($packageScan.ExitCode -eq 0) "Expected exported package scan to use destination paths: $($packageScan.Output)"

  Write-Utf8 -Path (Join-Path $happyDestination "keep.txt") -Content "user file"
  $nonEmptyResult = Invoke-ExporterProcess -Arguments @(
    "-ManifestPath", (Join-Path $happyRoot "public-export-manifest.json"),
    "-Destination", $happyDestination
  )
  Assert-True ($nonEmptyResult.ExitCode -ne 0) "Expected non-empty destination to require -Force"
  Assert-True (Test-Path -LiteralPath (Join-Path $happyDestination "keep.txt")) "Exporter removed an unrelated file"

  $forceResult = Invoke-ExporterProcess -Arguments @(
    "-ManifestPath", (Join-Path $happyRoot "public-export-manifest.json"),
    "-Destination", $happyDestination,
    "-Force"
  )
  Assert-True ($forceResult.ExitCode -eq 0) "Expected -Force export to succeed: $($forceResult.Output)"
  Assert-True (Test-Path -LiteralPath (Join-Path $happyDestination "keep.txt")) "-Force removed an unrelated file"

  $missingRoot = New-Fixture -Name "missing"
  Remove-Item -LiteralPath (Join-Path $missingRoot "open-source\LICENSE") -Force
  $missingResult = Invoke-ExporterProcess -Arguments @(
    "-ManifestPath", (Join-Path $missingRoot "public-export-manifest.json"),
    "-Destination", (Join-Path $testRoot "missing-destination")
  )
  Assert-True ($missingResult.ExitCode -ne 0) "Expected missing manifest source to fail"

  $privatePathFixture = "D:\" + "ai\knowledge-base"
  $privateRoot = New-Fixture -Name "private" -Readme "private path: $privatePathFixture`n"
  $privateResult = Invoke-ExporterProcess -Arguments @(
    "-ManifestPath", (Join-Path $privateRoot "public-export-manifest.json"),
    "-Destination", (Join-Path $testRoot "private-destination")
  )
  Assert-True ($privateResult.ExitCode -ne 0) "Expected private absolute path to fail"

  $bearerFixture = "Authorization: " + "Bearer " + ("a" * 32) + "`n"
  $secretRoot = New-Fixture -Name "secret" -Readme $bearerFixture
  $secretResult = Invoke-ExporterProcess -Arguments @(
    "-ManifestPath", (Join-Path $secretRoot "public-export-manifest.json"),
    "-Destination", (Join-Path $testRoot "secret-destination")
  )
  Assert-True ($secretResult.ExitCode -ne 0) "Expected bearer credential to fail"

  Write-Host "public export tests passed"
}
finally {
  if (Test-Path -LiteralPath $testRoot) {
    $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot).Path
    $tempRoot = ([IO.Path]::GetTempPath()).TrimEnd('\')
    if ($resolvedTestRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedTestRoot).StartsWith("zimeiti-public-export-test-")) {
      Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
  }
}
