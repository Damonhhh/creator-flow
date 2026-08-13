param(
    [Parameter(Mandatory = $true)]
    [string]$VideoDir,
    [string[]]$ExtraTimestamps = @(),
    [ValidateRange(8, 200)]
    [int]$MaxReviewFrames = 80
)

$ErrorActionPreference = "Stop"
$KeyframeProbeMaxBytes = 512MB

function Resolve-FullPath {
    param([string]$PathValue)
    (Resolve-Path -LiteralPath $PathValue -ErrorAction Stop).Path
}

function Get-FfprobeDuration {
    param([string]$FilePath)
    $duration = & ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 $FilePath
    if (-not $duration) {
        throw "Could not read duration for $FilePath"
    }
    [double]::Parse($duration, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-FfprobeVideoStreamInfo {
    param([string]$FilePath)

    $json = & ffprobe `
        -v error `
        -select_streams v:0 `
        -show_entries stream=codec_name,pix_fmt,width,height,r_frame_rate,avg_frame_rate,color_space,color_transfer,color_primaries `
        -of json `
        $FilePath 2>$null
    $jsonText = @($json) -join "`n"
    if (-not $jsonText) {
        throw "Could not read video stream metadata for $FilePath"
    }

    $parsed = $jsonText | ConvertFrom-Json
    $streams = @($parsed.streams)
    if ($streams.Count -eq 0) { return $null }
    return $streams[0]
}

function Get-FfprobeKeyframeTimes {
    param([string]$FilePath)

    $output = & ffprobe `
        -v error `
        -select_streams v:0 `
        -skip_frame nokey `
        -show_entries frame=best_effort_timestamp_time `
        -of csv=p=0 `
        $FilePath 2>$null

    $times = @()
    foreach ($line in @($output)) {
        $value = ([string]$line).Trim()
        if (-not $value -or $value -eq "N/A") { continue }
        $value = ($value -split ',')[0]
        $parsedValue = 0.0
        if ([double]::TryParse($value, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedValue)) {
            $times += $parsedValue
        }
    }

    return @($times | Sort-Object -Unique)
}

function Get-MaxKeyframeGap {
    param([double[]]$Times)

    if (-not $Times -or $Times.Count -lt 2) { return $null }
    $maxGap = 0.0
    for ($i = 0; $i -lt ($Times.Count - 1); $i++) {
        $gap = $Times[$i + 1] - $Times[$i]
        if ($gap -gt $maxGap) { $maxGap = $gap }
    }
    return $maxGap
}

function Get-IntentionalStillFallbackLabel {
    param([hashtable]$AttributeMap)

    $booleanNames = @(
        "data-intentional-still-fallback",
        "data-intentional-fallback"
    )
    foreach ($name in $booleanNames) {
        if (-not $AttributeMap.ContainsKey($name)) { continue }
        $value = ([string]$AttributeMap[$name]).Trim()
        if (-not $value -or $value -match '^(?i:true|1|yes|intentional|still|hold)$') {
            return $name
        }
    }

    $valueNames = @(
        "data-fallback",
        "data-fallback-mode",
        "data-qa-fallback"
    )
    foreach ($name in $valueNames) {
        if (-not $AttributeMap.ContainsKey($name)) { continue }
        $value = ([string]$AttributeMap[$name]).Trim()
        if ($value -match '(?i)\b(intentional-still|intentional[-_\s]?fallback|hold[-_\s]?last[-_\s]?frame|still[-_\s]?fallback|freeze[-_\s]?frame|poster[-_\s]?fallback)\b') {
            return ("{0}={1}" -f $name, $value)
        }
    }

    if ($AttributeMap.ContainsKey("class")) {
        $classValue = [string]$AttributeMap["class"]
        if ($classValue -match '(?i)\b(intentional-still-fallback|intentional-fallback|hold-last-frame|still-fallback|freeze-frame)\b') {
            return ("class={0}" -f $classValue)
        }
    }

    return $null
}

function Parse-MediaElementsFromHtml {
    param(
        [string]$HtmlPath,
        [string]$TagName
    )

    $content = Get-Content -LiteralPath $HtmlPath -Raw -Encoding utf8
    $pattern = "<$TagName\b(?<attrs>[^>]*)>"
    $attrPattern = '(?<name>[a-zA-Z0-9\-_]+)="(?<value>[^"]*)"'
    $elements = @()

    foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($content, $pattern)) {
        $attrs = $match.Groups['attrs'].Value
        $map = @{}
        foreach ($attrMatch in [System.Text.RegularExpressions.Regex]::Matches($attrs, $attrPattern)) {
            $map[$attrMatch.Groups['name'].Value] = $attrMatch.Groups['value'].Value
        }

        $hasTimeline = (
            $map.ContainsKey('data-start') -and
            $map.ContainsKey('data-duration') -and
            $map.ContainsKey('data-track-index')
        )

        $elements += [pscustomobject]@{
            Tag        = $TagName
            Id         = $map['id']
            HfId       = if ($map.ContainsKey('data-hf-id')) { $map['data-hf-id'] } else { $null }
            Src        = if ($map.ContainsKey('src')) { $map['src'] } else { $null }
            ClassName  = if ($map.ContainsKey('class')) { $map['class'] } else { "" }
            AttributeMap = $map
            HasTimeline = $hasTimeline
            Start      = if ($hasTimeline) { [double]::Parse($map['data-start'], [System.Globalization.CultureInfo]::InvariantCulture) } else { $null }
            Duration   = if ($hasTimeline) { [double]::Parse($map['data-duration'], [System.Globalization.CultureInfo]::InvariantCulture) } else { $null }
            Track      = if ($hasTimeline) { [int]$map['data-track-index'] } else { $null }
            MediaStart = if ($map.ContainsKey('data-media-start')) { [double]::Parse($map['data-media-start'], [System.Globalization.CultureInfo]::InvariantCulture) } else { 0.0 }
            IntentionalStillFallback = $null -ne (Get-IntentionalStillFallbackLabel -AttributeMap $map)
            FallbackLabel = Get-IntentionalStillFallbackLabel -AttributeMap $map
        }
    }

    return $elements
}

function Parse-SceneElementsFromHtml {
    param([string]$HtmlPath)

    $content = Get-Content -LiteralPath $HtmlPath -Raw -Encoding utf8
    $tagPattern = '<(?<tag>[a-zA-Z0-9]+)\b(?<attrs>[^>]*)>'
    $attrPattern = '(?<name>[a-zA-Z0-9\-_]+)="(?<value>[^"]*)"'
    $scenes = @()

    foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($content, $tagPattern)) {
        $map = @{}
        foreach ($attrMatch in [System.Text.RegularExpressions.Regex]::Matches($match.Groups['attrs'].Value, $attrPattern)) {
            $map[$attrMatch.Groups['name'].Value] = $attrMatch.Groups['value'].Value
        }
        if (-not $map.ContainsKey('class') -or [string]$map['class'] -notmatch '(?i)(^|\s)scene(\s|$)') { continue }
        if (-not $map.ContainsKey('data-start') -or -not $map.ContainsKey('data-duration')) { continue }

        $scenes += [pscustomobject]@{
            Id = if ($map.ContainsKey('id')) { $map['id'] } else { '' }
            Start = [double]::Parse($map['data-start'], [System.Globalization.CultureInfo]::InvariantCulture)
            Duration = [double]::Parse($map['data-duration'], [System.Globalization.CultureInfo]::InvariantCulture)
        }
    }

    return $scenes
}

function Parse-TaggedClipsFromHtml {
    param(
        [string]$HtmlPath,
        [string]$TagName
    )

    return @(Parse-MediaElementsFromHtml -HtmlPath $HtmlPath -TagName $TagName |
        Where-Object { $_.HasTimeline })
}

function Get-MediaElementLabel {
    param([object]$Element)

    if ($Element.Id) { return $Element.Id }
    if ($Element.HfId) { return $Element.HfId }
    if ($Element.ClassName) { return $Element.ClassName }
    return $Element.Tag
}

