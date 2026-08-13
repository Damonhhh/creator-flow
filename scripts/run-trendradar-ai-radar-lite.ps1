param(
  [string]$ConfigDir = "",
  [string]$OutputRoot = "",
  [switch]$LiveCollection,
  [int]$MaxItemsPerSource = 30,
  [int]$RssMaxAgeHours = 72
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$workspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($ConfigDir)) {
  $ConfigDir = Join-Path $workspaceRoot "integrations\trendradar-ai-daily"
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path $workspaceRoot "output\trendradar-ai-daily"
}
if (-not $LiveCollection) {
  throw "TrendRadar collection is offline by default. Re-run with -LiveCollection to fetch current sources."
}

function Get-QuotedValue {
  param([string]$Line)
  if ($Line -match ':\s*"([^"]*)"') { return $Matches[1] }
  if ($Line -match ':\s*([^#\s]+)') { return $Matches[1].Trim() }
  return ""
}

function Read-TrendRadarLiteConfig {
  param([string]$Path)

  $sources = New-Object System.Collections.Generic.List[object]
  $feeds = New-Object System.Collections.Generic.List[object]
  $section = ""
  $current = $null

  foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith("#")) { continue }

    if ($line -match '^\S') {
      if ($trimmed -eq "platforms:") { $section = "platforms"; continue }
      if ($trimmed -eq "rss:") { $section = "rss"; continue }
      if ($trimmed -notmatch '^(sources|feeds):') {
        $section = ""
      }
    }

    if ($trimmed -eq "sources:") { $section = "platform_sources"; continue }
    if ($trimmed -eq "feeds:") { $section = "rss_feeds"; continue }

    if ($section -eq "platform_sources") {
      if ($trimmed -match '^- id:') {
        if ($current) { $sources.Add([pscustomobject]$current) }
        $current = @{ id = Get-QuotedValue $trimmed; name = ""; expected_domain = "" }
        continue
      }
      if ($current -and $trimmed -match '^name:') { $current.name = Get-QuotedValue $trimmed; continue }
      if ($current -and $trimmed -match '^expected_domain:') { $current.expected_domain = Get-QuotedValue $trimmed; continue }
    }

    if ($section -eq "rss_feeds") {
      if ($trimmed -match '^- id:') {
        if ($current) {
          if ($current.ContainsKey("url")) { $feeds.Add([pscustomobject]$current) } else { $sources.Add([pscustomobject]$current) }
        }
        $current = @{ id = Get-QuotedValue $trimmed; name = ""; url = "" }
        continue
      }
      if ($current -and $trimmed -match '^name:') { $current.name = Get-QuotedValue $trimmed; continue }
      if ($current -and $trimmed -match '^url:') { $current.url = Get-QuotedValue $trimmed; continue }
    }
  }

  if ($current) {
    if ($current.ContainsKey("url")) { $feeds.Add([pscustomobject]$current) } else { $sources.Add([pscustomobject]$current) }
  }

  $sourceArray = @()
  foreach ($source in $sources) { $sourceArray += $source }
  $feedArray = @()
  foreach ($feed in $feeds) { $feedArray += $feed }

  [pscustomobject]@{
    sources = $sourceArray
    feeds = $feedArray
  }
}

