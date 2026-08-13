param(
    [Parameter(Mandatory = $true)]
    [string]$VideoDir
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([string]$PathValue)
    (Resolve-Path -LiteralPath $PathValue -ErrorAction Stop).Path
}

function Get-JsonProperty {
    param(
        [object]$Object,
        [string[]]$Names
    )
    foreach ($name in $Names) {
        if ($Object.PSObject.Properties.Name -contains $name) {
            $value = $Object.$name
            if ($null -ne $value -and "$value" -ne "") { return $value }
        }
    }
    return $null
}

function Convert-ToDoubleOrNull {
    param([object]$Value)
    if ($null -eq $Value -or "$Value" -eq "") { return $null }
    try {
        return [double]::Parse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        return $null
    }
}

function Convert-ToIntOrNull {
    param([object]$Value)
    if ($null -eq $Value -or "$Value" -eq "") { return $null }
    try {
        return [int]::Parse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        return $null
    }
}

function Get-FfprobeDuration {
    param([string]$Path)
    try {
        $raw = & ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 $Path
        if (-not $raw) { return $null }
        return [double]::Parse([string]$raw, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        return $null
    }
}

function Get-AudioDurationFromJson {
    param([string]$Path)
    try {
        $json = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }
    return Convert-ToDoubleOrNull (Get-JsonProperty -Object $json -Names @(
        "audio_duration_sec",
        "audioDurationSec",
        "durationSec",
        "duration_sec",
        "duration"
    ))
}

function Find-DurationProof {
    param([string]$VideoRoot)
    $candidateRoots = @(
        (Join-Path $VideoRoot "subtitles"),
        (Join-Path $VideoRoot "assets"),
        (Join-Path $VideoRoot "publish"),
        (Join-Path $VideoRoot "review")
    )
    foreach ($root in $candidateRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $jsonFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.json" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending)
        foreach ($file in $jsonFiles) {
            $duration = Get-AudioDurationFromJson -Path $file.FullName
            if ($null -ne $duration -and $duration -gt 0) {
                return [pscustomobject]@{
                    Path = $file.FullName
                    DurationSec = $duration
                }
            }
        }
    }
    return $null
}

function Find-RenderedDurationProof {
    param([string]$VideoRoot)
    $candidateRoots = @(
        (Join-Path (Join-Path $VideoRoot "hyperframes-app") "renders"),
        (Join-Path $VideoRoot "final"),
        (Join-Path $VideoRoot "publish"),
        (Join-Path $VideoRoot "review")
    )
    foreach ($root in $candidateRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $mp4Files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.mp4" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending)
        foreach ($file in $mp4Files) {
            $duration = Get-FfprobeDuration -Path $file.FullName
            if ($null -ne $duration -and $duration -gt 0) {
                return [pscustomobject]@{
                    Path = $file.FullName
                    DurationSec = $duration
                }
            }
        }
    }
    return $null
}

function Get-LegacyOrientationEvidence {
    param([string]$VideoRoot)
    $paths = @(
        (Join-Path $VideoRoot "status.md"),
        (Join-Path (Join-Path (Join-Path $VideoRoot "draft") "visual-plan") "material-beat-map.md"),
        (Join-Path (Join-Path $VideoRoot "hyperframes-app") "design.md")
    )
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $text = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
        $dimensions = $null
        if ($text -match "1920\s*x\s*1080") {
            $dimensions = [pscustomobject]@{ Width = 1920; Height = 1080; Orientation = "horizontal" }
        }
        elseif ($text -match "1080\s*x\s*1920") {
            $dimensions = [pscustomobject]@{ Width = 1080; Height = 1920; Orientation = "vertical" }
        }
        if (-not $dimensions) { continue }

        $duration = $null
        $durationMatches = [System.Text.RegularExpressions.Regex]::Matches($text, "(?<value>\d+(?:\.\d+)?)\s*s\b")
        if ($durationMatches.Count -gt 0) {
            $duration = ($durationMatches | ForEach-Object {
                Convert-ToDoubleOrNull $_.Groups["value"].Value
            } | Where-Object { $null -ne $_ } | Measure-Object -Maximum).Maximum
        }

        $hasExplicitThreshold = $text -match "(?i)>?\s*90\s*(s|sec|seconds)" -or
            $text -match "90\s*\u79d2" -or
            $text -match "\u8d85\u8fc7\s*90" -or
            $text -match "1\s*\u5206\s*30\s*\u79d2"

        return [pscustomobject]@{
            Path = $path
            Orientation = $dimensions.Orientation
            Width = $dimensions.Width
            Height = $dimensions.Height
            DurationSec = $duration
            HasExplicitThreshold = $hasExplicitThreshold
            Source = "legacy"
        }
    }
    return $null
}