function Test-ExternalMediaSrc {
    param([string]$Src)

    if (-not $Src) { return $false }
    return ($Src -match '^(?i:https?:|//|data:|blob:)')
}

function Resolve-MediaSourcePath {
    param(
        [string]$AssetsRoot,
        [string]$Src
    )

    $relativeSrc = $Src -replace '^\./', ''
    $relativeSrc = $relativeSrc -replace '[?#].*$', ''
    $relativeSrc = $relativeSrc -replace '/', '\'
    $srcPath = Join-Path $AssetsRoot $relativeSrc
    if (Test-Path -LiteralPath $srcPath) {
        return $srcPath
    }

    $fallbackPath = Join-Path $AssetsRoot ([System.IO.Path]::GetFileName($relativeSrc))
    if (Test-Path -LiteralPath $fallbackPath) {
        return $fallbackPath
    }

    return $srcPath
}

function Test-SkippedBackgroundUrl {
    param([string]$Url)

    if (-not $Url) { return $true }
    $trimmed = $Url.Trim()
    if (-not $trimmed) { return $true }

    return ($trimmed -match '(?i)^(https?:|//|data:|blob:|about:|#)' -or $trimmed -match '(?i)^var\(')
}

function Resolve-BackgroundSourcePath {
    param(
        [string]$HyperframesDir,
        [string]$AssetsRoot,
        [string]$BaseDir,
        [string]$Url
    )

    $relativeUrl = $Url.Trim()
    $relativeUrl = $relativeUrl -replace '[?#].*$', ''
    $relativeUrl = $relativeUrl -replace '/', '\'
    if ([System.IO.Path]::IsPathRooted($relativeUrl)) {
        return $relativeUrl
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($BaseDir) {
        $candidates.Add((Join-Path $BaseDir $relativeUrl))
    }
    $candidates.Add((Join-Path $HyperframesDir $relativeUrl))

    $assetRelative = $relativeUrl -replace '^[Aa][Ss][Ss][Ee][Tt][Ss]\\', ''
    $candidates.Add((Join-Path $AssetsRoot $assetRelative))
    $candidates.Add((Join-Path $AssetsRoot ([System.IO.Path]::GetFileName($assetRelative))))

    $uniqueCandidates = @($candidates | Select-Object -Unique)
    foreach ($candidate in $uniqueCandidates) {
        $fullCandidate = [System.IO.Path]::GetFullPath($candidate)
        if (Test-Path -LiteralPath $fullCandidate) {
            return $fullCandidate
        }
    }

    return [System.IO.Path]::GetFullPath($uniqueCandidates[0])
}

function Get-CssBackgroundUrlReferences {
    param(
        [string]$CssText,
        [string]$SourceLabel,
        [string]$BaseDir
    )

    $references = @()
    if (-not $CssText) { return $references }

    $declarationPattern = '(?is)(?<prop>background(?:-image)?|mask-image|border-image|list-style-image)\s*:\s*(?<value>[^;{}]*url\([^)]+\)[^;{}]*)'
    $urlPattern = 'url\(\s*[''"]?(?<url>[^''")]+)[''"]?\s*\)'

    foreach ($declarationMatch in [System.Text.RegularExpressions.Regex]::Matches($CssText, $declarationPattern)) {
        $property = $declarationMatch.Groups['prop'].Value
        $value = $declarationMatch.Groups['value'].Value
        $lineNumber = 1
        if ($declarationMatch.Index -gt 0) {
            $lineNumber = (($CssText.Substring(0, $declarationMatch.Index) -split "`r?`n").Count)
        }

        foreach ($urlMatch in [System.Text.RegularExpressions.Regex]::Matches($value, $urlPattern)) {
            $references += [pscustomobject]@{
                Url         = $urlMatch.Groups['url'].Value.Trim()
                SourceLabel = $SourceLabel
                BaseDir     = $BaseDir
                Property    = $property
                LineNumber  = $lineNumber
            }
        }
    }

    return $references
}

function Test-BackgroundSourcePresence {
    param(
        [string]$HyperframesDir,
        [string]$AssetsRoot,
        [string]$HtmlPath
    )

    $problems = @()
    $references = @()
    $htmlBaseDir = Split-Path -Parent $HtmlPath
    $htmlText = Get-Content -LiteralPath $HtmlPath -Raw -Encoding utf8

    $inlineIndex = 0
    foreach ($styleMatch in [System.Text.RegularExpressions.Regex]::Matches($htmlText, '(?is)\bstyle\s*=\s*(["''])(?<style>.*?)\1')) {
        $inlineIndex += 1
        $references += Get-CssBackgroundUrlReferences `
            -CssText $styleMatch.Groups['style'].Value `
            -SourceLabel ("index.html inline style #{0}" -f $inlineIndex) `
            -BaseDir $htmlBaseDir
    }

    $styleBlockIndex = 0
    foreach ($styleBlockMatch in [System.Text.RegularExpressions.Regex]::Matches($htmlText, '(?is)<style\b[^>]*>(?<css>.*?)</style>')) {
        $styleBlockIndex += 1
        $references += Get-CssBackgroundUrlReferences `
            -CssText $styleBlockMatch.Groups['css'].Value `
            -SourceLabel ("index.html <style> block #{0}" -f $styleBlockIndex) `
            -BaseDir $htmlBaseDir
    }

    $cssFiles = @(Get-ChildItem -LiteralPath $HyperframesDir -Recurse -Filter *.css -File |
        Where-Object { $_.FullName -notmatch '\\(node_modules|renders|dist|build|\.git)\\' })
    foreach ($cssFile in $cssFiles) {
        $cssText = Get-Content -LiteralPath $cssFile.FullName -Raw -Encoding utf8
        $relativeLabel = $cssFile.FullName.Substring($HyperframesDir.Length).TrimStart('\')
        $references += Get-CssBackgroundUrlReferences `
            -CssText $cssText `
            -SourceLabel $relativeLabel `
            -BaseDir $cssFile.DirectoryName
    }

    foreach ($reference in $references) {
        if (Test-SkippedBackgroundUrl -Url $reference.Url) { continue }

        $sourcePath = Resolve-BackgroundSourcePath `
            -HyperframesDir $HyperframesDir `
            -AssetsRoot $AssetsRoot `
            -BaseDir $reference.BaseDir `
            -Url $reference.Url
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            $lineNote = if ($reference.LineNumber) { " line $($reference.LineNumber)" } else { "" }
            $problems += "Missing background media asset: $sourcePath referenced by $($reference.SourceLabel)$lineNote ($($reference.Property): url($($reference.Url))). Background images must use real local assets or remove the style."
        }
    }

    return @($problems | Select-Object -Unique)
}

function Test-MediaSourcePresence {
    param(
        [string]$AssetsRoot,
        [object[]]$Elements
    )

    $problems = @()
    foreach ($element in $Elements) {
        $label = Get-MediaElementLabel -Element $element
        if (-not $element.Src -or [string]::IsNullOrWhiteSpace([string]$element.Src)) {
            $problems += "Blank media slot: $($element.Tag) element $label has no src. Add a real source or remove the media element."
            continue
        }

        if (Test-ExternalMediaSrc -Src $element.Src) { continue }

        $srcPath = Resolve-MediaSourcePath -AssetsRoot $AssetsRoot -Src $element.Src
        if (-not (Test-Path -LiteralPath $srcPath)) {
            $problems += "Missing media asset: $srcPath for $($element.Tag) element $label"
        }
    }
    return $problems
}

function Test-TrackOverlaps {
    param([object[]]$Clips)

    $problems = @()
    $byTrack = $Clips | Group-Object Track
    foreach ($group in $byTrack) {
        $sorted = $group.Group | Sort-Object Start
        for ($i = 0; $i -lt $sorted.Count - 1; $i++) {
            $current = $sorted[$i]
            $next = $sorted[$i + 1]
            $currentEnd = $current.Start + $current.Duration
            if ($currentEnd -gt ($next.Start + 0.0001)) {
                $problems += "Track $($group.Name): $($current.Id) overlaps $($next.Id)"
            }
        }
    }
    return $problems
}

function Test-PlayableDuration {
    param(
        [string]$AssetsRoot,
        [object[]]$Clips
    )

    $problems = @()
    foreach ($clip in $Clips) {
        if (-not $clip.Src) { continue }
        if (Test-ExternalMediaSrc -Src $clip.Src) { continue }
        $srcPath = Resolve-MediaSourcePath -AssetsRoot $AssetsRoot -Src $clip.Src
        if (-not (Test-Path -LiteralPath $srcPath)) {
            continue
        }
        try {
            $duration = Get-FfprobeDuration -FilePath $srcPath
        }
        catch {
            $problems += "Video duration probe failed for clip $($clip.Id): $srcPath"
            continue
        }
        $remaining = $duration - $clip.MediaStart
        if ($remaining + 0.0001 -lt $clip.Duration) {
            $playableUntil = $clip.Start + $remaining
            $hasHandoff = $Clips | Where-Object {
                $_.Id -ne $clip.Id -and
                $_.Src -and
                $_.Start -gt ($clip.Start + 0.05) -and
                $_.Start -le ($playableUntil + 0.25) -and
                $_.Start -lt ($clip.Start + $clip.Duration - 0.05)
            } | Select-Object -First 1

            if (-not $hasHandoff) {
                $label = Get-MediaElementLabel -Element $clip
                if ($clip.IntentionalStillFallback -and $remaining -gt 0.05) {
                    continue
                }
                if ($clip.IntentionalStillFallback) {
                    $problems += "Clip $label declares intentional still fallback ($($clip.FallbackLabel)) but source remaining is only $([math]::Round($remaining,2))s. Use a real still/poster source or a longer clip."
                }
                else {
                    $problems += "Clip $label runs $([math]::Round($clip.Duration,2))s but source remaining is only $([math]::Round($remaining,2))s. Add a handoff clip or mark an intentional still fallback with data-intentional-still-fallback=""true"" or data-fallback=""intentional-still""."
                }
            }
        }
    }
    return $problems
}

function Get-EncodingExceptionData {
    param(
        [string]$VideoRoot,
        [string]$AssetsRoot
    )

    if (-not $VideoRoot) {
        return @{
            HdrApproved = @()
            Path = $null
        }
    }

    $exceptionPath = Join-Path $VideoRoot "review\encoding-exceptions.json"
    if (-not (Test-Path -LiteralPath $exceptionPath)) {
        return @{
            HdrApproved = @()
            Path = $exceptionPath
        }
    }

    try {
        $json = Get-Content -LiteralPath $exceptionPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Could not parse encoding exception file: $exceptionPath"
    }

    $approved = @()
    foreach ($propertyName in @("hdrApproved", "approvedHdrSources", "hdrApprovedSources")) {
        if (-not ($json.PSObject.Properties.Name -contains $propertyName)) { continue }
        foreach ($entry in @($json.$propertyName)) {
            if ($entry -is [string]) {
                $approved += [string]$entry
            }
            elseif ($entry.PSObject.Properties.Name -contains "src") {
                $approved += [string]$entry.src
            }
            elseif ($entry.PSObject.Properties.Name -contains "path") {
                $approved += [string]$entry.path
            }
        }
    }

    $normalized = @()
    foreach ($item in $approved) {
        if (-not $item) { continue }
        $normalized += $item.Trim()
        try {
            $resolved = Resolve-MediaSourcePath -AssetsRoot $AssetsRoot -Src $item.Trim()
            $normalized += [System.IO.Path]::GetFullPath($resolved)
        }
        catch {
            # Keep the raw exception entry; unmatched entries simply do not approve a clip.
        }
    }

    return @{
        HdrApproved = @($normalized | Sort-Object -Unique)
        Path = $exceptionPath
    }
}

function Get-HdrApprovalLabel {
    param(
        [object]$Clip,
        [string]$FullPath,
        [hashtable]$ExceptionData
    )

    $map = $Clip.AttributeMap
    if ($map) {
        foreach ($name in @("data-hdr-approved", "data-encoding-approved", "data-qa-encoding-approved")) {
            if (-not $map.ContainsKey($name)) { continue }
            $value = ([string]$map[$name]).Trim()
            if (-not $value -or $value -match '^(?i:true|1|yes|approved|hdr|hdr-approved)$') {
                return $name
            }
        }

        foreach ($name in @("data-encoding-exception", "data-qa-encoding-exception")) {
            if (-not $map.ContainsKey($name)) { continue }
            $value = ([string]$map[$name]).Trim()
            if ($value -match '(?i)\b(hdr|hlg|bt\.?2020|encoding[-_\s]?approved|approved)\b') {
                return ("{0}={1}" -f $name, $value)
            }
        }
    }

    $approved = @($ExceptionData.HdrApproved)
    if ($approved.Count -eq 0) { return $null }

    $full = [System.IO.Path]::GetFullPath($FullPath)
    foreach ($entry in $approved) {
        if (-not $entry) { continue }
        if ($entry -eq $Clip.Src -or $entry -eq $full) {
            return ("review\encoding-exceptions.json:{0}" -f $entry)
        }
    }

    return $null
}

function Test-VideoEncodingRisk {
    param(
        [string]$AssetsRoot,
        [object[]]$Clips,
        [string]$VideoRoot
    )

    $results = @()
    $seen = @{}
    $exceptionData = Get-EncodingExceptionData -VideoRoot $VideoRoot -AssetsRoot $AssetsRoot
    foreach ($clip in $Clips) {
        if (-not $clip.Src) { continue }
        if (Test-ExternalMediaSrc -Src $clip.Src) { continue }
        $srcPath = Resolve-MediaSourcePath -AssetsRoot $AssetsRoot -Src $clip.Src
        if (-not (Test-Path -LiteralPath $srcPath)) { continue }

        $fullPath = [System.IO.Path]::GetFullPath($srcPath)
        $seenKey = $fullPath.ToLowerInvariant()
        if ($seen.ContainsKey($seenKey)) { continue }
        $seen[$seenKey] = $true

        $label = Get-MediaElementLabel -Element $clip
        try {
            $stream = Get-FfprobeVideoStreamInfo -FilePath $fullPath
        }
        catch {
            $results += [pscustomobject]@{
                Level   = "Warning"
                Message = "Video metadata probe failed for clip ${label}: $fullPath"
            }
            continue
        }
        if ($null -eq $stream) { continue }

        $codec = [string]$stream.codec_name
        $pixFmt = [string]$stream.pix_fmt
        $colorSpace = [string]$stream.color_space
        $colorTransfer = [string]$stream.color_transfer
        $colorPrimaries = [string]$stream.color_primaries

        $isHdrOrBt2020 = (
            $colorTransfer -match '(?i)(arib-std-b67|smpte2084|hlg|pq)' -or
            $colorPrimaries -match '(?i)bt2020' -or
            $colorSpace -match '(?i)bt2020'
        )
        if ($isHdrOrBt2020) {
            $approvalLabel = Get-HdrApprovalLabel -Clip $clip -FullPath $fullPath -ExceptionData $exceptionData
            if ($approvalLabel) {
                $results += [pscustomobject]@{
                    Level   = "Warning"
                    Message = "Video encoding exception: clip $label uses HDR/HLG/BT.2020 metadata but is explicitly approved by $approvalLabel. Confirm the rendered output is SDR-safe before publish."
                }
            }
            else {
                $results += [pscustomobject]@{
                    Level   = "Issue"
                    Message = "Video encoding risk: clip $label uses HDR/HLG/BT.2020 metadata ($codec, $pixFmt, transfer=$colorTransfer, primaries=$colorPrimaries, colorspace=$colorSpace). Re-encode to H.264, 30fps, yuv420p, SDR BT.709 before HyperFrames, or add an explicit encoding exception after manual review."
                }
            }
        }

        $warningParts = @()
        if ($codec -and $codec -ne "h264") {
            $warningParts += "codec=$codec"
        }
        if ($pixFmt -and $pixFmt -notmatch '^(?i)yuvj?420p$') {
            $warningParts += "pix_fmt=$pixFmt"
        }

        try {
            $fileInfo = Get-Item -LiteralPath $fullPath -Force
            if ($fileInfo.Length -gt $KeyframeProbeMaxBytes) {
                $warningParts += ("keyframe probe skipped for large file={0}" -f ([math]::Round($fileInfo.Length / 1MB, 1).ToString([System.Globalization.CultureInfo]::InvariantCulture) + "MB"))
            }
            else {
                $keyframeTimes = @(Get-FfprobeKeyframeTimes -FilePath $fullPath)
                $maxGap = Get-MaxKeyframeGap -Times $keyframeTimes
                if ($null -ne $maxGap -and $maxGap -gt 3.2) {
                    $warningParts += ("max keyframe gap={0}s" -f [math]::Round($maxGap, 2))
                }
            }
        }
        catch {
            $warningParts += "keyframe probe failed"
        }

        if ($warningParts.Count -gt 0) {
            $results += [pscustomobject]@{
                Level   = "Warning"
                Message = "Video preprocessing warning: clip $label has $($warningParts -join ', '). Preferred HyperFrames source is H.264, 30fps, yuv420p, SDR BT.709, with dense keyframes."
            }
        }
    }

    return $results
}

function Test-EvidenceReadabilityRisk {
    param([object[]]$ImageClips)

    $risks = @()
    foreach ($clip in $ImageClips) {
        if (-not $clip.Src) { continue }
        $classText = $clip.ClassName
        $srcText = $clip.Src
        # Tail-frame layers are deliberate post-video handoffs, not evidence boards
        # that need the long-static readability warning below.
        $isMotionTailFrame = (
            $clip.IntentionalStillFallback -or
            $classText -match '(?i)\b(global-motion-tail|motion-tail|hold-last-frame|freeze-frame|still-fallback)\b'
        )
        if ($isMotionTailFrame) { continue }
        $isProofLike = (
            $clip.Id -match 'proof|dashboard|board|evidence' -or
            $srcText -match 'dashboard|findings|screenshot|screen|cover' -or
            $classText -match 'proof|board'
        )
        if (-not $isProofLike) { continue }
        $looksLargeStatic = $clip.Duration -ge 5
        if ($looksLargeStatic) {
            $risks += "Evidence readability risk: image clip $($clip.Id) holds for $([math]::Round($clip.Duration,2))s; verify it is readable and not a cropped contain/cover mistake."
        }
    }
    return $risks
}

function Test-OpeningVisualDensity {
    param(
        [string]$HtmlPath,
        [object[]]$VideoClips
    )

    $problems = @()
    $content = Get-Content -LiteralPath $HtmlPath -Raw -Encoding utf8
    $scene1Match = [System.Text.RegularExpressions.Regex]::Match(
        $content,
        '<section[^>]*id="scene-1"[\s\S]*?</section>'
    )

    if ($scene1Match.Success) {
        $scene1Html = $scene1Match.Value
        $cardCount = [System.Text.RegularExpressions.Regex]::Matches($scene1Html, 'class="[^"]*\bcard\b').Count
        if ($cardCount -gt 2) {
            $problems += "Opening visual overload: scene-1 contains $cardCount card blocks. First screen should have one focal claim and at most two support blocks."
        }
    }

    $openingVideos = @($VideoClips | Where-Object {
        $_.Start -lt 8.0 -and
        ($_.Start + $_.Duration) -gt 1.0 -and
        $_.ClassName -notmatch 'background|grain'
    })
    if ($openingVideos.Count -gt 2) {
        $ids = ($openingVideos | ForEach-Object { $_.Id }) -join ', '
        $problems += "Opening media overload: $($openingVideos.Count) video clips are visible in the first 8s ($ids). Use one primary motion asset plus optional background only."
    }

    return $problems
}

function Test-ProductionNoteLeak {
    param(
        [string]$VideoRoot,
        [string]$HyperframesDir
    )

    $problems = @()
    $scriptFileName = Join-UnicodeChars -Codes @(0x5f55, 0x97f3, 0x7a3f, 0x2e, 0x74, 0x78, 0x74)
    $targets = @(
        (Join-Path (Join-Path $VideoRoot "draft") $scriptFileName),
        (Join-Path $HyperframesDir "captions-data.js"),
        (Join-Path $HyperframesDir "index.html")
    )

    $patterns = @(
        @{ Regex = '\u9875\u9762\u4e0a\u5c55\u793a'; Label = 'page-show-note' },
        @{ Regex = '\u753b\u9762\u91cc\u6211\u4f1a|\u753b\u9762\u91cc\u653e'; Label = 'visual-instruction' },
        @{ Regex = '\u4e0d\u5360\u53e3\u64ad\u65f6\u95f4'; Label = 'not-narration-time' },
        @{ Regex = '\u53e3\u64ad\u4e0d\u8bfb|\u4e0d\u8bfb\u51fa\u6765'; Label = 'do-not-read' },
        @{ Regex = '\u8fd9\u91cc\u505a\u6210|\u505a\u6210\u5361\u7247'; Label = 'make-card-note' },
        @{ Regex = '\u5236\u4f5c\u5907\u6ce8|\u526a\u8f91\u5907\u6ce8|\u7ed9\u526a\u8f91'; Label = 'production/editing-note' },
        @{ Regex = '\u7d20\u6750\u89c4\u5219'; Label = 'material-rule-note' },
        # "内部规则" can be legitimate viewer-facing business language (for example,
        # asking whether company rules may be shared). Only flag it when production
        # or review context makes it an editing instruction.
        @{ Regex = '\u5185\u90e8\s*QA|(?:\u5236\u4f5c|\u526a\u8f91|\u5ba1\u6838|\u5b57\u5e55|\u753b\u9762|\u9879\u76ee)\s*\u5185\u90e8\s*\u89c4\u5219|\u5185\u90e8\s*(?:\u5236\u4f5c|\u526a\u8f91|\u5ba1\u6838|\u5b57\u5e55|\u753b\u9762|\u9879\u76ee)\s*\u89c4\u5219'; Label = 'internal-qa/rule' },
        @{ Regex = '\u53ea\u5141\u8bb8\u7559\u5728|\u81ea\u5236\u753b\u9762\u4e0d\u590d\u8ff0'; Label = 'internal-visual-boundary' },
        @{ Regex = '\u4e0d\u8981\u51fa\u73b0\u5728\u53e3\u64ad'; Label = 'must-not-enter-narration' },
        @{ Regex = '(?i)not\s+for\s+narration'; Label = 'not for narration' },
        @{ Regex = '(?i)editing\s+note|visual\s+note|internal\s+qa'; Label = 'editing/internal note' }
    )

    foreach ($target in $targets) {
        if (-not (Test-Path -LiteralPath $target)) { continue }
        $relative = $target
        if ($target.StartsWith($VideoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relative = $target.Substring($VideoRoot.Length).TrimStart('\')
        }
        $lines = @(Get-Content -LiteralPath $target -Encoding utf8)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = [string]$lines[$i]
            foreach ($pattern in $patterns) {
                if ($line -match $pattern.Regex) {
                    $problems += "Production-note leakage in $relative line $($i + 1): contains '$($pattern.Label)'. Viewer-facing narration, captions, and visible UI must not contain editing instructions."
                    break
                }
            }
        }
    }

    return $problems
}

function Test-NarrationSrtProvenance {
    param(
        [string]$VideoRoot,
        [string]$HyperframesDir
    )

    $problems = @()
    $voiceDir = Join-Path $VideoRoot "assets\voice"
    $appSrt = Join-Path $HyperframesDir "assets\narration.srt"
    if (-not (Test-Path -LiteralPath $voiceDir)) { return $problems }
    if (-not (Test-Path -LiteralPath $appSrt)) { return $problems }

    $speedAudios = @(Get-ChildItem -LiteralPath $voiceDir -Filter "*-1p*.wav" -File -ErrorAction SilentlyContinue)
    if ($speedAudios.Count -eq 0) { return $problems }

    $realignedSrts = @(Get-ChildItem -LiteralPath $voiceDir -Filter "*realigned*.srt" -File -ErrorAction SilentlyContinue)
    $asrSrts = @(Get-ChildItem -LiteralPath $voiceDir -Filter "*asr*.srt" -File -ErrorAction SilentlyContinue)
    if ($realignedSrts.Count -eq 0 -and $asrSrts.Count -eq 0) {
        $problems += "Cloned/speed narration has no ASR or realigned SRT artifact. Do not use a linearly scaled SRT as the spoken timeline."
        return $problems
    }

    if ($realignedSrts.Count -gt 0) {
        $latestRealigned = $realignedSrts | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $appText = (Get-Content -LiteralPath $appSrt -Raw -Encoding utf8).Trim()
        $realignedText = (Get-Content -LiteralPath $latestRealigned.FullName -Raw -Encoding utf8).Trim()
        if ($appText -ne $realignedText) {
            $problems += "HyperFrames assets/narration.srt is not the latest realigned SRT: $($latestRealigned.FullName)"
        }
    }

    return $problems
}

function Normalize-CaptionText {
    param([string]$Text)

    if ($null -eq $Text) { return "" }

    $chars = New-Object System.Collections.Generic.List[char]
    foreach ($char in $Text.ToCharArray()) {
        if ([char]::IsLetterOrDigit($char)) {
            $chars.Add([char]::ToLowerInvariant($char))
        }
    }
    return -join $chars
}

function Test-TerminalPunctuation {
    param([string]$Text)
    if ($null -eq $Text) { return $false }
    $trimmed = $Text.Trim()
    if (-not $trimmed) { return $false }
    $last = [int]$trimmed[$trimmed.Length - 1]
    $terminalCodes = @(0x3002, 0xff01, 0xff1f, 0xff1b, 0xff1a, 0x21, 0x3f, 0x3b, 0x3a)
    return ($terminalCodes -contains $last)
}

function Join-UnicodeChars {
    param([int[]]$Codes)
    return -join ($Codes | ForEach-Object { [char]$_ })
}

function Get-HyperframesCaptions {
    param([string]$HyperframesDir)

    $captionPath = Join-Path $HyperframesDir "captions-data.js"
    if (-not (Test-Path -LiteralPath $captionPath)) {
        return @()
    }

    $raw = Get-Content -LiteralPath $captionPath -Raw -Encoding utf8
    $match = [System.Text.RegularExpressions.Regex]::Match(
        $raw,
        'window\.CAPTIONS\s*=\s*(?<json>\[[\s\S]*?\])\s*;'
    )
    if (-not $match.Success) {
        return @([pscustomobject]@{
            ParseError = "Could not parse HyperFrames captions-data.js"
        })
    }

    $parsed = $match.Groups['json'].Value | ConvertFrom-Json
    foreach ($caption in @($parsed)) {
        Write-Output $caption
    }
    return
}

function Test-CaptionDisplayQuality {
    param(
        [string]$VideoRoot,
        [string]$HyperframesDir
    )

    $problems = @()
    $captions = @(Get-HyperframesCaptions -HyperframesDir $HyperframesDir)
    if ($captions.Count -eq 0) { return $problems }

    if ($captions[0].PSObject.Properties.Name -contains "ParseError") {
        $problems += $captions[0].ParseError
        return $problems
    }

    $scriptFileName = Join-UnicodeChars -Codes @(0x5f55, 0x97f3, 0x7a3f, 0x2e, 0x74, 0x78, 0x74)
    $scriptPath = Join-Path (Join-Path $VideoRoot "draft") $scriptFileName
    if (Test-Path -LiteralPath $scriptPath) {
        $scriptText = Get-Content -LiteralPath $scriptPath -Raw -Encoding utf8
        $captionText = ($captions | ForEach-Object { $_.text }) -join ""
        $scriptNorm = Normalize-CaptionText -Text $scriptText
        $captionNorm = Normalize-CaptionText -Text $captionText
        if ($scriptNorm -and $captionNorm -and $scriptNorm -ne $captionNorm) {
            $problems += "Caption text mismatch: HyperFrames captions-data.js does not match the approved narration script after punctuation/space normalization."
        }
    }

    $suspiciousPairs = @(
        @{ End = (Join-UnicodeChars -Codes @(0x73a9, 0x4e00)); Next = (Join-UnicodeChars -Codes @(0x4e2a)); Label = "wan-yi-ge" },
        @{ End = (Join-UnicodeChars -Codes @(0x8fd9, 0x4e9b, 0x4e1c)); Next = (Join-UnicodeChars -Codes @(0x897f)); Label = "zhe-xie-dong-xi" },
        @{ End = (Join-UnicodeChars -Codes @(0x5b66, 0x8d39, 0x6821)); Next = (Join-UnicodeChars -Codes @(0x533a)); Label = "xue-fei-xiao-qu" },
        @{ End = (Join-UnicodeChars -Codes @(0x4e13, 0x4e1a, 0x5907)); Next = (Join-UnicodeChars -Codes @(0x6ce8)); Label = "zhuan-ye-bei-zhu" },
        @{ End = (Join-UnicodeChars -Codes @(0x63a5, 0x53e3)); Next = "key"; Label = "jie-kou-key" },
        @{ End = "api"; Next = "key"; Label = "API key" },
        @{ End = (Join-UnicodeChars -Codes @(0x6211, 0x514d, 0x8d39)); Next = (Join-UnicodeChars -Codes @(0x6211, 0x597d, 0x5fc3)); Label = "wo-mian-fei-wo-hao-xin" }
    )

    for ($i = 0; $i -lt $captions.Count - 1; $i++) {
        $current = $captions[$i]
        $next = $captions[$i + 1]
        $currentText = ([string]$current.text).Trim()
        $nextText = ([string]$next.text).Trim()
        if (-not $currentText -or -not $nextText) { continue }

        $currentEnd = [double]$current.end
        $nextStart = [double]$next.start
        $gap = $nextStart - $currentEnd
        $nextNorm = Normalize-CaptionText -Text $nextText

        foreach ($pair in $suspiciousPairs) {
            if (
                $currentText.EndsWith($pair.End, [System.StringComparison]::OrdinalIgnoreCase) -and
                $nextText.StartsWith($pair.Next, [System.StringComparison]::OrdinalIgnoreCase)
            ) {
                $problems += "Broken caption phrase near $([math]::Round($current.start,2))s: '$currentText' / '$nextText' splits '$($pair.Label)'."
            }
        }

        if (
            $gap -le 0.35 -and
            -not (Test-TerminalPunctuation -Text $currentText) -and
            $nextNorm.Length -gt 0 -and
            $nextNorm.Length -le 3
        ) {
            $problems += "Suspicious short caption continuation near $([math]::Round($current.start,2))s: '$currentText' / '$nextText'. Merge or resegment display captions on real ASR boundaries."
        }
    }

    return $problems
}

function Test-CaptionAudioAlignmentEvidence {
    param(
        [string]$VideoRoot,
        [string]$HyperframesDir
    )

    $problems = @()
    $captionPath = Join-Path $HyperframesDir "captions-data.js"
    $audioPath = Join-Path $HyperframesDir "assets\audio\narration.wav"
    if (-not (Test-Path -LiteralPath $captionPath)) { return $problems }
    if (-not (Test-Path -LiteralPath $audioPath)) { return $problems }

    $reviewDir = Join-Path $VideoRoot "review"
    $reports = @()
    if (Test-Path -LiteralPath $reviewDir) {
        $reports = @(Get-ChildItem -LiteralPath $reviewDir -Filter "asr-align-report.json" -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending)
    }

    if ($reports.Count -eq 0) {
        $problems += "Caption/audio alignment missing: no ASR alignment report found under review. Rebuild captions from real narration audio before delivery."
        return $problems
    }

    $latestReport = $reports[0]
    $captionFile = Get-Item -LiteralPath $captionPath
    if ($latestReport.LastWriteTime -lt $captionFile.LastWriteTime.AddSeconds(-5)) {
        $problems += "Caption/audio alignment stale: latest ASR alignment report is older than captions-data.js ($($latestReport.FullName))."
        return $problems
    }

    try {
        $report = Get-Content -LiteralPath $latestReport.FullName -Raw -Encoding utf8 | ConvertFrom-Json
    }
    catch {
        $problems += "Caption/audio alignment report is not valid JSON: $($latestReport.FullName)"
        return $problems
    }

    if (-not $report.captions -or [int]$report.captions -le 0) {
        $problems += "Caption/audio alignment report has no caption cues: $($latestReport.FullName)"
    }
    if (-not $report.raw_segments -or @($report.raw_segments).Count -eq 0) {
        $problems += "Caption/audio alignment report has no raw ASR segments: $($latestReport.FullName)"
    }
    if ($report.script_norm_chars -and $report.asr_norm_chars) {
        $scriptChars = [double]$report.script_norm_chars
        $asrChars = [double]$report.asr_norm_chars
        if ($scriptChars -gt 0) {
            $ratio = $asrChars / $scriptChars
            if ($ratio -lt 0.90 -or $ratio -gt 1.10) {
                $problems += "Caption/audio alignment weak: ASR/script character ratio is $([math]::Round($ratio,3)); expected 0.90-1.10."
            }
        }
    }
    else {
        $problems += "Caption/audio alignment report missing script/asr character counts: $($latestReport.FullName)"
    }

    return $problems
}

function Get-LatestRender {
    param([string]$HyperframesDir)
    $renderDirs = @($HyperframesDir, (Join-Path $HyperframesDir "renders")) | Where-Object { Test-Path -LiteralPath $_ }
    $renderFiles = foreach ($dir in $renderDirs) {
        Get-ChildItem -LiteralPath $dir -Filter *.mp4 -File
    }
    $latest = $renderFiles |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $latest) { return $null }
    return $latest.FullName
}

function Get-LatestRenderFromDirs {
    param([string[]]$Dirs)
    $renderFiles = foreach ($dir in $Dirs) {
        if (Test-Path -LiteralPath $dir) {
            Get-ChildItem -LiteralPath $dir -Filter *.mp4 -File
        }
    }
    $latest = $renderFiles |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $latest) { return $null }
    return $latest.FullName
}

function Add-ReviewTimestamp {
    param(
        [System.Collections.Generic.List[double]]$Bucket,
        [double]$Value
    )
    if ($Value -lt 0) { return }
    if (-not ($Bucket | Where-Object { [math]::Abs($_ - $Value) -lt 0.08 })) {
        $Bucket.Add([math]::Round($Value, 2))
    }
}

function Select-CappedReviewTimestamps {
    param(
        [double[]]$AllTimestamps,
        [double[]]$RequiredTimestamps,
        [int]$MaxCount
    )

    $selected = New-Object 'System.Collections.Generic.List[double]'
    foreach ($value in @($RequiredTimestamps | Sort-Object -Unique)) {
        Add-ReviewTimestamp -Bucket $selected -Value $value
    }
    if ($selected.Count -gt $MaxCount) {
        throw "Required review timestamps exceed MaxReviewFrames ($($selected.Count) > $MaxCount). Increase -MaxReviewFrames or reduce -ExtraTimestamps."
    }

    $remaining = @($AllTimestamps | Sort-Object -Unique | Where-Object {
        $candidate = $_
        -not ($selected | Where-Object { [math]::Abs($_ - $candidate) -lt 0.08 })
    })
    $slots = [math]::Max(0, $MaxCount - $selected.Count)
    if ($remaining.Count -le $slots) {
        foreach ($value in $remaining) { Add-ReviewTimestamp -Bucket $selected -Value $value }
    }
    elseif ($slots -gt 0) {
        for ($i = 0; $i -lt $slots; $i++) {
            $ratio = if ($slots -eq 1) { 0.5 } else { $i / [double]($slots - 1) }
            $index = [int][math]::Round($ratio * ($remaining.Count - 1))
            Add-ReviewTimestamp -Bucket $selected -Value $remaining[$index]
        }
    }

    return @($selected | Sort-Object)
}

function Export-ReviewFrames {
    param(
        [string]$VideoPath,
        [string]$ReviewDir,
        [double[]]$Timestamps
    )

    New-Item -ItemType Directory -Path $ReviewDir -Force | Out-Null
    Get-ChildItem -LiteralPath $ReviewDir -Filter "qa-frame-*.jpg" -File -ErrorAction SilentlyContinue |
        Remove-Item -Force
    foreach ($time in $Timestamps) {
        $safe = ("{0:0.00}" -f $time).Replace('.', '_')
        $outPath = Join-Path $ReviewDir ("qa-frame-{0}.jpg" -f $safe)
        & ffmpeg -v error -y -ss $time -i $VideoPath -frames:v 1 -q:v 3 -pix_fmt yuvj420p -strict unofficial -update 1 $outPath 2>$null | Out-Null
    }
}

$videoRoot = Resolve-FullPath $VideoDir
$hyperframesDir = Join-Path $videoRoot "hyperframes-app"
$remotionDir = Join-Path $videoRoot "remotion-app"
$assemblyDir = Join-Path $videoRoot "assembly"
$reviewDir = Join-Path $videoRoot "review"
$issues = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$notes = New-Object System.Collections.Generic.List[string]
$sceneClips = @()

$materialMixScript = Join-Path (Split-Path -Parent $PSCommandPath) "test-video-material-mix.ps1"
if (Test-Path -LiteralPath $materialMixScript) {
    $materialOutput = & powershell -ExecutionPolicy Bypass -File $materialMixScript -VideoDir $videoRoot 2>&1
    if ($LASTEXITCODE -eq 0) {
        $notes.Add("material mix QA passed")
    }
    else {
        foreach ($line in $materialOutput) {
            $text = ([string]$line).Trim()
            if ($text -and $text -ne "Material mix QA failed:") {
                $issues.Add("Material mix: $text")
            }
        }
    }
}
else {
    $issues.Add("Missing material mix QA script: $materialMixScript")
}

$visualTaskCoverageScript = Join-Path (Split-Path -Parent $PSCommandPath) "test-video-visual-task-coverage.ps1"
if (Test-Path -LiteralPath $visualTaskCoverageScript) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $visualTaskCoverageOutput = & powershell -ExecutionPolicy Bypass -File $visualTaskCoverageScript -VideoDir $videoRoot 2>&1
    $visualTaskCoverageExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($visualTaskCoverageExitCode -eq 0) {
        $notes.Add("visual-task implementation QA passed or was not applicable")
    }
    else {
        foreach ($line in $visualTaskCoverageOutput) {
            $text = ([string]$line).Trim()
            if ($text) { $issues.Add("Visual task coverage: $text") }
        }
    }
}
else {
    $issues.Add("Missing visual-task implementation QA script: $visualTaskCoverageScript")
}

$orientationScript = Join-Path (Split-Path -Parent $PSCommandPath) "test-video-orientation-decision.ps1"
if (Test-Path -LiteralPath $orientationScript) {
    $orientationOutput = & powershell -ExecutionPolicy Bypass -File $orientationScript -VideoDir $videoRoot 2>&1
    if ($LASTEXITCODE -eq 0) {
        $notes.Add("orientation decision QA passed")
        foreach ($line in $orientationOutput) {
            $text = ([string]$line).Trim()
            if ($text -and $text -ne "Orientation decision QA passed.") {
                $notes.Add("orientation: $text")
            }
        }
    }
    else {
        foreach ($line in $orientationOutput) {
            $text = ([string]$line).Trim()
            if ($text -and $text -ne "Orientation decision QA failed:") {
                $issues.Add("Orientation: $text")
            }
        }
    }
}
else {
    $issues.Add("Missing orientation decision QA script: $orientationScript")
}

foreach ($problem in (Test-ProductionNoteLeak -VideoRoot $videoRoot -HyperframesDir $hyperframesDir)) { $issues.Add($problem) }

if (Test-Path -LiteralPath $hyperframesDir) {
    $htmlPath = Join-Path $hyperframesDir "index.html"
    if (-not (Test-Path -LiteralPath $htmlPath)) {
        throw "Missing HyperFrames HTML: $htmlPath"
    }

    $htmlContent = Get-Content -LiteralPath $htmlPath -Raw -Encoding utf8
    if ($htmlContent -match '(?i)\bsapi\b|sapi-draft|narration-sapi') {
        $issues.Add("Invalid TTS path: HyperFrames composition references SAPI draft narration. Production narration must use IndexTTS-2 long-script audio with verified SRT/caption timing; SAPI is only a local timing stub.")
    }

    $videoElements = @(Parse-MediaElementsFromHtml -HtmlPath $htmlPath -TagName "video")
    $imageElements = @(Parse-MediaElementsFromHtml -HtmlPath $htmlPath -TagName "img")
    $videoClips = @($videoElements | Where-Object { $_.HasTimeline })
    $imageClips = @($imageElements | Where-Object { $_.HasTimeline })
    $sceneClips = @(Parse-SceneElementsFromHtml -HtmlPath $htmlPath)

    foreach ($problem in (Test-MediaSourcePresence -AssetsRoot $hyperframesDir -Elements (@($videoElements) + @($imageElements)))) { $issues.Add($problem) }
    foreach ($problem in (Test-BackgroundSourcePresence -HyperframesDir $hyperframesDir -AssetsRoot $hyperframesDir -HtmlPath $htmlPath)) { $issues.Add($problem) }
    foreach ($problem in (Test-TrackOverlaps -Clips $videoClips)) { $issues.Add($problem) }
    foreach ($problem in (Test-PlayableDuration -AssetsRoot $hyperframesDir -Clips $videoClips)) { $issues.Add($problem) }
    foreach ($risk in (Test-VideoEncodingRisk -AssetsRoot $hyperframesDir -Clips $videoClips -VideoRoot $videoRoot)) {
        if ($risk.Level -eq "Issue") {
            $issues.Add($risk.Message)
        }
        else {
            $warnings.Add($risk.Message)
        }
    }
    foreach ($problem in (Test-EvidenceReadabilityRisk -ImageClips $imageClips)) { $issues.Add($problem) }
    foreach ($problem in (Test-OpeningVisualDensity -HtmlPath $htmlPath -VideoClips $videoClips)) { $issues.Add($problem) }
    foreach ($problem in (Test-NarrationSrtProvenance -VideoRoot $videoRoot -HyperframesDir $hyperframesDir)) { $issues.Add($problem) }
    foreach ($problem in (Test-CaptionDisplayQuality -VideoRoot $videoRoot -HyperframesDir $hyperframesDir)) { $issues.Add($problem) }
    foreach ($problem in (Test-CaptionAudioAlignmentEvidence -VideoRoot $videoRoot -HyperframesDir $hyperframesDir)) { $issues.Add($problem) }
    $captionNoteData = @(Get-HyperframesCaptions -HyperframesDir $hyperframesDir)
    if ($captionNoteData.Count -gt 0 -and -not ($captionNoteData[0].PSObject.Properties.Name -contains "ParseError")) {
        $notes.Add(("caption display QA checked: {0} cues" -f $captionNoteData.Count))
    }
    $notes.Add("caption audio alignment QA checked")

    $scenePeakMarks = New-Object 'System.Collections.Generic.List[double]'
    foreach ($scene in $sceneClips) {
        Add-ReviewTimestamp -Bucket $scenePeakMarks -Value ($scene.Start + ($scene.Duration / 2.0))
    }
    $inspectAt = @($scenePeakMarks | Sort-Object | ForEach-Object {
        $_.ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture)
    }) -join ','

    Push-Location $hyperframesDir
    try {
        if ($inspectAt) {
            # Keep the current HyperFrames contract: hyperframes@0.7.55 inspect --at.
            # Redirect native stdout to a UTF-8 file so Windows PowerShell does not
            # corrupt non-ASCII JSON before ConvertFrom-Json sees it.
            $inspectToken = [guid]::NewGuid().ToString("N")
            $inspectOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("zimeiti-hf-inspect-{0}.json" -f $inspectToken)
            $inspectErrorPath = Join-Path ([System.IO.Path]::GetTempPath()) ("zimeiti-hf-inspect-{0}.stderr.log" -f $inspectToken)
            try {
                $inspectProcess = Start-Process `
                    -FilePath "npx.cmd" `
                    -ArgumentList @("--yes", "hyperframes@0.7.55", "inspect", "--at", $inspectAt, "--json") `
                    -WorkingDirectory $hyperframesDir `
                    -RedirectStandardOutput $inspectOutputPath `
                    -RedirectStandardError $inspectErrorPath `
                    -WindowStyle Hidden `
                    -Wait `
                    -PassThru
                $inspectExitCode = $inspectProcess.ExitCode
                $inspectText = Get-Content -LiteralPath $inspectOutputPath -Raw -Encoding utf8
                $inspectResult = $inspectText | ConvertFrom-Json
            }
            finally {
                foreach ($temporaryInspectPath in @($inspectOutputPath, $inspectErrorPath)) {
                    if ($temporaryInspectPath -and (Test-Path -LiteralPath $temporaryInspectPath)) {
                        Remove-Item -LiteralPath $temporaryInspectPath -Force
                    }
                }
            }
            $blockingInspectCodes = @('text_occluded', 'content_overlap', 'text_box_overflow', 'canvas_overflow', 'container_overflow')
            foreach ($item in @($inspectResult.issues)) {
                if ($blockingInspectCodes -contains [string]$item.code -and @('error', 'warning') -contains [string]$item.severity) {
                    $issues.Add(("Inspect scene midpoint t={0}s {1}: {2}" -f $item.time, $item.code, $item.message))
                }
            }
            $notes.Add(("hyperframes scene-midpoint inspect executed: {0} scene(s)" -f $scenePeakMarks.Count))
            if ($inspectExitCode -ne 0 -and @($inspectResult.issues).Count -eq 0) {
                $notes.Add("hyperframes scene-midpoint inspect returned non-zero without a reported layout issue")
            }
        }
        else {
            $notes.Add("hyperframes scene-midpoint inspect skipped: no timed .scene elements found")
        }
    }
    finally {
        Pop-Location
    }
}
elseif (Test-Path -LiteralPath $remotionDir) {
    $notes.Add("remotion project detected")
    $packagePath = Join-Path $remotionDir "package.json"
    $srcRoot = Join-Path $remotionDir "src"
    if (-not (Test-Path -LiteralPath $packagePath)) {
        $issues.Add("Missing Remotion package.json: $packagePath")
    }
    if (-not (Test-Path -LiteralPath $srcRoot)) {
        $issues.Add("Missing Remotion src folder: $srcRoot")
    }
}
elseif (Test-Path -LiteralPath (Join-Path $assemblyDir "render_story.py")) {
    $notes.Add("scripted assembly project detected")
    $assemblyManifest = Join-Path $reviewDir "render-manifest-v01.json"
    if (-not (Test-Path -LiteralPath $assemblyManifest)) {
        $issues.Add("Missing scripted assembly render manifest: $assemblyManifest")
    }
}
else {
    throw "Missing supported video app. Expected HyperFrames, Remotion, or assembly/render_story.py under $videoRoot"
}

New-Item -ItemType Directory -Path $reviewDir -Force | Out-Null

$finalDir = Join-Path $videoRoot "final"
$latestRender = if (Test-Path -LiteralPath $hyperframesDir) {
    Get-LatestRenderFromDirs -Dirs @(
        $hyperframesDir,
        (Join-Path $hyperframesDir "renders"),
        $finalDir
    )
}
elseif (Test-Path -LiteralPath $remotionDir) {
    Get-LatestRenderFromDirs -Dirs @(
        $remotionDir,
        (Join-Path $remotionDir "renders"),
        $finalDir
    )
}
else {
    $stateRender = $null
    $statePath = Join-Path $videoRoot "project-state.json"
    if (Test-Path -LiteralPath $statePath) {
        try {
            $state = Get-Content -LiteralPath $statePath -Raw -Encoding utf8 | ConvertFrom-Json
            if ($state.latestRender.path -and (Test-Path -LiteralPath ([string]$state.latestRender.path))) {
                $stateRender = (Resolve-Path -LiteralPath ([string]$state.latestRender.path)).Path
            }
        }
        catch {
            $warnings.Add("Could not read latest render from project-state.json: $($_.Exception.Message)")
        }
    }
    if ($stateRender) { $stateRender } else {
        Get-LatestRenderFromDirs -Dirs @($reviewDir, $assemblyDir, $finalDir)
    }
}
if ($latestRender) {
    $notes.Add("latest render found: $latestRender")
    $timelineMarks = New-Object 'System.Collections.Generic.List[double]'

    if (Test-Path -LiteralPath $hyperframesDir) {
        foreach ($clip in @($videoClips) + @($imageClips)) {
            Add-ReviewTimestamp -Bucket $timelineMarks -Value $clip.Start
            Add-ReviewTimestamp -Bucket $timelineMarks -Value ($clip.Start + $clip.Duration - 0.2)
        }
        foreach ($scene in $sceneClips) {
            Add-ReviewTimestamp -Bucket $timelineMarks -Value $scene.Start
            Add-ReviewTimestamp -Bucket $timelineMarks -Value ($scene.Start + ($scene.Duration / 2.0))
            Add-ReviewTimestamp -Bucket $timelineMarks -Value ($scene.Start + $scene.Duration - 0.2)
        }
    }

    Add-ReviewTimestamp -Bucket $timelineMarks -Value 0
    Add-ReviewTimestamp -Bucket $timelineMarks -Value 0.03
    Add-ReviewTimestamp -Bucket $timelineMarks -Value 3
    Add-ReviewTimestamp -Bucket $timelineMarks -Value 10

    foreach ($rawStampGroup in $ExtraTimestamps) {
        foreach ($piece in ($rawStampGroup -split ',')) {
            $trimmed = $piece.Trim()
            if (-not $trimmed) { continue }
            $value = [double]::Parse($trimmed, [System.Globalization.CultureInfo]::InvariantCulture)
            Add-ReviewTimestamp -Bucket $timelineMarks -Value $value
        }
    }

    $requiredMarks = New-Object 'System.Collections.Generic.List[double]'
    foreach ($value in @(0, 0.03, 3, 10)) {
        Add-ReviewTimestamp -Bucket $requiredMarks -Value $value
    }
    foreach ($scene in $sceneClips) {
        Add-ReviewTimestamp -Bucket $requiredMarks -Value ($scene.Start + ($scene.Duration / 2.0))
    }
    foreach ($rawStampGroup in $ExtraTimestamps) {
        foreach ($piece in ($rawStampGroup -split ',')) {
            $trimmed = $piece.Trim()
            if (-not $trimmed) { continue }
            $value = [double]::Parse($trimmed, [System.Globalization.CultureInfo]::InvariantCulture)
            Add-ReviewTimestamp -Bucket $requiredMarks -Value $value
        }
    }

    $finalMarks = Select-CappedReviewTimestamps -AllTimestamps $timelineMarks -RequiredTimestamps $requiredMarks -MaxCount $MaxReviewFrames
    $reviewFrameDir = Join-Path $reviewDir "qa-frames-current"
    Export-ReviewFrames -VideoPath $latestRender -ReviewDir $reviewFrameDir -Timestamps $finalMarks
    $notes.Add(("review frames exported: {0} (cap={1}, dir={2})" -f $finalMarks.Count, $MaxReviewFrames, $reviewFrameDir))
}
else {
    $issues.Add("No rendered mp4 found for the detected project type under $videoRoot")
}

$reportLines = @()
$reportLines += "# Draft QA"
$reportLines += ""
$reportLines += "VideoDir: $videoRoot"
$reportLines += "CheckedAt: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$reportLines += ""
$reportLines += "## Notes"
$reportLines += ""
if ($notes.Count -eq 0) {
    $reportLines += "- none"
}
else {
    $notes | ForEach-Object { $reportLines += "- $_" }
}
$reportLines += ""
$reportLines += "## Warnings"
$reportLines += ""
if ($warnings.Count -eq 0) {
    $reportLines += "- none"
}
else {
    $warnings | ForEach-Object { $reportLines += "- $_" }
}
$reportLines += ""
$reportLines += "## Issues"
$reportLines += ""
if ($issues.Count -eq 0) {
    $reportLines += "- PASS"
}
else {
    $issues | ForEach-Object { $reportLines += "- $_" }
}

$reportLines += ""
$reportLines += "## Manual Visual Gates"
$reportLines += ""
$reportLines += '- Open review/qa-frames-current/qa-frame-0_00.jpg and review/qa-frames-current/qa-frame-0_03.jpg: the first visible frame must already have a focal composition, not an empty background or only a caption.'
$reportLines += '- Open review/qa-frames-current/qa-frame-3_00.jpg: the opening must not stack all meaningful content in the lower band or leave a large unused top/bottom half.'
$reportLines += '- Open every exported scene-midpoint frame: it represents the full-entry/peak state and must not contain title-card, chip, label, proof, or caption collisions.'
$reportLines += '- Open at least four subtitle frames around opening, middle proof, middle argument, and closing: captions must be natural phrases, not broken fragments.'
$reportLines += "- Before showing the draft, compare these frames with the user's known failure patterns: bottom-stacked opening, empty media slots, unreadable proof cards, heavy subtitle slabs, and PPT-like info cards."
$reportLines += "- This section is a hard human review gate. Script PASS is not enough if any of these frames fails by eye."

$reportPath = Join-Path $reviewDir "draft-qa-report.md"
Set-Content -LiteralPath $reportPath -Value $reportLines -Encoding utf8

if ($latestRender) {
    $pendingReviewPath = Join-Path $reviewDir "human-visual-review-pending.md"
    $renderHash = (Get-FileHash -LiteralPath $latestRender -Algorithm SHA256).Hash
    $automatedStatus = if ($issues.Count -gt 0) { "BLOCKED" } else { "PASS" }
    $pendingLines = @(
        "# Human Visual Review Pending",
        "",
        "Status: PENDING",
        "Automated QA: $automatedStatus",
        "Candidate: ``$latestRender``",
        "Candidate SHA256: ``$renderHash``",
        "Frame evidence directory: ``$(Join-Path $reviewDir 'qa-frames-current')``",
        "",
        "Complete the checks below, cite opened JPG/PNG evidence, then save the accepted record as ``review\human-visual-review-vNN.md``.",
        "",
        "- First visible frame:",
        "- Subtitle readability:",
        "- Evidence readability:",
        "- Visual-task coverage:",
        "- Blank media slots:",
        "- Transition artifacts:",
        "- Static-card duration:",
        "- Audio review:",
        "- Closing beat:",
        "- Evidence files opened:"
    )
    Set-Content -LiteralPath $pendingReviewPath -Value $pendingLines -Encoding utf8
}

$stateScript = Join-Path (Split-Path -Parent $PSCommandPath) "update-video-project-state.ps1"
if (Test-Path -LiteralPath $stateScript) {
    $stageStatus = if ($issues.Count -gt 0) { "blocked" } else { "awaiting_human_review" }
    $automatedQaStatus = if ($issues.Count -gt 0) { "FAIL" } else { "PASS" }
    $nextAction = if ($issues.Count -gt 0) { "Resolve draft QA blockers in the owning stage." } else { "Complete review\human-visual-review-vNN.md for the current render." }
    $stateArgs = @{
        VideoDir = $videoRoot
        CurrentStage = "QA"
        StageStatus = $stageStatus
        NextAction = $nextAction
        AutomatedQa = $automatedQaStatus
        AutomatedQaReport = $reportPath
        Source = "run-video-draft-qa.ps1"
    }
    if ($latestRender) { $stateArgs["LatestRender"] = $latestRender }
    if ($issues.Count -gt 0) { $stateArgs["Blockers"] = @($issues) }
    & $stateScript @stateArgs | Out-Null
}

Write-Host "Draft QA report: $reportPath"
if ($issues.Count -gt 0) {
    Write-Error ("Draft QA failed with {0} issue(s)." -f $issues.Count)
    exit 1
}
Write-Host "Draft QA passed."