function New-TextFromCodePoints {
  param([int[]]$CodePoints)
  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function New-KeywordGroups {
  $cp = @{
    artificial_intelligence = New-TextFromCodePoints @(0x4eba,0x5de5,0x667a,0x80fd)
    big_model = New-TextFromCodePoints @(0x5927,0x6a21,0x578b)
    generative_ai = (New-TextFromCodePoints @(0x751f,0x6210,0x5f0f)) + "AI"
    agent_cn = New-TextFromCodePoints @(0x667a,0x80fd,0x4f53)
    multimodal = New-TextFromCodePoints @(0x591a,0x6a21,0x6001)
    open_source_model = New-TextFromCodePoints @(0x5f00,0x6e90,0x6a21,0x578b)
    reasoning_model = New-TextFromCodePoints @(0x63a8,0x7406,0x6a21,0x578b)
    compute_power = New-TextFromCodePoints @(0x7b97,0x529b)
    chip = New-TextFromCodePoints @(0x82af,0x7247)
    robot = New-TextFromCodePoints @(0x673a,0x5668,0x4eba)
  }

  @(
    [pscustomobject]@{ name = "models_products"; patterns = @("OpenAI","ChatGPT","GPT-","GPT ","Claude","Anthropic","Gemini","DeepMind","Grok","xAI","Llama","Meta AI","Qwen","DeepSeek","Kimi","Doubao","Hunyuan","ERNIE","Pangu","openPangu",(New-TextFromCodePoints @(0x76d8,0x53e4)),$cp.artificial_intelligence,$cp.big_model,$cp.generative_ai,$cp.open_source_model,$cp.reasoning_model) },
    [pscustomobject]@{ name = "agents_coding"; patterns = @("Codex","Cursor","GitHub Copilot","Copilot","Claude Code","agent","agents","MCP","computer use","AI coding","code agent",$cp.agent_cn) },
    [pscustomobject]@{ name = "infra_compute"; patterns = @("Nvidia","GPU","CUDA","Blackwell","inference","TPU","AI chip","Hugging Face","vector database",$cp.compute_power,$cp.chip) },
    [pscustomobject]@{ name = "research_multimodal"; patterns = @("multimodal","reasoning","diffusion","video model","image model","robotics",$cp.multimodal,$cp.robot) },
    [pscustomobject]@{ name = "policy_business"; patterns = @("AI regulation","AI safety","copyright","lawsuit","funding","acquisition","partnership","antitrust","export control") }
  )
}

function Invoke-Utf8TextRequest {
  param(
    [string]$Uri,
    [string]$Accept = "*/*",
    [int]$TimeoutSec = 25
  )

  $currentUri = $Uri
  for ($redirect = 0; $redirect -lt 5; $redirect++) {
    $request = [System.Net.HttpWebRequest][System.Net.WebRequest]::Create($currentUri)
    $request.Method = "GET"
    $request.Timeout = $TimeoutSec * 1000
    $request.ReadWriteTimeout = $TimeoutSec * 1000
    $request.AllowAutoRedirect = $true
    $request.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
    $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"
    $request.Accept = $Accept
    $request.Headers.Set("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")
    $request.Headers.Set("Cache-Control", "no-cache")

    $response = $null
    $stream = $null
    $reader = $null
    try {
      $response = $request.GetResponse()
      $stream = $response.GetResponseStream()
      $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
      return $reader.ReadToEnd()
    } catch [System.Net.WebException] {
      $webResponse = $_.Exception.Response
      if ($webResponse -and $webResponse.Headers["Location"]) {
        $status = [int]$webResponse.StatusCode
        if ($status -in @(301,302,303,307,308)) {
          $location = $webResponse.Headers["Location"]
          $baseUri = [Uri]$currentUri
          $currentUri = ([Uri]::new($baseUri, $location)).AbsoluteUri
          continue
        }
      }
      throw
    } finally {
      if ($reader) { $reader.Dispose() }
      elseif ($stream) { $stream.Dispose() }
      if ($response) { $response.Dispose() }
    }
  }

  throw "Too many redirects for $Uri"
}

function Get-MatchedGroups {
  param(
    [string]$Text,
    [object[]]$Groups
  )

  $matched = New-Object System.Collections.Generic.List[string]
  foreach ($group in $Groups) {
    foreach ($pattern in $group.patterns) {
      if ($Text -and $Text.IndexOf([string]$pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $matched.Add($group.name)
        break
      }
    }
  }
  return @($matched | Select-Object -Unique)
}

function Test-ExpectedDomain {
  param(
    [string]$Url,
    [string]$ExpectedDomain
  )
  if ([string]::IsNullOrWhiteSpace($Url) -or [string]::IsNullOrWhiteSpace($ExpectedDomain)) { return $true }
  try {
    $uri = [Uri]$Url
    $hostname = $uri.Host.ToLowerInvariant()
    $expected = $ExpectedDomain.ToLowerInvariant()
    return ($uri.Scheme -eq "https" -and ($hostname -eq $expected -or $hostname.EndsWith("." + $expected)))
  } catch {
    return $false
  }
}

function Convert-ToDateTimeOffset {
  param([object]$Value)
  if ($null -eq $Value) { return $null }
  $text = ([string]$Value).Trim()
  if (-not $text) { return $null }

  $dto = [DateTimeOffset]::MinValue
  if ([DateTimeOffset]::TryParse($text, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$dto)) {
    return $dto
  }
  return $null
}

function Get-FirstXmlText {
  param([object]$Node, [string[]]$Names)
  foreach ($name in $Names) {
    try {
      $prop = $Node.PSObject.Properties[$name]
      if ($prop -and $null -ne $prop.Value) {
        $value = $prop.Value
        if ($value -is [System.Xml.XmlNode] -and $value.InnerText) { return ([string]$value.InnerText).Trim() }
        if ($value -is [System.Xml.XmlNode]) { return "" }
        return ([string]$value).Trim()
      }
    } catch {}
  }
  return ""
}

function Get-AtomLink {
  param([object]$Entry)
  try {
    $prop = $Entry.PSObject.Properties["link"]
    if (-not $prop) { return "" }
    foreach ($link in @($prop.Value)) {
      if ($link.href) { return [string]$link.href }
      if ($link.InnerText) { return [string]$link.InnerText }
      if ($link) { return [string]$link }
    }
  } catch {}
  return ""
}

function Fetch-HotlistItems {
  param(
    [object[]]$Sources,
    [object[]]$KeywordGroups,
    [int]$MaxItemsPerSource
  )

  $items = New-Object System.Collections.Generic.List[object]
  foreach ($source in $Sources) {
    $apiUrl = "https://newsnow.busiyi.world/api/s?id=$($source.id)&latest"
    try {
      $responseText = $null
      for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
          $responseText = Invoke-Utf8TextRequest -Uri $apiUrl -Accept "application/json, text/plain, */*" -TimeoutSec 20
          break
        } catch {
          if ($attempt -eq 3) { throw }
          Start-Sleep -Seconds (2 * $attempt)
        }
      }
      $response = $responseText | ConvertFrom-Json
      $rank = 0
      foreach ($raw in @($response.items | Select-Object -First $MaxItemsPerSource)) {
        $rank++
        $title = ([string]$raw.title).Trim()
        if (-not $title) { continue }

        $url = [string]$raw.url
        if (-not (Test-ExpectedDomain -Url $url -ExpectedDomain $source.expected_domain)) { continue }

        $hover = ""
        try {
          if ($raw.extra -and $raw.extra.hover) { $hover = [string]$raw.extra.hover }
        } catch {}

        $matched = @(Get-MatchedGroups -Text "$title`n$hover" -Groups $KeywordGroups)
        if (@($matched).Count -eq 0) { continue }

        $items.Add([pscustomobject]@{
          source_type = "hotlist"
          source_id = $source.id
          source_name = $source.name
          title = $title
          url = $url
          mobile_url = if ($raw.PSObject.Properties["mobileUrl"]) { [string]$raw.mobileUrl } else { "" }
          rank = $rank
          published_at = $null
          matched_groups = @($matched)
          summary = $hover
        })
      }
    } catch {
      $items.Add([pscustomobject]@{
        source_type = "error"
        source_id = $source.id
        source_name = $source.name
        title = "FETCH_FAILED"
        url = $apiUrl
        mobile_url = ""
        rank = $null
        published_at = $null
        matched_groups = @()
        summary = $_.Exception.Message
      })
    }
  }

  $output = @()
  foreach ($item in $items) { $output += $item }
  return $output
}

