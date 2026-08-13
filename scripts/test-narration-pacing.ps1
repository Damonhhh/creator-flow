param(
  [Parameter(Mandatory = $true)]
  [string]$AudioPath,
  [double]$MaxPauseSec = 0.9,
  [double]$SilenceThresholdDb = -35,
  [double]$MinDetectedSilenceSec = 0.35,
  [string]$ReportPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$audio = (Resolve-Path -LiteralPath $AudioPath -ErrorAction Stop).Path
if ($MaxPauseSec -le 0 -or $MinDetectedSilenceSec -le 0) { throw "Pause thresholds must be positive." }

$previous = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$raw = & ffmpeg -hide_banner -i $audio -af "silencedetect=n=$($SilenceThresholdDb)dB:d=$MinDetectedSilenceSec" -f null NUL 2>&1 | Out-String
$exitCode = $LASTEXITCODE
$ErrorActionPreference = $previous
if ($exitCode -ne 0) { throw "ffmpeg silencedetect failed for $audio (exit $exitCode)." }

$durations = @([regex]::Matches($raw, "silence_duration:\s*([0-9.]+)") | ForEach-Object { [double]$_.Groups[1].Value })
$violations = @($durations | Where-Object { $_ -gt $MaxPauseSec })
$maximum = if ($durations.Count) { ($durations | Measure-Object -Maximum).Maximum } else { 0.0 }
$result = [ordered]@{
  audio = $audio
  maxAllowedPauseSec = $MaxPauseSec
  pauseCount = $durations.Count
  maxDetectedPauseSec = [math]::Round([double]$maximum, 3)
  pausesOverLimit = $violations.Count
  status = if ($violations.Count) { "FAIL" } else { "PASS" }
}

if ($ReportPath) {
  $parent = Split-Path -Parent $ReportPath
  if (-not (Test-Path -LiteralPath $parent)) { throw "Report directory does not exist: $parent" }
  $text = @(
    "# Narration Pacing Check", "",
    "- Audio: $audio",
    "- Maximum allowed pause: $MaxPauseSec s",
    "- Detected pauses: $($durations.Count)",
    "- Longest detected pause: $([math]::Round([double]$maximum, 3)) s",
    "- Pauses over limit: $($violations.Count)",
    "- Status: $($result.status)"
  ) -join "`n"
  [System.IO.File]::WriteAllText($ReportPath, $text + "`n", [System.Text.UTF8Encoding]::new($false))
}

$result | ConvertTo-Json -Depth 4
if ($violations.Count) {
  throw "Narration has $($violations.Count) pause(s) over $MaxPauseSec s. Regenerate with larger TTS segments or shorter joins; do not pad runtime with silence."
}
