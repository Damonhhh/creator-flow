# zimeiti-video-workflow

这是一套从真实生产项目中抽出的自媒体视频链路：

`选题 → 评分 → 脚本 → 素材 → visual plan → 组装 → 渲染 → QA → 发布包 → 收尾`

仓库交付的是链路，不是一台 **one-click fully automated account machine**。它不会替你决定账号定位，也不附带某个人的声音、判断、写作习惯或知识库。你需要补入自己的三个长期输入，系统才会逐渐成为你的工作流。

V1 面向 Windows。Core 使用 PowerShell、Python、FFmpeg 和 ffprobe；HyperFrames、IndexTTS2、ASR、视频生成适配器与上传工具按需启用。

## Quick Start

### 1. 克隆并进入仓库

```powershell
git clone https://github.com/<your-account>/zimeiti-video-workflow.git
cd .\zimeiti-video-workflow
```

如果远程仓库尚未创建，可直接在本地仓库根目录执行后续命令。

### 2. 检查 Core 能力

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-capabilities.ps1 -Profile Core
```

只有 `ready: true` 才继续。缺项按[安装说明](docs/installation.md)处理；可选能力与降级方式见[依赖矩阵](docs/dependency-matrix.md)。

### 3. 创建四个本地配置

```powershell
Copy-Item .\config\workflow.example.json .\config\workflow.local.json
Copy-Item .\config\tts.example.json .\config\tts.local.json
Copy-Item .\config\providers.example.json .\config\providers.local.json
Copy-Item .\config\publish.example.json .\config\publish.local.json
```

`.local.json` 不进入 Git。先保留默认的 `existing-audio` 模式也可以，不需要为了跑通主链先安装 TTS。

### 4. 初始化最小视频项目

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\new-video-project.ps1 `
  -Name '2026-08-12-minimal-demo' `
  -Destination .\videos
```

脚本不会覆盖已有目录。新项目从 `Topic / topic_ready` 开始，`review\` 和 `publish\` 保持为空。

### 5. 填入你自己的三个输入

打开新项目并填写：

- `account-profile.md`：账号服务谁、持续讲什么、不讲什么。
- `writing-style.md`：语气、句式、禁用表达和真实改写样本。
- `knowledge-sources.md`：可信来源、复核规则与禁止公开的边界。

再核对 `source-content.md`。示例内容只是可运行起点，不是你的账号结论。

### 6. 选择声音路线

- 已有旁白：保持 `config\tts.local.json` 中的 `mode` 为 `existing-audio`，在 Script TTS 阶段提供实际音频和字幕。
- 需要 TTS：填写对应本地工具路径或接入自己的适配器，再运行 `-Profile Full` 检查。不要把声音样本、音色 ID 或凭据提交到仓库。

如果检查发现缺少外部工具，系统会先说明它的用途、下载来源和拟执行命令，再询问你是否愿意安装。没有明确同意，不会自动下载或安装。

### 7. 在 Codex 中依次执行六个 stage

让 Codex 使用 `.agents\skills\zimeiti-video-workflow\SKILL.md`，每次只推进当前阶段。例如：

```text
使用 zimeiti-video-workflow，读取 videos\2026-08-12-minimal-demo\project-state.json，完成当前 Topic 阶段并保存证据。
```

随后依次推进 `Topic`、`Script TTS`、`Material`、`Assembly`、`QA`、`Publish Wrap Up`。每个阶段的输入、输出、检查和返回条件都在[六阶段执行图](.agents/skills/zimeiti-video-workflow/references/pipeline.md)中。

第一次进入 Assembly 且项目还没有渲染器时，先只查看初始化方案：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\initialize-video-renderer.ps1 `
  -ProjectDir .\videos\2026-08-12-minimal-demo
```

该命令不会下载内容。确认用途和来源后，如愿意下载，再明确加上 `-AcceptDownload`。

### 8. 自动 QA 后进行人工关键帧复核

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-video-draft-qa.ps1 -VideoDir .\videos\2026-08-12-minimal-demo
```

脚本 PASS 不等于成片可发。必须实际打开关键帧，检查首帧、字幕、证据卡、空素材位、转场、静态停留、裁切和尾帧；接受结果写入 `review\human-visual-review-vNN.md`，并绑定当前成片 SHA256。

### 9. 生成发布包

人工复核通过后再执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-video-wrap-up.ps1 `
  -VideoDir .\videos\2026-08-12-minimal-demo `
  -Collection 'my-series'
```

默认目标是得到可检查的 `publish\` 包，不是自动替你发布。发布包还需要竖版封面、横版封面和发布文案复核记录；规则见[项目契约](docs/project-contract.md)和[通用封面协议](docs/cover-system.md)。

## 边界

- 个人配置只放 `.local.json` 或项目内未提交的个人文件。
- API Base 只从 CLI、环境变量或 `providers.local.json` 读取；公开仓库不预设第三方中转地址。
- 自动 QA 与 human-visual-review 是两道不同的门。
- 默认生成发布包，不自动上传。

遇到问题先看[故障排查](docs/troubleshooting.md)和[隐私边界](docs/privacy-boundary.md)。

## 发布前自检

如果你准备 fork、改造或重新发布这套工作流，先运行 Core 发布门禁：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-public-release.ps1 -Profile Core
```

它会核对 Git 工作区、白名单文件、SHA256、隐私扫描和 Core 测试。`Full` 还需要完整渲染环境与一份已经人工复核的真实视频项目；缺少的能力会直接列出，不会显示成假 PASS。

## License

[MIT](LICENSE)
