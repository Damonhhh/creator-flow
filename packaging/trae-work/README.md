# CreatorFlow for TRAE Work

这是交付给 TRAE Work 用户的自媒体视频工作流包，适用于 Windows 桌面端的 Code Mode。

它把一次内容生产拆成六个可检查的阶段：

`Topic → Script TTS → Material → Assembly → QA → Publish Wrap Up`

你可以跑完整链路，也可以只处理当前阶段。包内提供 Skill、脚本、检查规则和项目模板；账号定位、个人判断、写作风格、知识来源和本次选题需要由使用者自己填写。

## 项目主页

CreatorFlow 的公开仓库是 [https://github.com/Damonhhh/creator-flow](https://github.com/Damonhhh/creator-flow)。需要查看后续更新、反馈问题或重新获取项目时，可以从这里进入。

直播课发放的 ZIP 是提前检查过的固定版本。上课和第一次安装建议先使用课程包，避免仓库后续更新影响现场操作。

## 第一次使用

1. 解压本包，并用 TRAE Work 桌面端 Code Mode 打开 `CreatorFlow-TRAE-Work` 文件夹。
2. 进入 `Settings → Rule & Skills → Skills → Create`。
3. 分别导入：
   - `.agents/skills/zimeiti-video-workflow/SKILL.md`
   - `.agents/skills/zimeiti-video-wrap-up/SKILL.md`
4. 在仓库根目录运行包体校验：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-trae-work-package.ps1 -PackageRoot .
```

5. 检查 Core 能力：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-capabilities.ps1 -Profile Core
```

如果缺少 PowerShell、Python、FFmpeg 或 ffprobe，先让 TRAE Work 列出缺失项、用途、官方下载来源、拟执行命令和风险。只有你明确同意后，才能下载或安装。

## 创建第一个项目

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\new-video-project.ps1 `
  -Name 'my-first-video' `
  -Destination .\videos
```

创建后先填写：

- `account-profile.md`：账号服务谁、持续讲什么、明确不讲什么。
- `writing-style.md`：语气、句式、禁用表达和真实改写样本。
- `knowledge-sources.md`：可信来源、复核规则和禁止公开的边界。
- `source-content.md`：这次要处理的选题、素材、证据与初步判断。

然后把下面这段发给 TRAE Work：

```text
请使用 CreatorFlow 的 zimeiti-video-workflow，读取当前项目的 project-state.json，只完成 currentStage 对应的阶段并保存证据。不要提前推进下一阶段；遇到缺失依赖，或需要下载、安装、登录、配置凭据时，先说明用途、官方下载来源、拟执行命令和风险，得到我明确同意后再继续。
```

## 交付标准

- 文件存在不等于阶段完成，每个阶段都要保存对应证据。
- 自动 QA 通过后仍要检查关键帧。
- 人工视觉复核必须绑定当前成片的 SHA256。
- 默认生成可复核的 `publish\` 发布包，不自动上传平台。
- `.local.json`、Cookie、Token、API Key、声音样本、个人项目和本机绝对路径不得进入共享包。

完整步骤见 [安装与第一次运行](docs/installation.md)，依赖说明见 [依赖矩阵](docs/dependency-matrix.md)，工作流阶段见 [执行图](.agents/skills/zimeiti-video-workflow/references/pipeline.md)。

TRAE 的 Skill 导入方式可参考其[官方 Agent Skills 指南](https://www.trae.ai/blog/trae_tutorial_0115)。

## 适用边界

本包验证的是 TRAE Work 桌面端 Code Mode，因为完整链路需要访问本地文件并运行 PowerShell、Python 和 FFmpeg。网页端、移动端和纯对话模式不在本交付包的完整运行保证范围内。

## License

[MIT](LICENSE)
