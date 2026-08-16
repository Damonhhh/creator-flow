param(
    [Parameter(Mandatory = $true)]
    [string]$VideoDir,

    [switch]$NoStateUpdate
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath $VideoDir -ErrorAction Stop).Path
$carryoverFile = Join-Path $root "draft\production-carryover.md"
$sourceFile = Join-Path $root "draft\web-assets\source-candidates.md"
$beatMapFile = Join-Path $root "draft\visual-plan\material-beat-map.md"
$generatedMotionPlanFile = Join-Path $root "draft\visual-plan\generated-motion-asset-plan.md"
$stillPromptPackFile = Join-Path $root "draft\visual-plan\still-image-prompt-pack.md"
$sourceImageRenameMapFile = Join-Path $root "draft\visual-plan\source-image-rename-map.md"
$motionPromptPackFile = Join-Path $root "draft\visual-plan\motion-video-prompt-pack.md"
$sourceMotionRenameMapFile = Join-Path $root "draft\visual-plan\source-motion-rename-map.md"
$motionVideoIntakeFile = Join-Path $root "draft\visual-plan\motion-video-intake.md"

$issues = New-Object System.Collections.Generic.List[string]
$materialNextAction = "Resolve material QA blockers before Assembly."
$carryoverText = ""
$sourceText = ""
$beatText = ""
$placeholderPattern = '(?i)\b(TODO|TBD)\b|\u5f85\u5b9a|\u5f85\u8865|\u5f85\u586b|\u5360\u4f4d|\u7a0d\u540e\u8865|\u672a\u5b9a|\u672a\u8865|\u5f85\u5b8c\u5584'
$chinesePlaceholderPattern = '\u5f85\u5b9a|\u5f85\u8865|\u5f85\u586b|\u5360\u4f4d|\u7a0d\u540e\u8865|\u672a\u5b9a|\u672a\u8865|\u5f85\u5b8c\u5584'
$requiredCarryoverMarkers = @(
    'Hook gives a take-away',
    'Proof appears before polish',
    'Abstract nouns become actions',
    'Invisible mechanisms get process visuals',
    'Key terms and entities get anchors',
    'Visual rhythm has breathing points',
    'Closing thesis lands visually',
    'Publish package closes the loop'
)

function Add-EncodingIssueIfNeeded {
    param(
        [string]$Text,
        [string]$Label
    )

    if (-not $Text) { return }
    $replacementChar = [string][char]0xfffd
    if ($Text -match [System.Text.RegularExpressions.Regex]::Escape($replacementChar) -or $Text -match '\?{3,}') {
        $issues.Add("$Label appears to contain mojibake or replacement characters. Re-save it as UTF-8 before material QA.")
    }
}

function Test-PlaceholderText {
    param([string]$Text)

    if (-not $Text) { return $false }
    $lines = @($Text -split "`r?`n")
    foreach ($line in $lines) {
        if ($line -match $chinesePlaceholderPattern) {
            return $true
        }
        if ($line -match '(?i)\b(TODO|TBD)\b' -and $line -notmatch '(?i)placeholder|example|rule|block|check|template') {
            return $true
        }
    }
    return $false
}

function Get-DeclaredFieldValue {
    param(
        [string]$Text,
        [string]$Name
    )

    if (-not $Text) { return $null }
    $match = [System.Text.RegularExpressions.Regex]::Match(
        $Text,
        '(?im)^\s*-?\s*' + [System.Text.RegularExpressions.Regex]::Escape($Name) + '\s*[:\uFF1A]\s*(?<value>[^\r\n]+?)\s*$'
    )
    if (-not $match.Success) { return $null }
    return $match.Groups["value"].Value.Trim().Trim('`').Trim()
}

function Get-DeclaredInteger {
    param(
        [string]$Text,
        [string]$Name
    )

    $value = Get-DeclaredFieldValue -Text $Text -Name $Name
    $parsed = 0
    if ($null -eq $value -or -not [int]::TryParse($value, [ref]$parsed)) {
        return $null
    }
    return $parsed
}

function Resolve-ProjectDeclaredPath {
    param(
        [string]$ProjectRoot,
        [string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $null }
    $clean = $PathValue.Trim().Trim('`').Trim() -replace '/', '\'
    if ([System.IO.Path]::IsPathRooted($clean)) {
        return [System.IO.Path]::GetFullPath($clean)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $clean))
}

function Get-StableAssetRows {
    param(
        [string]$Text,
        [ValidateSet("IMG", "MOV")]
        [string]$Prefix
    )

    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($line in @($Text -split "`r?`n")) {
        if ($line -notmatch ('^\s*\|\s*' + $Prefix + '\d{2}-')) { continue }
        $cells = @(Split-MarkdownTableRow -Line $line)
        if ($cells.Count -eq 0) { continue }
        $rows.Add([pscustomobject]@{
            Id = $cells[0]
            Cells = $cells
            Raw = $line
        })
    }
    return @($rows | ForEach-Object { $_ })
}

