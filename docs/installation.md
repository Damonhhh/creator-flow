# 安装说明

V1 支持 Windows PowerShell 5.1 和 PowerShell 7。先安装 Core，再按实际路线增加可选组件。

## Core

Core 需要以下命令可从 `PATH` 调用：

- `powershell`
- Python 3：`py` 或 `python`
- `ffmpeg`
- `ffprobe`

安装后在仓库根运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-capabilities.ps1 -Profile Core
```

返回 `ready: true` 才代表基础命令齐全。能力探测只检查运行条件，不代表某条视频已经通过内容与视觉验收。

## 本地配置

从四个示例复制本地文件：

```powershell
Copy-Item .\config\workflow.example.json .\config\workflow.local.json
Copy-Item .\config\tts.example.json .\config\tts.local.json
Copy-Item .\config\providers.example.json .\config\providers.local.json
Copy-Item .\config\publish.example.json .\config\publish.local.json
```

这些 `.local.json` 已被 `.gitignore` 排除。相对路径以仓库根为基准，也可以使用环境变量。不要把 Cookie、Token、API Key、声音样本或本机私有路径写入 example 文件。

## 可选组件

- Node.js 与 npm：用于 HyperFrames 等前端渲染路线。
- HyperFrames：参考装配器；也可以换用满足项目契约的其他渲染器。
- IndexTTS2 或其他 TTS：只在选择生成旁白时需要。
- ASR：用于从最终音频重建字幕；有准确字幕时可不装。
- Grok-compatible / MiniMax 等视频适配器：只在 Material 阶段确实需要生成动态素材时启用。
- Uploader：只负责最后上传，不影响发布包生成。

API Base 不带公开默认值。启用第三方视频生成时，从命令行、环境变量或 `config\providers.local.json` 明确填写服务地址和密钥环境变量；缺失配置就把该能力视为不可用。

## Full 探测

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-capabilities.ps1 -Profile Full
```

Full 会按配置检查参考渲染和声音路线。它缺项时应列出缺少的能力，不能把未安装或未实际渲染的组件写成 PASS。

## 缺失依赖的处理原则

探测脚本只报告，不自动安装。缺少外部依赖时，执行者需要先告诉你：缺少什么、用来做什么、官方下载地址、准备执行的命令，以及是否会下载或运行第三方代码。只有得到明确同意后，才能继续安装或初始化。

HyperFrames 项目初始化也遵守这条规则。先运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\initialize-video-renderer.ps1 -ProjectDir <video-dir>
```

它只给出方案。确认后才可加 `-AcceptDownload`。脚本不会代替你自动安装 Node.js、FFmpeg 或其他系统依赖。

下一步回到 [README Quick Start](../README.md)。