function Fetch-RssItems {
  param(
    [object[]]$Feeds,
    [object[]]$KeywordGroups,
    [int]$MaxItemsPerSource,
    [int]$MaxAgeHours
  )

  $items = New-Object System.Collections.Generic.List[object]
  $cutoff = [DateTimeOffset]::UtcNow.AddHours(-1 * $MaxAgeHours)

  foreach ($feed in $Feeds) {
    try {
      $content = Invoke-Utf8TextRequest -Uri $feed.url -Accept "application/rss+xml, application/xml, text/xml, */*" -TimeoutSec 25
      [xml]$xml = $content
      $rank = 0
      $entries = @()
      $rssNodes = $xml.SelectNodes("//channel/item")
      if ($rssNodes -and $rssNodes.Count -gt 0) {
        $entries = @($rssNodes)
      } else {
        $atomNodes = $xml.GetElementsByTagName("entry")
        if ($atomNodes -and $atomNodes.Count -gt 0) {
          $entries = @($atomNodes)
        }
      }

      foreach ($entry in @($entries | Select-Object -First $MaxItemsPerSource)) {
        $rank++
        $title = Get-FirstXmlText -Node $entry -Names @("title")
        if (-not $title) { continue }

        $link = Get-FirstXmlText -Node $entry -Names @("link")
        if (-not $link) { $link = Get-AtomLink -Entry $entry }

        $publishedRaw = Get-FirstXmlText -Node $entry -Names @("pubDate","published","updated","dc:date")
        $publishedAt = Convert-ToDateTimeOffset $publishedRaw
        if ($publishedAt -and $publishedAt.ToUniversalTime() -lt $cutoff) { continue }

        $summary = Get-FirstXmlText -Node $entry -Names @("description","summary","content")
        $text = "$title`n$summary"
        $matched = @(Get-MatchedGroups -Text $text -Groups $KeywordGroups)
        if (@($matched).Count -eq 0) { continue }

        $items.Add([pscustomobject]@{
          source_type = "rss"
          source_id = $feed.id
          source_name = $feed.name
          title = $title
          url = $link
          mobile_url = ""
          rank = $rank
          published_at = if ($publishedAt) { $publishedAt.ToUniversalTime().ToString("o") } else { $null }
          matched_groups = @($matched)
          summary = ($summary -replace '<[^>]+>', ' ' -replace '\s+', ' ').Trim()
        })
      }
    } catch {
      $items.Add([pscustomobject]@{
        source_type = "error"
        source_id = $feed.id
        source_name = $feed.name
        title = "FETCH_FAILED"
        url = $feed.url
        mobile_url = ""
        rank = $null
        published_at = $null
        matched_groups = @()
        summary = $_.Exception.Message
      })
    }
  }

  $output = @()
  foreach ($item in $items) { $output += $item }
  return $output
}