function Test-SamePath {
    param(
        [string]$Left,
        [string]$Right
    )

    if (-not $Left -or -not $Right) { return $false }
    return [string]::Equals(
        [System.IO.Path]::GetFullPath($Left).TrimEnd('\'),
        [System.IO.Path]::GetFullPath($Right).TrimEnd('\'),
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Get-CarryoverMarkerBody {
    param(
        [string]$Text,
        [string]$Marker,
        [string[]]$AllMarkers
    )

    $lines = @($Text -split "`r?`n")
    $escapedMarker = [System.Text.RegularExpressions.Regex]::Escape($Marker)

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $match = [System.Text.RegularExpressions.Regex]::Match($lines[$i], $escapedMarker, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $match.Success) { continue }

        $bodyParts = New-Object System.Collections.Generic.List[string]
        $inlineBody = $lines[$i].Substring($match.Index + $match.Length).Trim(" ", "`t", ":", "-")
        if ($inlineBody) { $bodyParts.Add($inlineBody) }

        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            $nextLine = $lines[$j].Trim()
            if (-not $nextLine) { continue }
            if ($nextLine -match '^\s*#') { break }
            $isNextMarker = $false
            foreach ($candidate in $AllMarkers) {
                if ($candidate -eq $Marker) { continue }
                if ($nextLine -match [System.Text.RegularExpressions.Regex]::Escape($candidate)) {
                    $isNextMarker = $true
                    break
                }
            }
            if ($isNextMarker) { break }
            $bodyParts.Add($nextLine.Trim(" ", "`t", "-", "*", ":"))
        }

        return (($bodyParts | Where-Object { $_ }) -join " ").Trim()
    }

    return $null
}

if (-not (Test-Path -LiteralPath $carryoverFile)) {
    $issues.Add("Missing draft\production-carryover.md. New video production must state how previous learnings become concrete actions for this video.")
} else {
    $carryoverText = Get-Content -LiteralPath $carryoverFile -Raw -Encoding utf8
    Add-EncodingIssueIfNeeded -Text $carryoverText -Label "production-carryover.md"
    if (Test-PlaceholderText -Text $carryoverText) {
        $issues.Add("production-carryover.md still contains placeholder text such as TODO/TBD or Chinese placeholder terms. Replace placeholders with this video's actual hook, proof, motion, rhythm, visual-anchor, and publish-package actions before material QA.")
    }
    foreach ($required in $requiredCarryoverMarkers) {
        $markerBody = Get-CarryoverMarkerBody -Text $carryoverText -Marker $required -AllMarkers $requiredCarryoverMarkers
        if ($null -eq $markerBody) {
            $issues.Add("production-carryover.md is missing carryover rule marker: $required")
        } elseif (($markerBody -replace '\s+', '').Length -lt 15) {
            $issues.Add("production-carryover.md marker '$required' does not contain a concrete action. Keep the marker and fill in this video's actual action before material QA.")
        }
    }
}

function Split-MarkdownTableRow {
    param([string]$Line)

    $trimmed = $Line.Trim()
    if (-not $trimmed.StartsWith("|")) { return @() }
    $inner = $trimmed.Trim("|")
    return @($inner -split "\|" | ForEach-Object { $_.Trim() })
}

function Test-MarkdownSeparatorRow {
    param([string]$Line)

    $cells = @(Split-MarkdownTableRow -Line $Line)
    if ($cells.Count -eq 0) { return $false }
    $separatorCells = @($cells | Where-Object { $_ -match '^:?-{3,}:?$' -or $_ -match '^-{3,}$' })
    return ($separatorCells.Count -eq $cells.Count)
}

function Get-HeaderIndex {
    param(
        [string[]]$Headers,
        [string]$Pattern
    )

    for ($i = 0; $i -lt $Headers.Count; $i++) {
        if ($Headers[$i] -match $Pattern) { return $i }
    }
    return -1
}

function Get-MaterialBeatTable {
    param([string]$BeatText)

    $lines = @($BeatText -split "`r?`n")
    $tables = @()

    for ($i = 0; $i -lt ($lines.Count - 1); $i++) {
        if (-not $lines[$i].Trim().StartsWith("|")) { continue }
        if (-not (Test-MarkdownSeparatorRow -Line $lines[$i + 1])) { continue }

        $headers = @(Split-MarkdownTableRow -Line $lines[$i])
        $jobIndex = Get-HeaderIndex -Headers $headers -Pattern '(?i)\bjob\b'
        $materialIndex = Get-HeaderIndex -Headers $headers -Pattern '(?i)(material|source|asset)'
        $motionIndex = Get-HeaderIndex -Headers $headers -Pattern '(?i)(motion|design note|treatment)'
        $lineIdIndex = Get-HeaderIndex -Headers $headers -Pattern '(?i)(line\s*id|sentence\s*id)'
        $timeIndex = Get-HeaderIndex -Headers $headers -Pattern '(?i)^time$|time\s*range|timing'
        $sentenceIndex = Get-HeaderIndex -Headers $headers -Pattern '(?i)(spoken\s*(sentence|line|beat)|narration)'
        $taskIdIndex = Get-HeaderIndex -Headers $headers -Pattern '(?i)task\s*id'
        $visualTaskIndex = Get-HeaderIndex -Headers $headers -Pattern '(?i)visual\s*task'
        if ($jobIndex -lt 0 -or $materialIndex -lt 0 -or $motionIndex -lt 0) { continue }

        $rows = @()
        for ($j = $i + 2; $j -lt $lines.Count; $j++) {
            $line = $lines[$j]
            if (-not $line.Trim().StartsWith("|")) { break }
            if (Test-MarkdownSeparatorRow -Line $line) { continue }

            $cells = @(Split-MarkdownTableRow -Line $line)
            $maxIndex = ($jobIndex, $materialIndex, $motionIndex | Measure-Object -Maximum).Maximum
            $malformed = ($cells.Count -le $maxIndex)
            $narrativeCells = @()
            for ($k = 0; $k -lt $cells.Count; $k++) {
                if ($k -ne $materialIndex -and $k -ne $motionIndex) {
                    $narrativeCells += $cells[$k]
                }
            }

            $rows += [pscustomobject]@{
                Raw       = $line
                Job       = if ($cells.Count -gt $jobIndex) { $cells[$jobIndex] } else { "" }
                Material  = if ($cells.Count -gt $materialIndex) { $cells[$materialIndex] } else { "" }
                Motion    = if ($cells.Count -gt $motionIndex) { $cells[$motionIndex] } else { "" }
                LineId    = if ($lineIdIndex -ge 0 -and $cells.Count -gt $lineIdIndex) { $cells[$lineIdIndex] } else { "" }
                Time      = if ($timeIndex -ge 0 -and $cells.Count -gt $timeIndex) { $cells[$timeIndex] } else { "" }
                Sentence  = if ($sentenceIndex -ge 0 -and $cells.Count -gt $sentenceIndex) { $cells[$sentenceIndex] } else { "" }
                TaskId    = if ($taskIdIndex -ge 0 -and $cells.Count -gt $taskIdIndex) { $cells[$taskIdIndex] } else { "" }
                VisualTask = if ($visualTaskIndex -ge 0 -and $cells.Count -gt $visualTaskIndex) { $cells[$visualTaskIndex] } else { "" }
                FirstCell = if ($cells.Count -gt 0) { $cells[0] } else { "" }
                Headers   = $headers
                Cells     = $cells
                Narrative = ($narrativeCells -join " ")
                Malformed = $malformed
            }
        }

        if ($rows.Count -gt 0) {
            $tables += [pscustomobject]@{
                Headers = $headers
                Rows = $rows
                IsCompact = ($headers.Count -le 5 -and $headers[0] -match '(?i)^(#|beat)$')
            }
        }
    }

    if ($tables.Count -eq 0) { return $null }
    return $tables
}

function Test-StrictMotionJobMode {
    param(
        [string]$VideoRoot,
        [string]$BeatText
    )

    $decisionPath = Join-Path (Join-Path $VideoRoot "draft") "orientation-decision.json"
    if (Test-Path -LiteralPath $decisionPath) { return $true }
    return ($BeatText -match '(?i)motion\s*job\s*[:\uFF1A]' -or $BeatText -match '(?i)motion-job-v1')
}

function Test-MotionJobSchemaV11Mode {
    param([string]$BeatText)

    return ($BeatText -match '(?i)motion-job-v1\.1')
}

function Test-VisualTaskV1Mode {
    param([string]$BeatText)

    return ($BeatText -match '(?i)visual-task-v1')
}

function Get-MotionJobStatement {
    param([string]$Text)

    if (-not $Text) { return "" }
    $match = [System.Text.RegularExpressions.Regex]::Match(
        $Text,
        '(?i)motion\s*job\s*[:\uFF1A]\s*(?<job>[^|;\uFF1B]+)'
    )
    if (-not $match.Success) { return "" }
    return $match.Groups["job"].Value.Trim()
}

function Get-MotionJobFieldValue {
    param(
        [string]$Text,
        [string]$FieldName
    )

    if (-not $Text) { return "" }
    $escapedField = [System.Text.RegularExpressions.Regex]::Escape($FieldName)
    $pattern = "(?i)(?:^|[;\uFF1B])\s*$escapedField\s*[:\uFF1A]\s*(?<value>[^;\uFF1B|]+)"
    $match = [System.Text.RegularExpressions.Regex]::Match($Text, $pattern)
    if (-not $match.Success) { return "" }
    return $match.Groups["value"].Value.Trim()
}

function Convert-VisualTaskTimestampToSeconds {
    param([string]$Timestamp)

    $parts = @($Timestamp.Trim() -split ':')
    if ($parts.Count -eq 2) {
        return ([double]$parts[0] * 60) + [double]$parts[1]
    }
    if ($parts.Count -eq 3) {
        return ([double]$parts[0] * 3600) + ([double]$parts[1] * 60) + [double]$parts[2]
    }
    throw "Unsupported visual-task timestamp: $Timestamp"
}

function Get-VisualTaskTimeRange {
    param([string]$TimeText)

    $match = [System.Text.RegularExpressions.Regex]::Match(
        $TimeText,
        '^(?<start>\d{2}:\d{2}(?::\d{2})?)\s*-\s*(?<end>\d{2}:\d{2}(?::\d{2})?)$'
    )
    if (-not $match.Success) { return $null }
    return [pscustomobject]@{
        Start = Convert-VisualTaskTimestampToSeconds -Timestamp $match.Groups['start'].Value
        End = Convert-VisualTaskTimestampToSeconds -Timestamp $match.Groups['end'].Value
    }
}

function Normalize-VisualTaskField {
    param([string]$Value)
    if (-not $Value) { return "" }
    return (($Value.Trim().ToLowerInvariant()) -replace '\s+', ' ')
}

function Test-TechnicalExplainerMode {
    param(
        [string]$BeatText,
        [string]$CarryoverText
    )

    $haystack = "$BeatText`n$CarryoverText"
    if ($haystack -match '(?im)^\s*(mode|content\s*mode)\s*[:\uFF1A]\s*technical[- ]explainer\b|^\s*technical\s*contract\s*[:\uFF1A]') {
        return $true
    }
    return ($haystack -match '(?i)(\b(technical|protocol|api|sdk|base64|xor|token|prompt|system\s+prompt|hidden\s+marker|encode|decode|codec|router|routing|permission|call\s+chain)\b|\u6280\u672f|\u673a\u5236|\u534f\u8bae|\u63d0\u793a\u8bcd|\u9690\u85cf|\u7f16\u7801|\u89e3\u7801|\u5b57\u7b26|\u8def\u7531|\u8c03\u7528|\u6743\u9650)')
}

if (-not (Test-Path -LiteralPath $sourceFile)) {
    $issues.Add("Missing draft\web-assets\source-candidates.md. Material search must be completed before HyperFrames assembly.")
} else {
    $sourceText = Get-Content -LiteralPath $sourceFile -Raw -Encoding utf8
    Add-EncodingIssueIfNeeded -Text $sourceText -Label "source-candidates.md"
    $sourceLines = @($sourceText -split "`r?`n")
    $roleCount = @($sourceLines | Where-Object {
        $_ -match '(?i)^\s*([-*+]|\|).*\b(prove|explain|advance|texture)\b' -and
        $_ -notmatch '(?i)prove/explain/advance/texture|role labels|should be tagged|tag every'
    }).Count
    $stockOnlyRisk = ($sourceText -match '(?i)Pexels|stock') -and ($sourceText -notmatch '(?i)YouTube|Bilibili|Douyin|X/Twitter|X\b|Twitter|Xiaohongshu|GitHub|official|product recording|screen recording|\u5f55\u5c4f|\u5b98\u65b9|\u6296\u97f3|\u5c0f\u7ea2\u4e66|B\u7ad9|\u54d4\u54e9|\u7f51\u9875\u8bc1\u636e')

    if ($roleCount -lt 6) {
        $issues.Add("source-candidates.md has fewer than 6 role labels. Each candidate should be tagged prove/explain/advance/texture before use.")
    }

    if ($stockOnlyRisk) {
        $issues.Add("source-candidates.md appears stock/Pexels-heavy without enough non-stock source trail. Add official/product/social/video/search evidence or record why channels failed.")
    }
}

if (-not (Test-Path -LiteralPath $beatMapFile)) {
    $issues.Add("Missing draft\visual-plan\material-beat-map.md. A video must have a beat-level material plan before composition.")
} else {
    $beatText = Get-Content -LiteralPath $beatMapFile -Raw -Encoding utf8
    Add-EncodingIssueIfNeeded -Text $beatText -Label "material-beat-map.md"
    $beatTables = @(Get-MaterialBeatTable -BeatText $beatText | Where-Object { $null -ne $_ })
    $beats = if ($beatTables.Count -gt 0) { @($beatTables | ForEach-Object { $_.Rows }) } else { @() }

    if ($beats.Count -eq 0) {
        $issues.Add("material-beat-map.md has no parseable beat table. Include columns for Job, Material, and Motion Treatment.")
    }

    $malformedRows = @($beats | Where-Object { $_.Malformed })
    if ($malformedRows.Count -gt 0) {
        $examples = ($malformedRows | Select-Object -First 3 | ForEach-Object { $_.Raw }) -join " / "
        $issues.Add("material-beat-map.md has malformed beat rows missing Job, Material, or Motion cells. Rows: $examples")
    }

    if ($beats.Count -gt 0 -and $beats.Count -lt 6) {
        $issues.Add("material-beat-map.md has fewer than 6 timed beats. Split the video into roughly 8-12s material beats.")
    }

    $placeholderRows = @($beats | Where-Object { Test-PlaceholderText -Text $_.Raw })
    if ($placeholderRows.Count -gt 0) {
        $examples = ($placeholderRows | Select-Object -First 3 | ForEach-Object { $_.Raw }) -join " / "
        $issues.Add("material-beat-map.md still contains template placeholder rows. Replace TODO/TBD or Chinese placeholder beats with real spoken beats, source paths, motion jobs, and fallback notes before QA. Rows: $examples")
    }

    $dynamicRows = @($beats | Where-Object { ($_.Material + " " + $_.Motion) -match '(?i)(dynamic|motion|video|screen recording|product demo|youtube|douyin|bilibili|camera|workflow motion|animated|moving|carousel|scroll|pan|zoom)' })
    if ($beats.Count -gt 0 -and $dynamicRows.Count -lt [math]::Ceiling($beats.Count * 0.5)) {
        $issues.Add("Less than half of material beats contain a dynamic/motion source. This risks a knowledge-card/PPT draft.")
    }

    $cardRows = @($beats | Where-Object { $_.Material -match '(?i)(knowledge-card|card-led|static|screenshot|image-card|diagram-led)' })
    if ($beats.Count -gt 0 -and $cardRows.Count -gt [math]::Floor($beats.Count * 0.35)) {
        $issues.Add("Too many beats are card/static-led. Replace some with dynamic internet/product/workflow material.")
    }

    $missingJobs = @($beats | Where-Object { $_.Job -notmatch '\b(prove|explain|advance|texture)\b' })
    if ($missingJobs.Count -gt 0) {
        $issues.Add("Some material beats do not declare prove/explain/advance/texture jobs.")
    }

    $longStaticRisk = @($beats | Where-Object { $_.Material -match '(?i)(knowledge-card|card-led|static|screenshot|image-card|diagram-led)' -and $_.Motion -notmatch '(?i)(zoom|highlight|mask|pan|camera|motion|moving|animated|scroll)' })
    if ($longStaticRisk.Count -gt 0) {
        $issues.Add("Static/card/screenshot beats must declare motion treatment such as zoom, pan, highlight, mask, or a second moving layer.")
    }

    $semanticMotionPattern = '(?i)(\b(enter|entrance|entrances|split|route|compress|connect|verify|fail|resolve|complete|block|sort|classify|flow|transform|state|draw|reveal|compare|highlight)\b|\u8fdb\u5165|\u8fdb\u573a|\u5206\u7c7b|\u62c6\u5206|\u538b\u7f29|\u8fde\u63a5|\u8def\u7531|\u70b9\u4eae|\u9a8c\u8bc1|\u5931\u8d25|\u5b8c\u6210|\u963b\u65ad|\u6392\u5e8f|\u7b5b\u9009|\u6d41\u52a8|\u72b6\u6001|\u53d8\u6210|\u5c55\u5f00|\u6536\u675f|\u5f52\u6863|\u5f39\u51fa|\u7a7f\u8fc7|\u6c47\u5165|\u63a8\u51fa|\u6253\u52fe|\u901a\u8fc7)'
    $abstractTermPattern = '(?i)(\u8d44\u4ea7|\u6d41\u7a0b|\u5165\u53e3|\u98ce\u9669|\u6210\u672c|\u4fe1\u4efb|\u79c1\u57df|\u7cfb\u7edf|\u5de5\u5177|\u670d\u52a1|\u5185\u5bb9|\u6a21\u578b|\u80fd\u529b|\u77e5\u8bc6\u5e93|\u6267\u884c\u5c42|\u98de\u8f6e|\u5de5\u4f5c\u6d41|\u9a8c\u6536|\u89c4\u5219|\u8d44\u4ea7\u5316|\b(agent|workflow|asset|risk|cost|trust|system|capability|knowledge\s*base)\b)'
    $explainRows = @($beats | Where-Object { $_.Job -match '(?i)\bexplain\b|\u89e3\u91ca|\u673a\u5236|\u8bf4\u660e' })
    $strictMotionJobMode = Test-StrictMotionJobMode -VideoRoot $root -BeatText $beatText
    $motionJobSchemaV11Mode = Test-MotionJobSchemaV11Mode -BeatText $beatText
    $visualTaskV1Mode = Test-VisualTaskV1Mode -BeatText $beatText

    if ($visualTaskV1Mode -and $beats.Count -gt 0) {
        $missingLineIds = @($beats | Where-Object { $_.LineId -notmatch '(?i)^LINE\d{2,}$' })
        if ($missingLineIds.Count -gt 0) {
            $examples = ($missingLineIds | Select-Object -First 3 | ForEach-Object { $_.Raw }) -join " / "
            $issues.Add("visual-task-v1 requires every spoken sentence/semantic unit to have a stable LINE## ID. Rows: $examples")
        }

        $missingTimes = @($beats | Where-Object { $_.Time -notmatch '^\d{2}:\d{2}(?::\d{2})?\s*-\s*\d{2}:\d{2}(?::\d{2})?$' })
        if ($missingTimes.Count -gt 0) {
            $examples = ($missingTimes | Select-Object -First 3 | ForEach-Object { $_.Raw }) -join " / "
            $issues.Add("visual-task-v1 requires an exact spoken time range for every LINE##. Rows: $examples")
        }

        $missingTaskIds = @($beats | Where-Object { $_.TaskId -notmatch '(?i)^VT\d{2,}$' })
        if ($missingTaskIds.Count -gt 0) {
            $examples = ($missingTaskIds | Select-Object -First 3 | ForEach-Object { $_.Raw }) -join " / "
            $issues.Add("visual-task-v1 requires every line to map to a VT## task ID. Consecutive lines may share one VT## only when the same visible subject/action is intentional. Rows: $examples")
        }

        $invalidVisualTasks = @($beats | Where-Object { $_.VisualTask -notmatch '(?i)^(prove|explain|analogize|transition|close)$' })
        if ($invalidVisualTasks.Count -gt 0) {
            $examples = ($invalidVisualTasks | Select-Object -First 3 | ForEach-Object { $_.Raw }) -join " / "
            $issues.Add("visual-task-v1 requires one primary visual task per line: prove, explain, analogize, transition, or close. Rows: $examples")
        }

        $textureOnlyTasks = @($beats | Where-Object { $_.Job -match '(?i)^\s*texture\s*$' })
        if ($textureOnlyTasks.Count -gt 0) {
            $examples = ($textureOnlyTasks | Select-Object -First 3 | ForEach-Object { $_.Raw }) -join " / "
            $issues.Add("Texture is an auxiliary material role and cannot be the only visual coverage for a spoken line. Rows: $examples")
        }

        $duplicateLineIds = @($beats | Group-Object { ([string]$_.LineId).ToUpperInvariant() } | Where-Object { $_.Name -and $_.Count -gt 1 })
        if ($duplicateLineIds.Count -gt 0) {
            $issues.Add("visual-task-v1 requires unique LINE## IDs. Duplicates: $($duplicateLineIds.Name -join ', ')")
        }

        $sharedTaskGroups = @($beats | Group-Object { ([string]$_.TaskId).ToUpperInvariant() } | Where-Object { $_.Name -and $_.Count -gt 1 })
        foreach ($group in $sharedTaskGroups) {
            $entries = @()
            for ($beatIndex = 0; $beatIndex -lt $beats.Count; $beatIndex++) {
                if (([string]$beats[$beatIndex].TaskId).ToUpperInvariant() -eq $group.Name) {
                    $entries += [pscustomobject]@{ Index = $beatIndex; Beat = $beats[$beatIndex] }
                }
            }

            for ($entryIndex = 1; $entryIndex -lt $entries.Count; $entryIndex++) {
                if ($entries[$entryIndex].Index -ne ($entries[$entryIndex - 1].Index + 1)) {
                    $issues.Add("Shared visual task $($group.Name) must belong to consecutive LINE## rows. Lines: $((@($entries | ForEach-Object { $_.Beat.LineId })) -join ', ')")
                    break
                }
            }

            $taskKinds = @($entries | ForEach-Object { Normalize-VisualTaskField $_.Beat.VisualTask } | Sort-Object -Unique)
            if ($taskKinds.Count -ne 1) {
                $issues.Add("Shared visual task $($group.Name) must keep one visual-task type. Actual: $($taskKinds -join ', ')")
            }

            $actions = @($entries | ForEach-Object { Normalize-VisualTaskField (Get-MotionJobStatement -Text $_.Beat.Motion) } | Sort-Object -Unique)
            $subjects = @($entries | ForEach-Object { Normalize-VisualTaskField (Get-MotionJobFieldValue -Text $_.Beat.Motion -FieldName 'subject') } | Sort-Object -Unique)
            if ($actions.Count -ne 1 -or [string]::IsNullOrWhiteSpace($actions[0]) -or $subjects.Count -ne 1 -or [string]::IsNullOrWhiteSpace($subjects[0])) {
                $issues.Add("Shared visual task $($group.Name) must keep the same explicit visible action and subject across its LINE## rows.")
            }

            for ($entryIndex = 1; $entryIndex -lt $entries.Count; $entryIndex++) {
                $previousRange = Get-VisualTaskTimeRange -TimeText $entries[$entryIndex - 1].Beat.Time
                $currentRange = Get-VisualTaskTimeRange -TimeText $entries[$entryIndex].Beat.Time
                if ($null -eq $previousRange -or $null -eq $currentRange) { continue }
                $gap = $currentRange.Start - $previousRange.End
                if ($gap -lt -0.5 -or $gap -gt 1.0) {
                    $issues.Add("Shared visual task $($group.Name) must use a continuous time window (allowed gap: -0.5s to 1.0s). Lines: $($entries[$entryIndex - 1].Beat.LineId), $($entries[$entryIndex].Beat.LineId); gap=$([math]::Round($gap, 2))s")
                }
            }
        }
    }
    $rowsNeedingMotionJobField = @($beats | Where-Object {
        $jobText = [string]$_.Job
        $isExplainLike = $jobText -match '(?i)\bexplain\b|\u89e3\u91ca|\u673a\u5236|\u8bf4\u660e'
        $isPureProofOrTexture = (
            $jobText -match '(?i)\b(prove|texture)\b' -and
            $jobText -notmatch '(?i)\b(explain|advance)\b|\u89e3\u91ca|\u673a\u5236|\u8bf4\u660e'
        )
        $isAbstractPlanningBeat = (
            -not $isPureProofOrTexture -and
            $_.Narrative -match $abstractTermPattern
        )
        $isExplainLike -or $isAbstractPlanningBeat
    })
    if ($strictMotionJobMode -and $rowsNeedingMotionJobField.Count -gt 0) {
        $missingMotionJobField = @($rowsNeedingMotionJobField | Where-Object {
            -not (Get-MotionJobStatement -Text $_.Motion)
        })
        if ($missingMotionJobField.Count -gt 0) {
            $examples = ($missingMotionJobField | Select-Object -First 3 | ForEach-Object { $_.Raw }) -join " / "
            $issues.Add("Strict motion-job contract: explain or abstract beats must include 'motion job:' inside the Motion column. Example format: motion job: split old path into steps; route request into result. Rows: $examples")
        }

        $weakMotionJobField = @($rowsNeedingMotionJobField | Where-Object {
            $motionJob = Get-MotionJobStatement -Text $_.Motion
            $motionJob -and $motionJob -notmatch $semanticMotionPattern
        })
        if ($weakMotionJobField.Count -gt 0) {
            $examples = ($weakMotionJobField | Select-Object -First 3 | ForEach-Object { $_.Raw }) -join " / "
            $issues.Add("Strict motion-job contract: 'motion job:' must name a semantic action such as enter, split, route, compress, connect, verify, fail, or resolve. Rows: $examples")
        }
    }

    if ($motionJobSchemaV11Mode -and $rowsNeedingMotionJobField.Count -gt 0) {
        $missingV11Fields = @($rowsNeedingMotionJobField | Where-Object {
            -not (Get-MotionJobFieldValue -Text $_.Motion -FieldName "motion job") -or
            -not (Get-MotionJobFieldValue -Text $_.Motion -FieldName "subject") -or
            -not (Get-MotionJobFieldValue -Text $_.Motion -FieldName "change") -or
            -not (Get-MotionJobFieldValue -Text $_.Motion -FieldName "fallback")
        })
        if ($missingV11Fields.Count -gt 0) {
            $examples = ($missingV11Fields | Select-Object -First 3 | ForEach-Object { $_.Raw }) -join " / "
            $issues.Add("motion-job-v1.1 requires explain or abstract beats to include fields in the Motion column: motion job: <action>; subject: <visible object>; change: <from state -> to state>; fallback: <fallback plan>. Rows: $examples")
        }

        $weakChangeFields = @($rowsNeedingMotionJobField | Where-Object {
            $change = Get-MotionJobFieldValue -Text $_.Motion -FieldName "change"
            $change -and $change -notmatch '(?i)(->|=>|\u2192|\bto\b|\u5230|\u53d8\u6210|\u8f6c\u6210)'
        })
        if ($weakChangeFields.Count -gt 0) {
            $examples = ($weakChangeFields | Select-Object -First 3 | ForEach-Object { $_.Raw }) -join " / "
            $issues.Add("motion-job-v1.1 change fields must describe a visible state change, for example 'question -> cited proof' or 'scattered assets -> callable path'. Rows: $examples")
        }
    }

    $technicalExplainerMode = Test-TechnicalExplainerMode -BeatText $beatText -CarryoverText $carryoverText
    if ($technicalExplainerMode -and $explainRows.Count -gt 0) {
        $technicalFieldChecks = @(
            [pscustomobject]@{
                Label = "process visual"
                Pattern = '(?i)(process\s*visual|mechanism\s*process|visible\s*process)\s*[:\uFF1A]|\u8fc7\u7a0b\u89c6\u89c9\s*[:\uFF1A]|\u673a\u5236\u8fc7\u7a0b\s*[:\uFF1A]'
                Hint = "process visual: <characters/state/chart/path that visibly changes>"
            },
            [pscustomobject]@{
                Label = "entity anchor"
                Pattern = '(?i)(entity\s*anchor|source\s*anchor|company\s*anchor|tool\s*anchor)\s*[:\uFF1A]|\u5b9e\u4f53\u951a\u70b9\s*[:\uFF1A]|\u6765\u6e90\u951a\u70b9\s*[:\uFF1A]|\u5de5\u5177\u951a\u70b9\s*[:\uFF1A]'
                Hint = "entity anchor: <official screenshot/product UI/repo page/logo/text-badge or explicit exemption>"
            },
            [pscustomobject]@{
                Label = "key term emphasis"
                Pattern = '(?i)(key\s*term|keyword|term\s*emphasis|key\s*phrase)\s*[:\uFF1A]|\u5173\u952e\u8bcd\s*[:\uFF1A]|\u5173\u952e\u672f\u8bed\s*[:\uFF1A]|\u6280\u672f\u8bcd\s*[:\uFF1A]|\u672f\u8bed\u5f3a\u8c03\s*[:\uFF1A]'
                Hint = "key term: <term to zoom/highlight/focus/underline>"
            },
            [pscustomobject]@{
                Label = "closing thesis"
                Pattern = '(?i)(closing\s*thesis|final\s*thesis|ending\s*thesis|closing\s*beat)\s*[:\uFF1A]|\u7ed3\u5c3e\u89c2\u70b9\s*[:\uFF1A]|\u6536\u675f\u89c2\u70b9\s*[:\uFF1A]|\u7ed3\u5c3e\u6536\u675f\s*[:\uFF1A]'
                Hint = "closing thesis: <one audience-facing sentence for the final visual>"
            }
        )

        foreach ($check in $technicalFieldChecks) {
            if ($beatText -notmatch $check.Pattern) {
                $issues.Add("Technical explainer contract: material-beat-map.md must declare '$($check.Label)' for mechanism-heavy videos. Add a field such as '$($check.Hint)' in the beat map. This only checks declared planning fields; visual quality remains a human frame-review gate.")
            }
        }
    }

    $abstractRowsMissingMotionJob = @($beats | Where-Object {
        $jobText = [string]$_.Job
        $isPureProofOrTexture = (
            $jobText -match '(?i)\b(prove|texture)\b' -and
            $jobText -notmatch '(?i)\b(explain|advance)\b|\u89e3\u91ca|\u673a\u5236|\u8bf4\u660e'
        )
        $needsSemanticMotion = (-not $isPureProofOrTexture -and $_.Narrative -match $abstractTermPattern)
        $needsSemanticMotion -and
        ($_.Job + " " + $_.Motion + " " + $_.Material) -notmatch $semanticMotionPattern
    })
    if ($abstractRowsMissingMotionJob.Count -gt 0) {
        $examples = ($abstractRowsMissingMotionJob | Select-Object -First 3 | ForEach-Object { $_.Raw }) -join " / "
        $issues.Add("Core abstract terms need semantic motion jobs, not only labels or generic cards. Add actions such as enter, split, route, compress, connect, verify, fail, or resolve. Examples: $examples")
    }

    $semanticMotionRows = @($explainRows | Where-Object { ($_.Motion + " " + $_.Material) -match $semanticMotionPattern })
    if ($explainRows.Count -ge 2 -and $semanticMotionRows.Count -eq 0) {
        $issues.Add("Explain beats do not declare any semantic motion job. Mechanism-heavy sections need visible state changes, routing, compression, connection, verification, failure, or resolution.")
    }
}

$visualTaskContractMode = Test-VisualTaskV1Mode -BeatText $beatText
if ($visualTaskContractMode) {
    if (-not $sourceText -or $sourceText -notmatch '(?i)agent-reach-material-v1') {
        $issues.Add("visual-task-v1 requires source-candidates.md to use the agent-reach-material-v1 external sourcing contract.")
    } else {
        $sourceStatusMatch = [System.Text.RegularExpressions.Regex]::Match(
            $sourceText,
            '(?im)^\s*-?\s*External\s+sourcing\s+status\s*[:\uFF1A]\s*(?<status>not-assessed|sourced|exhausted|blocked|not-needed)\s*$'
        )
        if (-not $sourceStatusMatch.Success) {
            $issues.Add("source-candidates.md must declare External sourcing status: sourced, exhausted, blocked, or not-needed.")
        } else {
            $sourceStatus = $sourceStatusMatch.Groups["status"].Value.ToLowerInvariant()
            if ($sourceStatus -eq "not-assessed") {
                $issues.Add("Agent Reach external sourcing is still not-assessed. Run channel preflight and choose sourced, exhausted, blocked, or not-needed.")
            } elseif ($sourceStatus -eq "sourced") {
                $candidateMatches = [System.Text.RegularExpressions.Regex]::Matches(
                    $sourceText,
                    '(?ms)^###\s+\d+\..*?(?=^###\s+\d+\.|\z)'
                )
                $acceptedCandidates = @($candidateMatches | Where-Object {
                    $_.Value -match '(?im)^\s*-\s*Status\s*[:\uFF1A]\s*(accepted|selected|ready|downloaded|sourced)\s*$'
                })
                if ($acceptedCandidates.Count -eq 0) {
                    $issues.Add("Agent Reach sourced status requires at least one candidate block with Status: accepted/selected/ready/downloaded/sourced.")
                }
                $requiredSourceEvidence = @(
                    [pscustomobject]@{ Label = "LINE## and time"; Pattern = '(?im)^[ \t]*-[ \t]*Spoken[ \t]+line[ \t]+ID[ \t]*/[ \t]*time[ \t]*:[ \t]*LINE\d{2,}\b[^\r\n]+\r?$' },
                    [pscustomobject]@{ Label = "visual task"; Pattern = '(?im)^[ \t]*-[ \t]*Visual[ \t]+task[ \t]*:[ \t]*(prove|explain|analogize|transition|close)[ \t]*\r?$' },
                    [pscustomobject]@{ Label = "Agent Reach route/command"; Pattern = '(?im)^[ \t]*-[ \t]*Agent[ \t]+Reach[ \t]+route[ \t]*/[ \t]*command[ \t]*:[ \t]*\S[^\r\n]*\r?$' },
                    [pscustomobject]@{ Label = "search query"; Pattern = '(?im)^[ \t]*-[ \t]*Search[ \t]+query[ \t]*:[ \t]*\S[^\r\n]*\r?$' },
                    [pscustomobject]@{ Label = "source URL"; Pattern = '(?im)^[ \t]*-[ \t]*Source[ \t]+URL[ \t]*:[ \t]*https?://\S+[ \t]*\r?$' },
                    [pscustomobject]@{ Label = "useful timestamp/page region"; Pattern = '(?im)^[ \t]*-[ \t]*Useful[ \t]+source[ \t]+timestamp[ \t]*/[ \t]*page[ \t]+region[ \t]*:[ \t]*\S[^\r\n]*\r?$' },
                    [pscustomobject]@{ Label = "sentence alignment"; Pattern = '(?im)^[ \t]*-[ \t]*Why[ \t]+it[ \t]+aligns[ \t]+with[ \t]+the[ \t]+spoken[ \t]+sentence[ \t]*:[ \t]*\S[^\r\n]*\r?$' }
                )
                foreach ($candidate in $acceptedCandidates) {
                    $candidateText = $candidate.Value
                    $candidateHeading = (($candidateText -split "`r?`n")[0]).Trim()
                    foreach ($check in $requiredSourceEvidence) {
                        if ($candidateText -notmatch $check.Pattern) {
                            $issues.Add("Agent Reach accepted candidate '$candidateHeading' is missing evidence: $($check.Label).")
                        }
                    }

                    $candidateLineMatch = [System.Text.RegularExpressions.Regex]::Match($candidateText, '(?im)^\s*-\s*Spoken\s+line\s+ID\s*/\s*time\s*:\s*(?<line>LINE\d{2,})\b')
                    if ($candidateLineMatch.Success -and $beats.Count -gt 0) {
                        $candidateLineId = $candidateLineMatch.Groups['line'].Value.ToUpperInvariant()
                        if (-not ($beats | Where-Object { ([string]$_.LineId).ToUpperInvariant() -eq $candidateLineId })) {
                            $issues.Add("Agent Reach accepted candidate '$candidateHeading' references $candidateLineId, but that line does not exist in material-beat-map.md.")
                        }
                    }

                    $routeMatch = [System.Text.RegularExpressions.Regex]::Match($candidateText, '(?im)^\s*-\s*Agent\s+Reach\s+route\s*/\s*command\s*:\s*(?<route>\S[^\r\n]*)$')
                    if ($routeMatch.Success) {
                        $route = $routeMatch.Groups['route'].Value.Trim()
                        foreach ($knownCommand in @('agent-reach', 'mcporter', 'gh', 'yt-dlp')) {
                            if ($route -match ("(?i)^" + [regex]::Escape($knownCommand) + "(?:\s|$)") -and -not (Get-Command $knownCommand -ErrorAction SilentlyContinue)) {
                                $issues.Add("Agent Reach accepted candidate '$candidateHeading' claims unavailable command '$knownCommand'. Record the actual fallback route instead.")
                            }
                        }
                    }
                }
            } elseif ($sourceStatus -in @("exhausted", "blocked")) {
                if ($sourceText -notmatch '(?im)^[ \t]*-?[ \t]*Channel[ \t]+availability[ \t]+summary[ \t]*[:\uFF1A][ \t]*\S[^\r\n]*$') {
                    $issues.Add("Agent Reach $sourceStatus status must record the channel availability/preflight result.")
                }
                if ($sourceText -notmatch '(?im)^[ \t]*-?[ \t]*Search[ \t]+fallback[ \t]*[:\uFF1A][ \t]*\S[^\r\n]*$') {
                    $issues.Add("Agent Reach $sourceStatus status must record the next sourcing or generated-media fallback.")
                }
            }
        }
    }
}

$generatedPlanReferenced = $beatText -match '(?i)(IMG\d{2}|MOV\d{2}|motion-required|generated[- ]motion\s+asset|(?:required|must)\s+(?:Jimeng|Seedance|\u5373\u68a6|\u751f\u56fe))'
if (-not (Test-Path -LiteralPath $generatedMotionPlanFile)) {
    if ($generatedPlanReferenced -or $visualTaskContractMode) {
        $issues.Add("visual-task/generated-media planning requires draft\visual-plan\generated-motion-asset-plan.md with a not-needed or required branch decision.")
    }
} else {
    $generatedPlanText = Get-Content -LiteralPath $generatedMotionPlanFile -Raw -Encoding utf8
    Add-EncodingIssueIfNeeded -Text $generatedPlanText -Label "generated-motion-asset-plan.md"

    $readinessContractMode = $generatedPlanText -match '(?im)^\s*-?\s*Contract\s*[:\uFF1A]\s*generated-material-readiness-v1\s*$'
    $requiresGeneratedBranchDecision = $visualTaskContractMode -or $generatedPlanReferenced -or $readinessContractMode -or $generatedPlanText -match '(?i)generated-motion-asset-v2'
    if ($requiresGeneratedBranchDecision) {
        $branchMatch = [System.Text.RegularExpressions.Regex]::Match(
            $generatedPlanText,
            '(?im)^\s*-?\s*Generation\s+branch\s*[:\uFF1A]\s*(?<status>not-assessed|not-needed|required)\s*$'
        )
        if (-not $branchMatch.Success) {
            $issues.Add("generated-motion-asset-plan.md must declare 'Generation branch: not-needed' or 'Generation branch: required' after checking external and internal material coverage.")
        } else {
            $branchStatus = $branchMatch.Groups["status"].Value.ToLowerInvariant()
            $readinessStatus = Get-DeclaredFieldValue -Text $generatedPlanText -Name "Material readiness"
            if ($readinessStatus) { $readinessStatus = $readinessStatus.ToLowerInvariant() }
            $validReadiness = @("sourcing", "prompt-pack-ready", "awaiting-user-stills", "stills-received", "motion-planned", "motion-ready", "complete")

            if ($readinessContractMode -and $validReadiness -notcontains $readinessStatus) {
                $issues.Add("generated-material-readiness-v1 requires Material readiness: sourcing, prompt-pack-ready, awaiting-user-stills, stills-received, motion-planned, motion-ready, or complete.")
            }

            if ($branchStatus -eq "not-assessed") {
                $materialNextAction = "Finish first-hand sourcing and timed coverage audit, then choose Generation branch: not-needed or required."
                $issues.Add("generated-motion-asset-plan.md is still not-assessed. Lock the script, fetch candidates, audit timed external/internal coverage, then choose not-needed or required.")
            } elseif ($branchStatus -eq "not-needed") {
                if ($readinessContractMode -and $readinessStatus -ne "complete") {
                    $materialNextAction = "Record Material readiness: complete after confirming fetched external/internal assets cover every timed beat."
                    $issues.Add("Generation branch is not-needed, but Material readiness must be complete before Assembly.")
                }
            } elseif ($branchStatus -eq "required") {
                if ($generatedPlanText -notmatch '(?im)^\s*-?\s*Script\s+status\s*[:\uFF1A]\s*locked\s*$') {
                    $issues.Add("Generated-media branch is required, but Script status is not locked.")
                }

                if (-not $readinessContractMode) {
                    if (Test-PlaceholderText -Text $generatedPlanText) {
                        $issues.Add("Generated-media branch is required, but generated-motion-asset-plan.md still contains TODO/TBD or Chinese placeholder text.")
                    }
                    if ($generatedPlanText -notmatch '(?i)IMG\d{2}-[a-z0-9-]+') {
                        $issues.Add("Generated-media branch is required, but no stable IMG##-slug asset ID was found.")
                    }
                    if ($generatedPlanText -notmatch '(?i)(motion-required|local-motion|static-support|reject)') {
                        $issues.Add("Generated-media branch is required, but still assets do not declare motion-required/local-motion/static-support/reject decisions.")
                    }

                    $legacyMotionRequired = $generatedPlanText -match '(?i)motion-required'
                    $legacyMotionRows = @($generatedPlanText -split "`r?`n" | Where-Object { $_ -match '^\s*\|\s*MOV\d{2}-' })
                    if ($legacyMotionRequired -and $legacyMotionRows.Count -eq 0) {
                        $issues.Add("At least one still is motion-required, but no MOV## motion-plan row was found.")
                    }
                    foreach ($motionRow in $legacyMotionRows) {
                        $durationMatch = [System.Text.RegularExpressions.Regex]::Match($motionRow, '(?i)(?<min>\d+(?:\.\d+)?)\s*(?:-|to|\u81f3)?\s*(?<max>\d+(?:\.\d+)?)?\s*(?:s|sec|seconds|\u79d2)')
                        if (-not $durationMatch.Success) {
                            $issues.Add("Motion-plan row must declare a duration of 10 seconds or less: $motionRow")
                            continue
                        }
                        $maxDuration = if ($durationMatch.Groups["max"].Success) { [double]$durationMatch.Groups["max"].Value } else { [double]$durationMatch.Groups["min"].Value }
                        if ($maxDuration -gt 10) {
                            $issues.Add("Jimeng/Seedance motion prompts must be 10 seconds or shorter. Row: $motionRow")
                        }
                    }
                } else {
                    $planImageRows = @(Get-StableAssetRows -Text $generatedPlanText -Prefix "IMG")
                    $motionRows = @(Get-StableAssetRows -Text $generatedPlanText -Prefix "MOV")
                    $promptPackText = ""
                    $promptImageRows = @()
                    $expectedFiles = @{}

                    if ($readinessStatus -eq "sourcing") {
                        $materialNextAction = "Fetch first-hand material, finish the coverage audit, and prepare a surplus still prompt pack only for named gaps."
                        $issues.Add("Material readiness is sourcing. Finish source search and coverage audit before the generated-still handoff.")
                    } else {
                        if (Test-PlaceholderText -Text $generatedPlanText) {
                            $issues.Add("Generated-media plan has advanced beyond sourcing but still contains TODO/TBD or Chinese placeholder text.")
                        }
                        if (-not (Test-Path -LiteralPath $stillPromptPackFile)) {
                            $issues.Add("Required generation branch needs draft\visual-plan\still-image-prompt-pack.md before user handoff.")
                        } else {
                            $promptPackText = Get-Content -LiteralPath $stillPromptPackFile -Raw -Encoding utf8
                            Add-EncodingIssueIfNeeded -Text $promptPackText -Label "still-image-prompt-pack.md"
                            if ((Get-DeclaredFieldValue -Text $promptPackText -Name "Prompt pack status") -ne "ready") {
                                $issues.Add("still-image-prompt-pack.md must declare Prompt pack status: ready before user handoff.")
                            }
                            if (Test-PlaceholderText -Text $promptPackText) {
                                $issues.Add("still-image-prompt-pack.md still contains TODO/TBD or Chinese placeholder text.")
                            }
                            $promptImageRows = @(Get-StableAssetRows -Text $promptPackText -Prefix "IMG")
                        }

                        $minimumStills = Get-DeclaredInteger -Text $generatedPlanText -Name "Minimum coverage stills"
                        $plannedStills = Get-DeclaredInteger -Text $generatedPlanText -Name "Planned still prompts"
                        $requiredSurplus = Get-DeclaredInteger -Text $generatedPlanText -Name "Required surplus stills"
                        if ($null -eq $minimumStills -or $minimumStills -lt 1 -or $null -eq $plannedStills -or $null -eq $requiredSurplus) {
                            $issues.Add("Required generation branch must declare positive Minimum coverage stills plus numeric Planned still prompts and Required surplus stills.")
                        } else {
                            $minimumRequiredSurplus = [Math]::Max(2, [int][Math]::Ceiling($minimumStills * 0.2))
                            if ($requiredSurplus -lt $minimumRequiredSurplus) {
                                $issues.Add("Required surplus stills must be at least max(2, ceil(minimum * 20%)); expected at least $minimumRequiredSurplus for minimum $minimumStills.")
                            }
                            if ($plannedStills -lt ($minimumStills + $requiredSurplus)) {
                                $issues.Add("Planned still prompts must cover minimum plus declared surplus: $minimumStills + $requiredSurplus.")
                            }
                        }

                        $expectedIncoming = Join-Path $root "assets\generated\incoming"
                        $expectedAccepted = Join-Path $root "assets\generated\accepted"
                        $declaredIncoming = Resolve-ProjectDeclaredPath -ProjectRoot $root -PathValue (Get-DeclaredFieldValue -Text $generatedPlanText -Name "Returned stills folder")
                        $declaredAccepted = Resolve-ProjectDeclaredPath -ProjectRoot $root -PathValue (Get-DeclaredFieldValue -Text $generatedPlanText -Name "Accepted stills folder")
                        if (-not (Test-SamePath -Left $declaredIncoming -Right $expectedIncoming)) {
                            $issues.Add("Returned stills folder must resolve exactly to assets\generated\incoming\.")
                        }
                        if (-not (Test-SamePath -Left $declaredAccepted -Right $expectedAccepted)) {
                            $issues.Add("Accepted stills folder must resolve exactly to assets\generated\accepted\.")
                        }
                        if ($promptPackText) {
                            $promptReturn = Resolve-ProjectDeclaredPath -ProjectRoot $root -PathValue (Get-DeclaredFieldValue -Text $promptPackText -Name "Return folder")
                            if (-not (Test-SamePath -Left $promptReturn -Right $expectedIncoming)) {
                                $issues.Add("Still prompt pack must give the user the exact absolute assets\generated\incoming\ return folder.")
                            }
                        }

                        $planIds = @($planImageRows | ForEach-Object { $_.Id } | Sort-Object -Unique)
                        $promptIds = @($promptImageRows | ForEach-Object { $_.Id } | Sort-Object -Unique)
                        if ($planIds.Count -eq 0) {
                            $issues.Add("Required generation branch has no stable IMG##-slug rows.")
                        }
                        if ($null -ne $plannedStills -and ($planIds.Count -ne $plannedStills -or $promptIds.Count -ne $plannedStills)) {
                            $issues.Add("Planned still count must match unique IMG## rows in both generated-motion-asset-plan.md and still-image-prompt-pack.md.")
                        }
                        foreach ($planId in $planIds) {
                            if ($promptIds -notcontains $planId) {
                                $issues.Add("Still prompt pack is missing planned image ID $planId.")
                            }
                            if ($promptPackText -and $promptPackText -notmatch ('(?im)^\s*##\s+Prompt\s*[:\uFF1A]\s*' + [System.Text.RegularExpressions.Regex]::Escape($planId) + '\s*$')) {
                                $issues.Add("Still prompt pack needs a complete '## Prompt: $planId' section.")
                            }
                        }

                        $alternateCount = 0
                        foreach ($promptRow in $promptImageRows) {
                            if ($promptRow.Cells.Count -lt 5) {
                                $issues.Add("Still prompt row is incomplete: $($promptRow.Raw)")
                                continue
                            }
                            $filename = $promptRow.Cells[1].Trim().Trim('`')
                            if ($filename -notmatch ('(?i)^' + [System.Text.RegularExpressions.Regex]::Escape($promptRow.Id) + '\.(png|jpe?g|webp)$')) {
                                $issues.Add("Expected still filename must exactly preserve its IMG##-slug ID: $($promptRow.Raw)")
                            } else {
                                $expectedFiles[$promptRow.Id] = $filename
                            }
                            if ($promptRow.Cells[3] -match '(?i)alternate-for\s*:\s*IMG\d{2}-') { $alternateCount++ }
                        }
                        if ($null -ne $requiredSurplus -and $alternateCount -lt $requiredSurplus) {
                            $issues.Add("Still prompt pack needs at least $requiredSurplus explicit alternate-for rows; found $alternateCount.")
                        }

                        $promptMinimum = if ($promptPackText) { Get-DeclaredInteger -Text $promptPackText -Name "Minimum coverage stills" } else { $null }
                        $promptPlanned = if ($promptPackText) { Get-DeclaredInteger -Text $promptPackText -Name "Planned still prompts" } else { $null }
                        $promptSurplus = if ($promptPackText) { Get-DeclaredInteger -Text $promptPackText -Name "Required surplus stills" } else { $null }
                        if ($promptPackText -and ($promptMinimum -ne $minimumStills -or $promptPlanned -ne $plannedStills -or $promptSurplus -ne $requiredSurplus)) {
                            $issues.Add("Still prompt pack minimum/planned/surplus counts must match generated-motion-asset-plan.md.")
                        }

                        $preIntakeStates = @("prompt-pack-ready", "awaiting-user-stills", "stills-received")
                        $motionPackValue = Get-DeclaredFieldValue -Text $generatedPlanText -Name "Motion-video prompt pack"
                        $resolvedMotionPack = Resolve-ProjectDeclaredPath -ProjectRoot $root -PathValue $motionPackValue
                        $hasEarlyMotionPack = $motionPackValue -and $motionPackValue -notmatch '(?i)^(pending-after-still-intake|not-needed)$' -and (Test-Path -LiteralPath $resolvedMotionPack)
                        $preIntakeException = Get-DeclaredFieldValue -Text $generatedPlanText -Name "Pre-intake motion exception"
                        if ($preIntakeStates -contains $readinessStatus -and ($motionRows.Count -gt 0 -or $hasEarlyMotionPack) -and ([string]::IsNullOrWhiteSpace($preIntakeException) -or $preIntakeException -eq "none")) {
                            $issues.Add("Motion rows or motion prompts were created before still intake. Remove them or document a valid source-image-free Pre-intake motion exception.")
                        }

                        if ($readinessStatus -eq "prompt-pack-ready") {
                            $materialNextAction = "Give the user still-image-prompt-pack.md, the exact assets\generated\incoming\ path, and all expected IMG## filenames; then set awaiting-user-stills."
                            $issues.Add("Material readiness is prompt-pack-ready. Complete the user handoff before advancing.")
                        } elseif ($readinessStatus -eq "awaiting-user-stills") {
                            $materialNextAction = "Wait for every expected IMG## file in assets\generated\incoming\, then set Material readiness: stills-received."
                            $issues.Add("Material readiness is awaiting-user-stills. Assembly remains blocked until the expected images return.")
                        }

                        if ($readinessStatus -eq "stills-received") {
                            foreach ($expectedFile in $expectedFiles.Values) {
                                if (-not (Test-Path -LiteralPath (Join-Path $expectedIncoming $expectedFile))) {
                                    $issues.Add("Expected returned still is missing from assets\generated\incoming\: $expectedFile")
                                }
                            }
                            $materialNextAction = "Inspect every returned image, write source-image-rename-map.md, copy accepted IMG## files to assets\generated\accepted\, then choose motion routes."
                            $issues.Add("Material readiness is stills-received. Finish visual intake before choosing motion or entering Assembly.")
                        }

                        if ($readinessStatus -in @("motion-planned", "motion-ready", "complete")) {
                            $imageIntakeText = ""
                            if (-not (Test-Path -LiteralPath $sourceImageRenameMapFile)) {
                                $issues.Add("Post-intake Material needs draft\visual-plan\source-image-rename-map.md.")
                            } else {
                                $imageIntakeText = Get-Content -LiteralPath $sourceImageRenameMapFile -Raw -Encoding utf8
                                Add-EncodingIssueIfNeeded -Text $imageIntakeText -Label "source-image-rename-map.md"
                                if (Test-PlaceholderText -Text $imageIntakeText) {
                                    $issues.Add("source-image-rename-map.md still contains placeholders.")
                                }
                            }

                            $motionRequiredImageIds = New-Object System.Collections.Generic.List[string]
                            foreach ($imageRow in $planImageRows) {
                                if ($imageRow.Cells.Count -lt 10) {
                                    $issues.Add("Generated still row does not match generated-material-readiness-v1 columns: $($imageRow.Raw)")
                                    continue
                                }
                                $decision = $imageRow.Cells[6].ToLowerInvariant()
                                $owner = $imageRow.Cells[7]
                                if ($decision -notin @("motion-required", "local-motion", "static-support", "reject")) {
                                    $issues.Add("Post-intake still $($imageRow.Id) must declare motion-required, local-motion, static-support, or reject.")
                                    continue
                                }
                                if ($imageIntakeText -and $imageIntakeText -notmatch [System.Text.RegularExpressions.Regex]::Escape($imageRow.Id)) {
                                    $issues.Add("source-image-rename-map.md is missing $($imageRow.Id), including accepted or rejected status.")
                                }
                                if ($decision -ne "reject") {
                                    $acceptedStill = @(Get-ChildItem -LiteralPath $expectedAccepted -File -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -eq $imageRow.Id -and $_.Extension -match '(?i)^\.(png|jpe?g|webp)$' })
                                    if ($acceptedStill.Count -eq 0) {
                                        $issues.Add("Accepted still is missing from assets\generated\accepted\ with canonical ID $($imageRow.Id).")
                                    }
                                }
                                if ($decision -eq "local-motion" -and $owner -notmatch '(?i)HyperFrames') {
                                    $issues.Add("local-motion still $($imageRow.Id) must name HyperFrames as owner.")
                                }
                                if ($decision -eq "motion-required") {
                                    if ($owner -notmatch '(?i)(Jimeng|Seedance|\u5373\u68a6|MiniMax\s*H3|Grok|third-party)') {
                                        $issues.Add("motion-required still $($imageRow.Id) must name Jimeng/Seedance, local MiniMax H3, or the third-party Grok-compatible provider.")
                                    }
                                    $motionRequiredImageIds.Add($imageRow.Id)
                                }
                            }

                            foreach ($sourceImageId in @($motionRequiredImageIds | ForEach-Object { $_ })) {
                                $matchingMotion = @($motionRows | Where-Object { $_.Cells.Count -ge 2 -and $_.Cells[1] -eq $sourceImageId })
                                if ($matchingMotion.Count -eq 0) {
                                    $issues.Add("motion-required still $sourceImageId has no MOV## row after still intake.")
                                }
                            }

                            if ($readinessStatus -eq "motion-planned") {
                                if ($motionRequiredImageIds.Count -gt 0) {
                                    $materialNextAction = "Generate the named MOV## clips with their selected providers, place returns in assets\motion\incoming\ or built-in outputs in assets\motion\raw\, then complete motion intake."
                                    $issues.Add("Material readiness is motion-planned. Required external motion clips have not completed intake.")
                                } else {
                                    $materialNextAction = "No external motion is required. Confirm every accepted still route, set Material readiness: complete, and rerun Material QA."
                                    $issues.Add("Material readiness is motion-planned, but all accepted routes are local/static. Mark complete after confirming the intake map.")
                                }
                            }

                            if ($motionRequiredImageIds.Count -gt 0 -and $readinessStatus -in @("motion-ready", "complete")) {
                                $motionPackValue = Get-DeclaredFieldValue -Text $generatedPlanText -Name "Motion-video prompt pack"
                                $resolvedMotionPack = Resolve-ProjectDeclaredPath -ProjectRoot $root -PathValue $motionPackValue
                                if (-not $motionPackValue -or $motionPackValue -match '(?i)^(pending-after-still-intake|not-needed)$' -or -not (Test-Path -LiteralPath $resolvedMotionPack)) {
                                    $issues.Add("External motion requires an existing Motion-video prompt pack path after still intake.")
                                }
                                $motionPromptText = if ($resolvedMotionPack -and (Test-Path -LiteralPath $resolvedMotionPack)) { Get-Content -LiteralPath $resolvedMotionPack -Raw -Encoding utf8 } else { "" }
                                if ($motionPromptText -and (Test-PlaceholderText -Text $motionPromptText)) {
                                    $issues.Add("Motion-video prompt pack still contains placeholders.")
                                }
                                $motionRenameText = if (Test-Path -LiteralPath $sourceMotionRenameMapFile) { Get-Content -LiteralPath $sourceMotionRenameMapFile -Raw -Encoding utf8 } else { "" }
                                $motionIntakeText = if (Test-Path -LiteralPath $motionVideoIntakeFile) { Get-Content -LiteralPath $motionVideoIntakeFile -Raw -Encoding utf8 } else { "" }
                                if (-not $motionRenameText) { $issues.Add("External motion requires source-motion-rename-map.md.") }
                                if (-not $motionIntakeText) { $issues.Add("External motion requires motion-video-intake.md with ffprobe and visual acceptance evidence.") }

                                foreach ($motionRow in $motionRows) {
                                    if ($motionRow.Cells.Count -lt 9) {
                                        $issues.Add("MOV## row does not match generated-material-readiness-v1 columns: $($motionRow.Raw)")
                                        continue
                                    }
                                    $motionId = $motionRow.Id
                                    $provider = $motionRow.Cells[3]
                                    $durationMatch = [System.Text.RegularExpressions.Regex]::Match($motionRow.Cells[4], '(?i)(?<min>\d+(?:\.\d+)?)\s*(?:-|to|\u81f3)?\s*(?<max>\d+(?:\.\d+)?)?\s*(?:s|sec|seconds|\u79d2)')
                                    if (-not $durationMatch.Success) {
                                        $issues.Add("Motion-plan row must declare a duration of 10 seconds or less: $($motionRow.Raw)")
                                    } else {
                                        $maxDuration = if ($durationMatch.Groups["max"].Success) { [double]$durationMatch.Groups["max"].Value } else { [double]$durationMatch.Groups["min"].Value }
                                        if ($maxDuration -gt 10) { $issues.Add("External motion prompts must be 10 seconds or shorter. Row: $($motionRow.Raw)") }
                                    }
                                    if ($provider -notmatch '(?i)(Jimeng|Seedance|\u5373\u68a6|MiniMax\s*H3|Grok|third-party)') {
                                        $issues.Add("MOV## row must name Jimeng/Seedance, local MiniMax H3, or the third-party Grok-compatible provider: $($motionRow.Raw)")
                                    }
                                    if ($motionPromptText -and $motionPromptText -notmatch [System.Text.RegularExpressions.Regex]::Escape($motionId)) {
                                        $issues.Add("Motion-video prompt pack is missing $motionId.")
                                    }
                                    if ($motionRenameText -and $motionRenameText -notmatch [System.Text.RegularExpressions.Regex]::Escape($motionId)) {
                                        $issues.Add("source-motion-rename-map.md is missing $motionId.")
                                    }
                                    if ($motionIntakeText -and $motionIntakeText -notmatch [System.Text.RegularExpressions.Regex]::Escape($motionId)) {
                                        $issues.Add("motion-video-intake.md is missing $motionId.")
                                    }

                                    $acceptedMotionValue = $motionRow.Cells[8].Trim().Trim('`')
                                    $acceptedMotionPath = Resolve-ProjectDeclaredPath -ProjectRoot $root -PathValue $acceptedMotionValue
                                    if (-not $acceptedMotionPath -or -not (Test-Path -LiteralPath $acceptedMotionPath)) {
                                        $issues.Add("Accepted motion path is missing for ${motionId}: $acceptedMotionValue")
                                    }

                                    if ($provider -match '(?i)(Grok|third-party)') {
                                        $metadataPath = Join-Path (Join-Path $root "assets\motion\raw") ($motionId + ".generation.json")
                                        if (-not (Test-Path -LiteralPath $metadataPath)) {
                                            $issues.Add("Third-party Grok motion $motionId is missing sibling .generation.json provenance.")
                                        } else {
                                            try {
                                                $metadata = Get-Content -LiteralPath $metadataPath -Raw -Encoding utf8 | ConvertFrom-Json
                                                if ($metadata.provider -ne "third-party-grok-compatible" -or [string]::IsNullOrWhiteSpace([string]$metadata.requestId)) {
                                                    $issues.Add("Third-party Grok metadata for $motionId needs provider=third-party-grok-compatible and a non-empty requestId.")
                                                }
                                                if ($metadata.PSObject.Properties.Name -notcontains "officialXaiApi" -or $metadata.officialXaiApi -ne $false) {
                                                    $issues.Add("Third-party Grok metadata for $motionId must explicitly declare officialXaiApi=false.")
                                                }
                                            } catch {
                                                $issues.Add("Third-party Grok metadata is invalid JSON for ${motionId}: $($_.Exception.Message)")
                                            }
                                        }
                                        if (($generatedPlanText + "`n" + $motionIntakeText) -notmatch '(?i)(not\s+(?:the\s+)?official\s+xAI|official\s+xAI\s+API\s*[:\uFF1A]\s*no|\u975e.*xAI.*\u5b98\u65b9)') {
                                            $issues.Add("Third-party Grok intake must acknowledge that the endpoint is not the official xAI API.")
                                        }
                                    }
                                }
                            }

                            if ($readinessStatus -eq "motion-ready") {
                                $materialNextAction = "Finish motion provenance/ffprobe/visual intake, set Material readiness: complete, and rerun Material QA."
                                $issues.Add("Material readiness is motion-ready. Formal Material completion still requires complete intake and readiness: complete.")
                            }
                        }
                    }
                }
            }
        }
    }
}

$stateScript = Join-Path $PSScriptRoot "update-video-project-state.ps1"
if ($issues.Count -gt 0) {
    if (-not $NoStateUpdate -and (Test-Path -LiteralPath $stateScript)) {
        & $stateScript `
            -VideoDir $root `
            -CurrentStage "Material" `
            -StageStatus "blocked" `
            -NextAction $materialNextAction `
            -Blockers @($issues) `
            -Source "test-video-material-mix.ps1" | Out-Null
    }
    Write-Host "Material mix QA failed:"
    foreach ($issue in $issues) {
        Write-Host "- $issue"
    }
    exit 1
}

if (-not $NoStateUpdate -and (Test-Path -LiteralPath $stateScript)) {
    & $stateScript `
        -VideoDir $root `
        -CurrentStage "Material" `
        -StageStatus "complete" `
        -NextAction "Enter Assembly using the accepted LINE## -> VT## -> asset map." `
        -Source "test-video-material-mix.ps1" | Out-Null
}

Write-Host "Material mix QA passed."
