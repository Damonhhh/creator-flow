# CreatorFlow Core Windows 环境包

这个包帮助你检查 CreatorFlow 的基础运行环境。它不包含 Python、FFmpeg 或其他第三方二进制文件，也不会静默安装软件。

Core 需要：

- Windows PowerShell 5.1 或 PowerShell 7
- Python 3
- FFmpeg
- ffprobe（随 FFmpeg 提供）

## 使用方法

先把 CreatorFlow 仓库下载并解压，再在 PowerShell 中运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start.ps1 `
  -CreatorFlowRoot 'D:\你的目录\creator-flow'
```

脚本只检查，不会下载。缺少组件时，可以让它打开官方下载页：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start.ps1 `
  -CreatorFlowRoot 'D:\你的目录\creator-flow' `
  -OpenOfficialDownloads
```

按官方安装器完成安装后，关闭并重新打开 PowerShell，再运行第一次检查。只有结果显示 `ready: true` 才代表 Core 已经就绪。

官方来源：

- Python：https://www.python.org/downloads/windows/
- FFmpeg：https://ffmpeg.org/download.html
- PowerShell：https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows

如果电脑无法安装 Core，CreatorFlow 的本地完整视频链路不能运行。可以换一台允许安装本地工具的 Windows 电脑，或者只阅读仓库和案例。
