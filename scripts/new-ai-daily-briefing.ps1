param(
  [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
  [string]$WorkspaceRoot = "",
  [string]$KnowledgeRoot = "",
  [string]$OutputRoot = "",
  [string]$JsonPath = "",
  [switch]$Write
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Utf8File {
  param(
    [string]$Path,
    [string]$Content
  )

  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

  try {
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
  } catch [System.UnauthorizedAccessException] {
    $parent = Split-Path -Parent $Path
    throw ("Write denied for `{0}`. Make sure the parent directory is writable: {1}" -f $Path, $parent)
  }
}

function New-TextFromCodePoints {
  param([int[]]$CodePoints)

  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function New-MarkdownLink {
  param(
    [string]$Label,
    [string]$Url
  )

  if ([string]::IsNullOrWhiteSpace($Url)) {
    return $Label
  }

  return "[{0}]({1})" -f $Label, $Url
}

function Get-JsonValue {
  param(
    [object]$Object,
    [string]$PropertyName,
    [string]$DefaultValue = ""
  )

  if ($null -eq $Object) {
    return $DefaultValue
  }

  $property = $Object.PSObject.Properties[$PropertyName]
  if ($null -eq $property -or $null -eq $property.Value) {
    return $DefaultValue
  }

  return [string]$property.Value
}

function Get-JsonArray {
  param(
    [object]$Object,
    [string]$PropertyName
  )

  if ($null -eq $Object) {
    return @()
  }

  $property = $Object.PSObject.Properties[$PropertyName]
  if ($null -eq $property -or $null -eq $property.Value) {
    return @()
  }

  return [object[]]@($property.Value)
}

function Add-Line {
  param(
    [System.Collections.Generic.List[string]]$Lines,
    [string]$Text = ""
  )

  $Lines.Add($Text) | Out-Null
}

$ZhKnowledgeRoot = New-TextFromCodePoints @(0x77E5,0x8BC6,0x5E93)
$ZhDailyBriefingName = New-TextFromCodePoints @(0x6BCF,0x65E5,0x0041,0x0049,0x7B80,0x62A5)
$ZhFrontmatterTitle = New-TextFromCodePoints @(0x6BCF,0x65E5,0x0020,0x0041,0x0049,0x0020,0x7B80,0x62A5)
$ZhTag1 = New-TextFromCodePoints @(0x0041,0x0049,0x7B80,0x62A5)
$ZhTag2 = New-TextFromCodePoints @(0x0041,0x0049,0x65B0,0x95FB)
$ZhTag3 = New-TextFromCodePoints @(0x5185,0x5BB9,0x9009,0x9898)
$ZhSourcePending = New-TextFromCodePoints @(0x6765,0x6E90,0x5F85,0x8865,0x5145)
$ZhTitlePending = New-TextFromCodePoints @(0x6807,0x9898,0x5F85,0x8865,0x5145)
$ZhWhatPrefix = New-TextFromCodePoints @(0x8FD9,0x4EF6,0x4E8B,0x662F,0x4EC0,0x4E48,0xFF1A)
$ZhWhyPrefix = New-TextFromCodePoints @(0x4E3A,0x4EC0,0x4E48,0x91CD,0x8981,0xFF1A)
$ZhImpactPrefix = New-TextFromCodePoints @(0x5BF9,0x6211,0x6709,0x4EC0,0x4E48,0x5F71,0x54CD,0xFF1A)
$ZhPending = New-TextFromCodePoints @(0x5F85,0x8865,0x5145)
$ZhFocusPending = New-TextFromCodePoints @(0x4ECA,0x65E5,0x91CD,0x70B9,0x5F85,0x8865,0x5145)

if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
  $WorkspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
  $WorkspaceRoot = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
}
$ZhFocusFallback = New-TextFromCodePoints @(0x5B83,0x6700,0x5BB9,0x6613,0x8F6C,0x6210,0x4ECA,0x5929,0x80FD,0x7EE7,0x7EED,0x8FFD,0x8E2A,0x3001,0x80FD,0x7EE7,0x7EED,0x505A,0x9009,0x9898,0x5224,0x65AD,0x7684,0x4E00,0x6761,0x4E3B,0x7EBF,0x3002)
$ZhSparseFallback = New-TextFromCodePoints @(0x4ECA,0x65E5,0x9AD8,0x4EF7,0x503C,0x0020,0x0041,0x0049,0x0020,0x65B0,0x95FB,0x8F83,0x5C11,0xFF0C,0x4EE5,0x4E0B,0x53EA,0x4FDD,0x7559,0x6700,0x503C,0x5F97,0x8DDF,0x8FDB,0x7684,0x6761,0x76EE,0x3002)
$ZhSectionTopNews = New-TextFromCodePoints @(0x4ECA,0x65E5,0x6700,0x91CD,0x8981,0x7684,0x0020,0x0033,0x0020,0x6761,0x0020,0x0041,0x0049,0x0020,0x65B0,0x95FB)
$ZhSectionFocus = New-TextFromCodePoints @(0x4ECA,0x65E5,0x91CD,0x70B9,0x5173,0x6CE8)
$ZhSectionIdeas = New-TextFromCodePoints @(0x53EF,0x8F6C,0x5316,0x9009,0x9898)
$ZhSectionViews = New-TextFromCodePoints @(0x53EF,0x53D1,0x5C0F,0x7EA2,0x4E66,0x0020,0x002F,0x0020,0x0058,0x0020,0x7684,0x4E00,0x53E5,0x8BDD,0x89C2,0x70B9)
$ZhFocusLinePrefix = New-TextFromCodePoints @(0x4ECA,0x5929,0x6700,0x503C,0x5F97,0x91CD,0x70B9,0x5173,0x6CE8,0x7684,0x662F,0xFF1A)
$ZhReasonLinePrefix = New-TextFromCodePoints @(0x539F,0x56E0,0xFF1A)
$ZhSourceLinePrefix = New-TextFromCodePoints @(0x6765,0x6E90,0xFF1A)
$ZhLinkLinePrefix = New-TextFromCodePoints @(0x94FE,0x63A5,0xFF1A)
$ZhWhatLinePrefix = New-TextFromCodePoints @(0x8FD9,0x4EF6,0x4E8B,0x662F,0x4EC0,0x4E48,0xFF1A)
$ZhWhyLinePrefix = New-TextFromCodePoints @(0x4E3A,0x4EC0,0x4E48,0x91CD,0x8981,0xFF1A)
$ZhImpactLinePrefix = New-TextFromCodePoints @(0x5BF9,0x6211,0x6709,0x4EC0,0x4E48,0x5F71,0x54CD,0xFF1A)
$ZhDemandSignalLinePrefix = New-TextFromCodePoints @(0x9700,0x6C42,0x4FE1,0x53F7,0xFF1A)
$ZhConversionDirectionLinePrefix = New-TextFromCodePoints @(0x53EF,0x8F6C,0x5316,0x65B9,0x5411,0xFF1A)
$ZhDemandSignalFallback = New-TextFromCodePoints @(0x5148,0x5224,0x65AD,0x5B83,0x66B4,0x9732,0x7684,0x662F,0x60C5,0x7EEA,0x3001,0x5B9E,0x7528,0x3001,0x6210,0x672C,0x3001,0x5C97,0x4F4D,0x3001,0x98CE,0x9669,0x8FD8,0x662F,0x51B3,0x7B56,0x9700,0x6C42,0xFF1B,0x4E0D,0x8981,0x53EA,0x8BB0,0x5F55,0x65B0,0x95FB,0x4E8B,0x5B9E,0x3002)
$ZhConversionDirectionFallback = New-TextFromCodePoints @(0x5982,0x679C,0x8FDB,0x5165,0x9009,0x9898,0x65E5,0x62A5,0xFF0C,0x9700,0x8981,0x8FDB,0x4E00,0x6B65,0x62C6,0x6210,0x89C2,0x4F17,0x6536,0x83B7,0x3001,0x8BC1,0x636E,0x548C,0x53EF,0x62CD,0x89D2,0x5EA6,0x3002)
$ZhDefaultIdea1 = New-TextFromCodePoints @(0x628A,0x4ECA,0x5929,0x6700,0x5F3A,0x7684,0x4E00,0x6761,0x65B0,0x95FB,0x6539,0x5199,0x6210,0x201C,0x666E,0x901A,0x4EBA,0x80FD,0x4E0D,0x80FD,0x7528,0x201D,0x7684,0x5224,0x65AD,0x9898)
$ZhDefaultIdea2 = New-TextFromCodePoints @(0x628A,0x4E24,0x6761,0x76F8,0x5173,0x65B0,0x95FB,0x5408,0x5E76,0x6210,0x4E00,0x4E2A,0x201C,0x8D8B,0x52BF,0x5230,0x5E95,0x5F80,0x54EA,0x8D70,0x201D,0x7684,0x89E3,0x91CA,0x9898)
$ZhDefaultIdea3 = New-TextFromCodePoints @(0x5982,0x679C,0x70ED,0x70B9,0x4E0D,0x591F,0x5F3A,0xFF0C,0x5C31,0x56DE,0x9000,0x6210,0x201C,0x8FD9,0x4EF6,0x4E8B,0x5BF9,0x5DE5,0x4F5C,0x6D41,0x610F,0x5473,0x7740,0x4EC0,0x4E48,0x201D,0x7684,0x5E38,0x9752,0x9898)
$ZhDefaultView1 = New-TextFromCodePoints @(0x5F88,0x591A,0x0020,0x0041,0x0049,0x0020,0x65B0,0x95FB,0x770B,0x8D77,0x6765,0x5F88,0x5927,0xFF0C,0x4F46,0x771F,0x6B63,0x8BE5,0x770B,0x7684,0x53EA,0x6709,0x4E00,0x53E5,0xFF1A,0x8FD9,0x4E1C,0x897F,0x5230,0x5E95,0x6709,0x6CA1,0x6709,0x8FDB,0x5165,0x771F,0x5B9E,0x5DE5,0x4F5C,0x6D41,0x3002)
$ZhDefaultView2 = New-TextFromCodePoints @(0x4E0D,0x662F,0x6BCF,0x4E2A,0x0020,0x0041,0x0049,0x0020,0x66F4,0x65B0,0x90FD,0x503C,0x5F97,0x8FFD,0xFF0C,0x771F,0x6B63,0x503C,0x5F97,0x8FFD,0x7684,0x662F,0x5B83,0x6709,0x6CA1,0x6709,0x8BA9,0x666E,0x901A,0x4EBA,0x7684,0x52A8,0x4F5C,0x53D8,0x77ED,0x3002)
$ZhDefaultView3 = New-TextFromCodePoints @(0x70ED,0x70B9,0x8D1F,0x8D23,0x544A,0x8BC9,0x4F60,0x4E16,0x754C,0x5728,0x53D8,0xFF0C,0x9009,0x9898,0x8D1F,0x8D23,0x5224,0x65AD,0x8FD9,0x53D8,0x5316,0x5230,0x5E95,0x548C,0x4F60,0x6709,0x6CA1,0x6709,0x5173,0x7CFB,0x3002)

function Get-DefaultItem {
  param([int]$Index)

  return [pscustomobject]@{
    title = "{0} {1}" -f $ZhTitlePending, $Index
    source = $ZhSourcePending
    link = ""
    what = $ZhPending
    why = $ZhPending
    impact = $ZhPending
  }
}

if ([string]::IsNullOrWhiteSpace($KnowledgeRoot)) {
  $KnowledgeRoot = Join-Path $WorkspaceRoot "data"
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path $KnowledgeRoot "AI-Daily-Briefing"
}

$fileName = "{0}-{1}.md" -f $Date, $ZhDailyBriefingName
$outputPath = Join-Path $OutputRoot $fileName

$items = @()
$focusTitle = ""
$focusReason = ""
$topicIdeas = @()
$socialViews = @()
$sparseNote = ""

if (-not [string]::IsNullOrWhiteSpace($JsonPath)) {
  if (-not (Test-Path -LiteralPath $JsonPath)) {
    throw "JsonPath not found: $JsonPath"
  }

  $raw = Get-Content -LiteralPath $JsonPath -Encoding UTF8 -Raw
  $payload = $raw | ConvertFrom-Json

  $items = Get-JsonArray -Object $payload -PropertyName "items"
  $topicIdeas = Get-JsonArray -Object $payload -PropertyName "topic_ideas"
  $socialViews = Get-JsonArray -Object $payload -PropertyName "social_views"
  $sparseNote = Get-JsonValue -Object $payload -PropertyName "sparse_note"

  $focusProperty = $payload.PSObject.Properties["focus"]
  if ($null -ne $focusProperty -and $null -ne $focusProperty.Value) {
    $focus = $focusProperty.Value
    $focusTitle = Get-JsonValue -Object $focus -PropertyName "title"
    $focusReason = Get-JsonValue -Object $focus -PropertyName "reason"
  }
}

if (@($items).Count -eq 0) {
  $items = @(1..3 | ForEach-Object { Get-DefaultItem -Index $_ })
}

if (@($topicIdeas).Count -eq 0) {
  $topicIdeas = @($ZhDefaultIdea1, $ZhDefaultIdea2, $ZhDefaultIdea3)
}

if (@($socialViews).Count -eq 0) {
  $socialViews = @($ZhDefaultView1, $ZhDefaultView2, $ZhDefaultView3)
}

if ([string]::IsNullOrWhiteSpace($focusTitle)) {
  $focusTitle = Get-JsonValue -Object $items[0] -PropertyName "title" -DefaultValue $ZhFocusPending
}

if ([string]::IsNullOrWhiteSpace($focusReason)) {
  $focusReason = $ZhFocusFallback
}

$lines = New-Object 'System.Collections.Generic.List[string]'

Add-Line -Lines $lines -Text "---"
Add-Line -Lines $lines -Text ('title: "{0} - {1}"' -f $ZhFrontmatterTitle, $Date)
Add-Line -Lines $lines -Text ("date: {0}" -f $Date)
Add-Line -Lines $lines -Text ("tags: [{0}, {1}, {2}]" -f $ZhTag1, $ZhTag2, $ZhTag3)
Add-Line -Lines $lines -Text 'source_type: "daily_ai_briefing"'
Add-Line -Lines $lines -Text 'status: "processed"'
Add-Line -Lines $lines -Text "---"
Add-Line -Lines $lines
Add-Line -Lines $lines -Text ("# {0} - {1}" -f $ZhFrontmatterTitle, $Date)
Add-Line -Lines $lines

if (@($items).Count -lt 3 -or -not [string]::IsNullOrWhiteSpace($sparseNote)) {
  $note = if (-not [string]::IsNullOrWhiteSpace($sparseNote)) { $sparseNote } else { $ZhSparseFallback }
  Add-Line -Lines $lines -Text ("> {0}" -f $note)
  Add-Line -Lines $lines
}

Add-Line -Lines $lines -Text ("## {0}" -f $ZhSectionTopNews)
Add-Line -Lines $lines

$index = 1
foreach ($item in $items) {
  $title = Get-JsonValue -Object $item -PropertyName "title" -DefaultValue ("{0} {1}" -f $ZhTitlePending, $index)
  $source = Get-JsonValue -Object $item -PropertyName "source" -DefaultValue $ZhSourcePending
  $link = Get-JsonValue -Object $item -PropertyName "link"
  $what = Get-JsonValue -Object $item -PropertyName "what" -DefaultValue $ZhPending
  $why = Get-JsonValue -Object $item -PropertyName "why" -DefaultValue $ZhPending
  $impact = Get-JsonValue -Object $item -PropertyName "impact" -DefaultValue $ZhPending
  $demandSignal = Get-JsonValue -Object $item -PropertyName "demand_signal" -DefaultValue $ZhDemandSignalFallback
  $conversionDirection = Get-JsonValue -Object $item -PropertyName "conversion_direction" -DefaultValue $ZhConversionDirectionFallback

  Add-Line -Lines $lines -Text ("### {0}. {1}" -f $index, $title)
  Add-Line -Lines $lines -Text ("- {0}{1}" -f $ZhSourceLinePrefix, $source)
  Add-Line -Lines $lines -Text ("- {0}{1}" -f $ZhLinkLinePrefix, (New-MarkdownLink -Label $title -Url $link))
  Add-Line -Lines $lines -Text ("- {0}{1}" -f $ZhWhatLinePrefix, $what)
  Add-Line -Lines $lines -Text ("- {0}{1}" -f $ZhWhyLinePrefix, $why)
  Add-Line -Lines $lines -Text ("- {0}{1}" -f $ZhImpactLinePrefix, $impact)
  Add-Line -Lines $lines -Text ("- {0}{1}" -f $ZhDemandSignalLinePrefix, $demandSignal)
  Add-Line -Lines $lines -Text ("- {0}{1}" -f $ZhConversionDirectionLinePrefix, $conversionDirection)
  Add-Line -Lines $lines
  $index++
}

Add-Line -Lines $lines -Text ("## {0}" -f $ZhSectionFocus)
Add-Line -Lines $lines
Add-Line -Lines $lines -Text ("{0}{1}" -f $ZhFocusLinePrefix, $focusTitle)
Add-Line -Lines $lines -Text ("{0}{1}" -f $ZhReasonLinePrefix, $focusReason)
Add-Line -Lines $lines

Add-Line -Lines $lines -Text ("## {0}" -f $ZhSectionIdeas)
Add-Line -Lines $lines
foreach ($idea in $topicIdeas) {
  Add-Line -Lines $lines -Text ("- {0}" -f $idea)
}
Add-Line -Lines $lines

Add-Line -Lines $lines -Text ("## {0}" -f $ZhSectionViews)
Add-Line -Lines $lines
foreach ($view in $socialViews) {
  Add-Line -Lines $lines -Text ("- {0}" -f $view)
}

$markdown = [string]::Join([Environment]::NewLine, $lines)

if ($Write) {
  New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
  Write-Utf8File -Path $outputPath -Content $markdown
}

[pscustomobject]@{
  Success    = $true
  Date       = $Date
  OutputRoot = $OutputRoot
  OutputPath = $outputPath
  WroteFile  = [bool]$Write
  ItemCount  = @($items).Count
  FocusTitle = $focusTitle
}
