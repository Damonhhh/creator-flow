# macOS Core Beta

CreatorFlow 现在提供一条可测试的 macOS Core 路线，覆盖 Apple Silicon 和 Intel Mac。它的目标是先让 Mac 用户跑通项目初始化、已有音频、素材整理、组装前检查和基础 QA，而不是把 Windows 上的所有本地模型原样搬过去。

## 当前能做什么

这条 Beta 路线支持：

- 检查 PowerShell 7、Python 3、FFmpeg 与 ffprobe；
- 创建标准视频项目，推进 Topic、Script TTS 和 Material；
- 使用已有旁白与已核对字幕，不安装本地声音克隆；
- 检查 Agent Reach 等素材能力，缺失时先给方案，得到同意后才安装；
- 检查 Node.js、FFmpeg 和 HyperFrames 组装条件；
- 继续使用项目契约、来源记录、QA 证据和发布包规则。

暂不承诺：IndexTTS2 本地声音克隆、CUDA 环境、Windows 离线资源包和自动上传工具。需要这些能力时，可以改用已有音频、云端 TTS、其他兼容装配器或手动发布。

## 准备环境

macOS 只使用 PowerShell 7，命令名是 `pwsh`。Core 还需要 Python 3、FFmpeg、ffprobe 和 Git；进入 HyperFrames 组装时再准备 Node.js 22 或更高版本。

如果使用 Homebrew，可以自行执行：

```bash
brew install --cask powershell
brew install python ffmpeg node
```

这些是系统环境安装，会写入 Homebrew 管理的目录。CreatorFlow 不会替你静默执行。没有 Homebrew 时，请按各工具官网说明安装。

## 第一次运行

```powershell
git clone https://github.com/Damonhhh/creator-flow.git
cd creator-flow

pwsh -NoProfile -File ./scripts/test-workflow-capabilities.ps1 -Profile Core

Copy-Item ./config/workflow.example.json ./config/workflow.local.json
Copy-Item ./config/tts.example.json ./config/tts.local.json
Copy-Item ./config/providers.example.json ./config/providers.local.json
Copy-Item ./config/publish.example.json ./config/publish.local.json

pwsh -NoProfile -File ./scripts/new-video-project.ps1 `
  -Name '2026-08-24-my-first-video' `
  -Destination ./videos
```

看到 `ready: true`，并且 `videos/2026-08-24-my-first-video/project-state.json` 已生成，才算 Core 起点就绪。建议第一次保留 `existing-audio`，先把自己的旁白和字幕放进项目，不要一上来安装声音克隆。

进入素材阶段时：

```powershell
pwsh -NoProfile -File ./scripts/resolve-workflow-dependencies.ps1 -Stage Material
```

进入组装阶段时：

```powershell
pwsh -NoProfile -File ./scripts/resolve-workflow-dependencies.ps1 `
  -Stage Assembly `
  -ProjectDir ./videos/2026-08-24-my-first-video
```

这两条命令默认只检查并解释，不会直接下载。只有你明确同意某个 `-AcceptAction` 后，Agent 才能执行对应动作。

## Beta 怎么算通过

仓库会在 GitHub 的 Intel 与 Apple Silicon macOS runner 上执行 Core 烟雾测试，检查跨平台路径、能力探测、项目初始化、素材目录和组装授权门。CI 通过只能说明基础脚本可运行，不等于某一条视频已经通过人工验收。

因为维护者目前没有 Mac 实机，这一版仍标为 Beta。第一位真实用户跑完后，请在 Issue 中写明 Mac 芯片、macOS 版本、PowerShell 版本、失败命令和完整错误信息；不要上传 Token、Cookie、声音样本或本机隐私配置。