function Get-DecisionFromJson {
    param([string]$DecisionPath)
    if (-not (Test-Path -LiteralPath $DecisionPath)) { return $null }
    $data = Get-Content -LiteralPath $DecisionPath -Encoding UTF8 -Raw | ConvertFrom-Json

    $width = Convert-ToIntOrNull (Get-JsonProperty -Object $data -Names @("width", "targetWidth"))
    $height = Convert-ToIntOrNull (Get-JsonProperty -Object $data -Names @("height", "targetHeight"))
    $duration = Convert-ToDoubleOrNull (Get-JsonProperty -Object $data -Names @(
        "durationSec",
        "audioDurationSec",
        "duration_sec",
        "audio_duration_sec",
        "duration"
    ))
    $orientation = [string](Get-JsonProperty -Object $data -Names @("orientation", "layout"))
    if (-not $orientation -and $width -and $height) {
        $orientation = if ($width -gt $height) { "horizontal" } else { "vertical" }
    }
    $orientation = $orientation.ToLowerInvariant()
    if ($orientation -in @("landscape", "horizontal")) { $orientation = "horizontal" }
    if ($orientation -in @("portrait", "vertical")) { $orientation = "vertical" }

    $exception = $false
    $exceptionValue = Get-JsonProperty -Object $data -Names @("exception", "override", "allowMismatch")
    if ($null -ne $exceptionValue) {
        $exception = [System.Convert]::ToBoolean($exceptionValue)
    }

    return [pscustomobject]@{
        Path = $DecisionPath
        Orientation = $orientation
        Width = $width
        Height = $height
        DurationSec = $duration
        Source = [string](Get-JsonProperty -Object $data -Names @("source", "durationSource"))
        Reason = [string](Get-JsonProperty -Object $data -Names @("reason", "note"))
        Exception = $exception
    }
}

$videoRoot = Resolve-FullPath $VideoDir
$decisionPath = Join-Path (Join-Path $videoRoot "draft") "orientation-decision.json"
$issues = New-Object System.Collections.Generic.List[string]
$notes = New-Object System.Collections.Generic.List[string]

$decision = Get-DecisionFromJson -DecisionPath $decisionPath
if (-not $decision) {
    $legacy = Get-LegacyOrientationEvidence -VideoRoot $videoRoot
    if ($legacy) {
        $notes.Add("legacy orientation evidence: $($legacy.Path)")
        $decision = $legacy
    }
    else {
        $issues.Add("Missing orientation decision. Add draft\orientation-decision.json with durationSec, orientation, width, height, and source before assembly.")
    }
}

if ($decision) {
    if ($decision.Orientation -notin @("horizontal", "vertical")) {
        $issues.Add("Orientation decision must be horizontal or vertical: $($decision.Path)")
    }
    if (-not $decision.Width -or -not $decision.Height) {
        $issues.Add("Orientation decision must declare width and height: $($decision.Path)")
    }

    $duration = $decision.DurationSec
    if ($null -eq $duration -or $duration -le 0) {
        $proof = Find-DurationProof -VideoRoot $videoRoot
        if ($proof) {
            $duration = $proof.DurationSec
            $notes.Add("duration proof: $($proof.Path)")
        }
    }
    if ($null -eq $duration -or $duration -le 0) {
        $renderProof = Find-RenderedDurationProof -VideoRoot $videoRoot
        if ($renderProof) {
            $duration = $renderProof.DurationSec
            $notes.Add("render duration proof: $($renderProof.Path)")
        }
    }

    if ($null -eq $duration -or $duration -le 0) {
        if ($decision.Source -eq "legacy" -and $decision.HasExplicitThreshold) {
            $notes.Add("legacy orientation names the 90s threshold but has no machine-readable duration")
        }
        else {
            $issues.Add("Orientation decision needs numeric duration proof: durationSec/audioDurationSec or a timeline proof JSON with audio_duration_sec.")
        }
    }
    else {
        $expected = if ($duration -gt 90.0) {
            [pscustomobject]@{ Orientation = "horizontal"; Width = 1920; Height = 1080 }
        }
        else {
            [pscustomobject]@{ Orientation = "vertical"; Width = 1080; Height = 1920 }
        }

        if (-not $decision.Exception) {
            if ($decision.Orientation -ne $expected.Orientation -or $decision.Width -ne $expected.Width -or $decision.Height -ne $expected.Height) {
                $issues.Add(("Orientation mismatch: duration {0}s expects {1} {2}x{3}, got {4} {5}x{6}. Use exception=true with a reason if intentional." -f ([math]::Round($duration, 3)), $expected.Orientation, $expected.Width, $expected.Height, $decision.Orientation, $decision.Width, $decision.Height))
            }
        }
        elseif (-not $decision.Reason) {
            $issues.Add("Orientation exception must include a reason: $($decision.Path)")
        }

        $notes.Add(("orientation decision: {0} {1}x{2}, duration {3}s" -f $decision.Orientation, $decision.Width, $decision.Height, [math]::Round($duration, 3)))
    }
}

if ($issues.Count -gt 0) {
    Write-Host "Orientation decision QA failed:"
    foreach ($issue in $issues) {
        Write-Host "- $issue"
    }
    exit 1
}

foreach ($note in $notes) {
    Write-Host $note
}
Write-Host "Orientation decision QA passed."
