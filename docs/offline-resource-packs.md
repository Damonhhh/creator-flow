# Windows 离线资源包

有些使用者无法稳定访问 GitHub、Hugging Face、npm 或 PyPI。针对这种情况，CreatorFlow 可以把已经下载好的第三方运行文件做成本地离线包，再通过网盘或移动硬盘单独分享。

离线包不提交到 GitHub。这些文件体积大、更新频繁，而且各自受第三方许可证约束。CreatorFlow 仓库只保留工作流、检查逻辑和说明；实际离线文件在分享前单独生成和校验，再通过网盘或移动硬盘交给接收者。

## 当前 Windows x64 分包

| 包 | 解决什么 | 主要内容 | 预计体积 |
| --- | --- | --- | --- |
| `01-CreatorFlow-Core-Windows-x64-Offline.zip` | 基础运行环境 | Python、Node.js、uv、FFmpeg | 约 150 MB |
| `02-CreatorFlow-Material-AgentReach-Windows-x64-Offline.zip` | 素材发现主程序 | Agent Reach 与 Python 3.11 wheelhouse | 约 10 MB |
| `03A-CreatorFlow-TTS-IndexTTS2-v2.0.0-Source-Offline.zip` | 本地 TTS 源码 | IndexTTS2 v2.0.0 源码 | 约 32 MB |
| `03B-CreatorFlow-TTS-IndexTTS2-Models-Offline.zip` | 本地 TTS 模型 | IndexTTS2 模型与原许可证 | 约 8.3 GB |
| `03C-CreatorFlow-TTS-IndexTTS2-Windows-NVIDIA-CUDA128-Runtime-Offline.zip` | NVIDIA 电脑的 TTS 运行依赖 | Python 3.11 / CUDA 12.8 uv 缓存 | 约 7.8 GB |
| `04-CreatorFlow-Assembly-HyperFrames-Windows-x64-Offline.zip` | 成片组装 | HyperFrames、npm 运行依赖、无头浏览器 | 约 656 MB |

接收者按编号解压并运行各包里的安装脚本。只想先跑通工作流的人可以先装 `01`、`02` 和 `04`，旁白使用已有音频；需要本地克隆声音时再安装 `03A`、`03B` 和符合硬件条件的 `03C`。

## 不能装进分享包的内容

- 个人声音样本、生成音频和成片；
- Cookie、Token、API Key、浏览器登录目录；
- `*.local.json`、私人知识库和账号定位；
- 已安装电脑上的 `.venv` 与绝对路径缓存。

每个离线包必须携带来源、版本、SHA256 和第三方许可证说明。IndexTTS 模型不是 CreatorFlow 的 MIT 代码，接收者需要单独遵守模型许可证。显卡驱动也不随包分发；`03C` 只面向说明中标注的 Windows NVIDIA 路线。

如果网络正常，优先使用[环境辅助包](environment-helper-packs.md)按官方来源安装；如果网络受限，再使用对应离线资源包。
