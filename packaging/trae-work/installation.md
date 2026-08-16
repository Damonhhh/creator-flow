# 安装与第一次运行

本指南面向 TRAE Work 桌面端 Code Mode。完整 CreatorFlow 会读写本地项目并调用 PowerShell、Python、FFmpeg 和 ffprobe。

CreatorFlow 公开仓库：[https://github.com/Damonhhh/creator-flow](https://github.com/Damonhhh/creator-flow)。直播课请先使用提前检查过的 ZIP；需要查看后续更新或反馈问题时，再进入公开仓库。

## 1. 解压并打开

把 `CreatorFlow-TRAE-Work.zip` 解压到一个可写的本地目录，再用 TRAE Work 的 Code Mode 打开解压后的根文件夹。

不要把包放进临时下载目录长期运行。项目文件、配置和渲染产物会持续写入当前目录。

## 2. 校验交付包

在 TRAE Work 终端中运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-trae-work-package.ps1 -PackageRoot .
```

校验会核对文件清单、SHA256、必需文件、敏感路径和品牌包禁词。只有出现 `TRAE Work package validation: PASS` 才继续。

## 3. 导入两个 Skill

进入 `Settings → Rule & Skills → Skills → Create`，分别导入：

- `.agents/skills/zimeiti-video-workflow/SKILL.md`：六阶段主流程。
- `.agents/skills/zimeiti-video-wrap-up/SKILL.md`：发布包与收尾。

导入后可以直接点名 Skill，也可以让 TRAE Work 根据任务自动选择。

## 4. 检查 Core 能力

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-capabilities.ps1 -Profile Core
```

Core 需要：

- PowerShell 5.1 或 7
- Python 3
- FFmpeg
- ffprobe

`ready: true` 才表示核心链路可继续。Node.js、HyperFrames、IndexTTS2、ASR、视频生成适配器和上传工具都是按路线启用的可选能力。

如果发现缺失项，让 TRAE Work 先说明：

1. 缺少什么；
2. 它负责哪一步；
3. 官方下载来源；
4. 准备执行的命令；
5. 是否涉及第三方代码、登录或凭据。

没有得到你的明确同意，不得自动下载、安装、登录或写入凭据。

进入 Script TTS、Material 或 Assembly 时，使用统一的阶段检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\resolve-workflow-dependencies.ps1 `
  -Stage Material
```

默认只展示方案。确认后，每次只批准一个 `-AcceptAction`；安装完成后脚本会重新检查。Agent Reach 安装在当前用户目录，IndexTTS2 的源码、运行环境和模型分别确认，声音样本仍只保存在本地。

## 5. 建立本地配置

```powershell
Copy-Item .\config\workflow.example.json .\config\workflow.local.json
Copy-Item .\config\tts.example.json .\config\tts.local.json
Copy-Item .\config\providers.example.json .\config\providers.local.json
Copy-Item .\config\publish.example.json .\config\publish.local.json
```

只修改 `*.local.json`。这些文件不会进入共享包，也不要把 Cookie、Token、API Key 或本机绝对路径复制到示例文件。

## 6. 创建视频项目

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\new-video-project.ps1 `
  -Name 'my-first-video' `
  -Destination .\videos
```

项目从 `Topic / topic_ready` 开始。先填写：

- `account-profile.md`
- `writing-style.md`
- `knowledge-sources.md`
- `source-content.md`

模板只提供结构，不替你决定账号定位、内容观点或写作风格。

## 7. 推进当前阶段

把下面这段发给 TRAE Work：

```text
请使用 CreatorFlow 的 zimeiti-video-workflow，读取 videos\my-first-video\project-state.json。只处理 currentStage 对应阶段，按 Skill 规定保存证据并更新状态；不要提前推进。遇到缺失依赖，或需要下载、安装、登录、配置凭据时，先停下并征得我的明确同意。
```

六个阶段及核心证据：

| 阶段 | 主要工作 | 核心证据 |
| --- | --- | --- |
| Topic | 选题、评分、风险和否决理由 | 选题决策与来源 |
| Script TTS | 录音稿、音频、字幕和画幅 | 锁定脚本、真实音频、SRT |
| Material | 来源、素材和逐句视觉任务 | `source-candidates.md`、`material-beat-map.md` |
| Assembly | 工程组装和候选成片 | 工程检查、渲染文件 |
| QA | 自动检查与人工关键帧复核 | QA 报告、绑定成片哈希的人工复核 |
| Publish Wrap Up | 封面、文案、发布包和收尾 | `publish\`、状态与同步记录 |

## 8. 初始化渲染器

第一次进入 Assembly 且项目没有渲染器时，先查看方案：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\resolve-workflow-dependencies.ps1 `
  -Stage Assembly `
  -ProjectDir .\videos\my-first-video
```

这条命令只展示计划，不下载。确认愿意下载后再明确加上 `-AcceptAction hyperframes`。

## 9. QA 与收尾

候选成片生成后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-video-draft-qa.ps1 `
  -VideoDir .\videos\my-first-video
```

脚本 PASS 之后仍要查看关键帧，并保存人工视觉复核记录。只有复核文件绑定当前成片 SHA256，才能进入发布包收尾。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-video-wrap-up.ps1 `
  -VideoDir .\videos\my-first-video `
  -Collection 'my-collection'
```

默认只准备发布包，不自动上传。

## 10. 常见边界

- 不要把 `.local.json`、`.env`、Cookie、Token、API Key、声音样本和个人项目交给品牌方或提交到仓库。
- API Base 只能从命令行、环境变量或本地配置读取。
- 实时发现源默认不联网，需要显式启用并提供 HTTPS 地址。
- 需要登录或写入平台凭据的步骤必须单独确认。
- 如果脚本与画面实际结果冲突，以可见成片和人工复核为准。

更完整的能力和降级路线见 [依赖矩阵](dependency-matrix.md)，隐私要求见 [隐私边界](privacy-boundary.md)，故障处理见 [故障排查](troubleshooting.md)。
