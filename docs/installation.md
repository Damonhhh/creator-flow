# 安装与第一次运行

V1 支持 Windows PowerShell 5.1 和 PowerShell 7。先跑通 Core，再按实际生产路线增加渲染、TTS、ASR、视频生成或上传组件。

## 1. 克隆仓库

```powershell
git clone https://github.com/Damonhhh/creator-flow.git
cd .\creator-flow
```

## 2. 检查 Core 能力

Core 需要以下命令可从 `PATH` 调用：

- `powershell`
- Python 3：`py` 或 `python`
- `ffmpeg`
- `ffprobe`

运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-capabilities.ps1 -Profile Core
```

只有 `ready: true` 才代表基础命令齐全。能力探测只检查运行条件，不代表某条视频已经通过内容与视觉验收。

## 3. 创建本地配置

```powershell
Copy-Item .\config\workflow.example.json .\config\workflow.local.json
Copy-Item .\config\tts.example.json .\config\tts.local.json
Copy-Item .\config\providers.example.json .\config\providers.local.json
Copy-Item .\config\publish.example.json .\config\publish.local.json
```

这些 `.local.json` 已被 `.gitignore` 排除。相对路径以仓库根为基准，也可以使用环境变量。不要把 Cookie、Token、API Key、声音样本或本机私有路径写入 example 文件。

先保留 `config\tts.local.json` 默认的 `existing-audio` 模式也可以。跑通主链不要求预先安装 TTS。

## 4. 初始化视频项目

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\new-video-project.ps1 `
  -Name '2026-08-14-my-first-video' `
  -Destination .\videos
```

脚本不会覆盖已有目录。新项目从 `Topic / topic_ready` 开始，`review\` 和 `publish\` 保持为空，不会预填通过记录。

## 5. 填写个人输入

打开新项目并完成：

- `account-profile.md`：账号服务谁、持续讲什么、不讲什么。
- `writing-style.md`：语气、句式、禁用表达和真实改写样本。
- `knowledge-sources.md`：可信来源、复核规则与禁止公开的边界。
- `source-content.md`：当前选题、已有内容、证据与初步判断。

模板提供一个可运行起点。账号结论仍由你填写；私人知识、凭据和声音样本只留在本地。

## 6. 选择声音路线

- 已有旁白：保持 `mode` 为 `existing-audio`，在 Script TTS 阶段提供实际音频和字幕。
- 需要 TTS：填写本地工具路径或接入自己的适配器，再运行 `-Profile Full` 检查。
- 已有准确字幕：可以跳过 ASR。
- 没有准确字幕：接入 ASR 后，从最终音频重建字幕。

不要把声音样本、音色 ID 或凭据提交到仓库。

## 7. 在 Codex 中推进六个阶段

让 Codex 使用 `.agents\skills\zimeiti-video-workflow\SKILL.md`，每次从 `project-state.json` 读取当前阶段：

```text
使用 zimeiti-video-workflow，读取 videos\2026-08-14-my-first-video\project-state.json，只完成当前阶段并保存证据。遇到缺失依赖或需要下载、安装、登录、配置凭据时先停下，说明用途、官方来源、拟执行命令和风险，未经我明确同意不要继续。
```

流程依次推进 `Topic`、`Script TTS`、`Material`、`Assembly`、`QA`、`Publish Wrap Up`。每个阶段的输入、输出、检查和返回条件都在[六阶段执行图](../.agents/skills/zimeiti-video-workflow/references/pipeline.md)中。

## 8. 按需初始化渲染器

第一次进入 Assembly 且项目还没有渲染器时，先查看方案：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\initialize-video-renderer.ps1 `
  -ProjectDir .\videos\2026-08-14-my-first-video
```

这条命令不会下载内容。确认用途和来源后，如果愿意下载，再明确加上 `-AcceptDownload`。

HyperFrames 是参考装配器，也可以换成满足[项目契约](project-contract.md)的其他渲染器。

## 9. 自动 QA 与人工关键帧复核

生成候选成片后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-video-draft-qa.ps1 `
  -VideoDir .\videos\2026-08-14-my-first-video
```

脚本 PASS 不等于成片可发。还要实际打开关键帧，检查首帧、字幕、证据卡、空素材位、转场、静态停留、裁切和尾帧。接受结果写入 `review\human-visual-review-vNN.md`，并绑定当前成片 SHA256。

## 10. 生成发布包

人工复核通过后再执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-video-wrap-up.ps1 `
  -VideoDir .\videos\2026-08-14-my-first-video `
  -Collection 'my-series'
```

默认只生成可检查的 `publish\` 包，不会替你上传。发布包还需要竖版封面、横版封面和发布文案复核记录；具体规则见[项目契约](project-contract.md)和[通用封面协议](cover-system.md)。

## 可选组件

- Node.js 与 npm：用于 HyperFrames 等前端渲染路线。
- HyperFrames：参考装配器；也可以换用兼容渲染器。
- IndexTTS2 或其他 TTS：只在需要生成旁白时启用。
- ASR：用于从最终音频重建字幕。
- Grok-compatible、MiniMax 等视频适配器：只在 Material 阶段确实需要生成动态素材时启用。
- Uploader：只负责最后上传，不影响发布包生成。

API Base 没有公开默认值。启用第三方视频生成时，从命令行、环境变量或 `config\providers.local.json` 明确填写服务地址和密钥环境变量。缺失配置就把该能力视为不可用。

### 可选的实时选题发现

实时发现默认关闭，也不会自动下载 TrendRadar 或替你选择数据服务。启用前先确认服务来源、使用条款和网络风险，再准备自己的 HTTPS 地址：

```powershell
$env:AIHOT_PUBLIC_ENDPOINT = 'https://your-provider.example/api/items'
$env:NEWSNOW_API_BASE = 'https://your-provider.example/api/s'

powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-ai-daily-briefing-chain.ps1 `
  -LiveCollection `
  -TrendRadarConfigDir .\config\trendradar.local
```

也可以不用环境变量，改传 `-SignalRadarAIHotEndpoint` 和 `-TrendRadarNewsNowApiBase`。地址必须是绝对 HTTPS URL。TrendRadar 平台源还需要你在 `-TrendRadarConfigDir` 指向的目录中创建 `config.yaml`：

```yaml
platforms:
  sources:
    - id: "your-source-id"
      name: "Your source"
      expected_domain: "example.com"
rss:
  feeds: []
```

如果缺少配置，脚本会停下并说明所需参数，不会自行下载依赖、登录账号或写入凭据。只使用本地 AI Hot JSON 时，可传 `-SignalRadarAIHotInputPath`，不需要启用实时网络采集。

## Full 探测

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-capabilities.ps1 -Profile Full
```

Full 会按配置检查参考渲染和声音路线。它缺项时应列出缺少的能力，不能把未安装或未实际渲染的组件写成 PASS。

## 缺失依赖的处理原则

探测脚本只报告，不自动安装。缺少外部依赖时，执行者需要先告诉你：

- 缺少什么；
- 它用来做什么；
- 官方下载地址；
- 准备执行的命令；
- 是否会下载或运行第三方代码，是否涉及登录或凭据。

只有得到明确同意后，才能继续安装、初始化、登录或写入凭据。无法安装时，应说明现有降级路线，例如使用已有音频、已核对 SRT、静态或本地动效、其他兼容渲染器。

遇到错误再看[故障排查](troubleshooting.md)和[依赖矩阵](dependency-matrix.md)。

下一步回到 [README](../README.md)。
