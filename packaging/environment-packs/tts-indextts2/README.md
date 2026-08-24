# CreatorFlow Script TTS：IndexTTS2 环境包

IndexTTS2 用于本地生成旁白。它是可选能力：已有配音和核对过的 SRT 时，可以继续使用 `existing-audio`，不用安装这个包。

这个辅助包不携带源码、模型、声音样本或显卡驱动。源码、Python 运行环境和模型权重必须分三次授权，不能一次全部下载。

## 存储位置

IndexTTS2 源码、环境、模型和缓存会占用较多空间。C 盘空间不足时，先在其他盘准备目录，例如 `D:\CreatorFlowTools`，然后每次都传入：

```powershell
-StorageRoot 'D:\CreatorFlowTools'
```

脚本会把 Hugging Face、uv、pip 和 ModelScope 缓存一起指向这个目录，减少安装器偷偷占满 C 盘的风险。

## 使用顺序

1. 只检查当前状态：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start.ps1 `
  -CreatorFlowRoot 'D:\你的目录\creator-flow' `
  -StorageRoot 'D:\CreatorFlowTools'
```

2. 缺少 Git 或 uv 时，打开它们的官方下载页：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start.ps1 `
  -CreatorFlowRoot 'D:\你的目录\creator-flow' `
  -StorageRoot 'D:\CreatorFlowTools' `
  -OpenPrerequisitePages
```

3. 根据每次检查实际提出的动作，依次执行。每次只允许一个动作：

```powershell
# 下载锁定的 IndexTTS2 v2.0.0 源码
.\start.ps1 -CreatorFlowRoot 'D:\你的目录\creator-flow' -StorageRoot 'D:\CreatorFlowTools' -AcceptAction indextts-source

# 安装隔离的 Python 运行环境
.\start.ps1 -CreatorFlowRoot 'D:\你的目录\creator-flow' -StorageRoot 'D:\CreatorFlowTools' -AcceptAction indextts-runtime

# 下载大体积模型权重
.\start.ps1 -CreatorFlowRoot 'D:\你的目录\creator-flow' -StorageRoot 'D:\CreatorFlowTools' -AcceptAction indextts-model
```

脚本只允许执行当前检查真正提出的动作。源码没完成时不能越过它直接下载模型。

安装完成后，还要在 CreatorFlow 的 `config\tts.local.json` 中选择 IndexTTS2 路线，并填写你自己的本地参考音频路径。声音样本不得放进公开仓库或这个压缩包。

官方来源：

- IndexTTS2：https://github.com/index-tts/index-tts/tree/v2.0.0
- 模型：https://huggingface.co/IndexTeam/IndexTTS-2
- uv：https://docs.astral.sh/uv/getting-started/installation/
- Git：https://git-scm.com/download/win