function Normalize-TitleKey {
  param([string]$Title)
  return (($Title -replace '\s+', ' ').Trim().ToLowerInvariant())
}

$configPath = Join-Path $ConfigDir "config.yaml"
if (-not (Test-Path -LiteralPath $configPath)) {
  throw "Config file not found: $configPath"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$config = Read-TrendRadarLiteConfig -Path $configPath
$keywordGroups = New-KeywordGroups

$hotlistItems = Fetch-HotlistItems -Sources $config.sources -KeywordGroups $keywordGroups -MaxItemsPerSource $MaxItemsPerSource
$rssItems = Fetch-RssItems -Feeds $config.feeds -KeywordGroups $keywordGroups -MaxItemsPerSource $MaxItemsPerSource -MaxAgeHours $RssMaxAgeHours

$allFetchedItems = @()
foreach ($item in @($hotlistItems)) { $allFetchedItems += $item }
foreach ($item in @($rssItems)) { $allFetchedItems += $item }

$seen = @{}
$deduped = New-Object System.Collections.Generic.List[object]
foreach ($item in $allFetchedItems) {
  if ($item.source_type -eq "error") {
    $deduped.Add($item)
    continue
  }
  $key = Normalize-TitleKey -Title $item.title
  if (-not $seen.ContainsKey($key)) {
    $seen[$key] = $true
    $deduped.Add($item)
  }
}

$date = Get-Date -Format "yyyy-MM-dd"
$collectedAt = [DateTimeOffset]::Now.ToString("o")
$candidateItems = @($deduped | Where-Object { $_.source_type -ne "error" })
$errors = @($deduped | Where-Object { $_.source_type -eq "error" })

$result = [pscustomobject]@{
  collected_at = $collectedAt
  config_path = $configPath
  role = "side_radar_candidates_only"
  source_count = @{
    hotlist_sources = @($config.sources).Count
    rss_feeds = @($config.feeds).Count
  }
  item_count = $candidateItems.Count
  error_count = $errors.Count
  items = @($candidateItems)
  errors = @($errors)
}

$jsonPath = Join-Path $OutputRoot "$date-trendradar-ai-radar.json"
$mdPath = Join-Path $OutputRoot "$date-trendradar-ai-radar.md"
$latestJsonPath = Join-Path $OutputRoot "latest-trendradar-ai-radar.json"
$latestMdPath = Join-Path $OutputRoot "latest-trendradar-ai-radar.md"

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $latestJsonPath -Encoding UTF8

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# TrendRadar AI Side Radar - $date")
$md.Add("")
$md.Add("- Role: side radar candidates only")
$md.Add("- Collected: $collectedAt")
$md.Add("- Candidate items: $($candidateItems.Count)")
$md.Add("- Fetch errors: $($errors.Count)")
$md.Add("")
$md.Add("## Candidates")
$md.Add("")

$i = 0
foreach ($item in $candidateItems) {
  $i++
  $groups = ($item.matched_groups -join ", ")
  $published = if ($item.published_at) { $item.published_at } else { "unknown" }
  $rank = if ($null -ne $item.rank) { $item.rank } else { "-" }
  $md.Add("### $i. $($item.title)")
  $md.Add("- Source: $($item.source_name) / $($item.source_type)")
  $md.Add("- Rank: $rank")
  $md.Add("- Published: $published")
  $md.Add("- Matched groups: $groups")
  $md.Add("- Link: $($item.url)")
  if ($item.summary) { $md.Add("- Summary: $($item.summary)") }
  $md.Add("")
}

if ($errors.Count -gt 0) {
  $md.Add("## Fetch Errors")
  $md.Add("")
  foreach ($err in $errors) {
    $md.Add("- $($err.source_name) [$($err.source_id)]: $($err.summary)")
  }
  $md.Add("")
}

$md | Set-Content -LiteralPath $mdPath -Encoding UTF8
$md | Set-Content -LiteralPath $latestMdPath -Encoding UTF8

[pscustomobject]@{
  success = $true
  item_count = $candidateItems.Count
  error_count = $errors.Count
  json_path = $jsonPath
  markdown_path = $mdPath
  latest_json_path = $latestJsonPath
  latest_markdown_path = $latestMdPath
}
