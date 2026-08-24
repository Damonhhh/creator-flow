# CreatorFlow Assembly：HyperFrames 环境包

HyperFrames 是 CreatorFlow 的参考成片装配器。它需要 Node.js、npm、npx、FFmpeg 和 ffprobe。你也可以换用满足 CreatorFlow 项目契约的其他渲染器。

这个包不携带 Node.js、HyperFrames 或 FFmpeg。第一次初始化时，CreatorFlow 会在你指定的视频项目中创建 `hyperframes-app`，并通过 npm 下载锁定版本 `hyperframes@0.7.55`。

## 第一步：只检查

先创建一个 CreatorFlow 视频项目，再运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start.ps1 `
  -CreatorFlowRoot 'D:\你的目录\creator-flow' `
  -ProjectDir 'D:\你的目录\creator-flow\videos\你的项目'
```

如果缺少 Node.js 或 FFmpeg，可以打开官方下载页：

```powershell
.\start.ps1 `
  -CreatorFlowRoot 'D:\你的目录\creator-flow' `
  -ProjectDir 'D:\你的目录\creator-flow\videos\你的项目' `
  -OpenPrerequisitePages
```

安装系统前置条件并重新打开 PowerShell。检查结果明确提出 `hyperframes` 动作后，才执行：

```powershell
.\start.ps1 `
  -CreatorFlowRoot 'D:\你的目录\creator-flow' `
  -ProjectDir 'D:\你的目录\creator-flow\videos\你的项目' `
  -AcceptAction hyperframes
```

这次授权只负责创建当前项目的渲染工程，不代表成片已经通过 QA，也不包含上传。

官方来源：

- Node.js：https://nodejs.org/en/download
- FFmpeg：https://ffmpeg.org/download.html
- HyperFrames：https://www.npmjs.com/package/hyperframes
