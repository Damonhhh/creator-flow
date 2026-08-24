# CreatorFlow Material：Agent Reach 环境包

Agent Reach 用在 Material 阶段，帮助 Agent 搜索网页、视频、社交平台和代码仓库中的一手来源。它是可选能力；没有它，也可以用浏览器检索、已有工具或自己提供的素材继续。

这个包不包含 Agent Reach 源码。安装时会从官方 GitHub 仓库下载 CreatorFlow 已锁定的版本，并安装到当前用户的 `.creatorflow\tools`，不会写进视频项目，也不会替你登录账号或保存凭据。

## 第一步：只检查

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start.ps1 `
  -CreatorFlowRoot 'D:\你的目录\creator-flow'
```

## 第二步：确认后下载

先阅读终端列出的用途、来源、命令和降级路线。愿意继续时再运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start.ps1 `
  -CreatorFlowRoot 'D:\你的目录\creator-flow' `
  -AcceptAction agent-reach
```

前置条件是 Core 中的 Python 3 已就绪。脚本会创建独立 Python 环境、安装锁定版本并运行安全检查和 `doctor`。部分网站能力仍可能需要你之后单独安装渠道工具或登录；这次授权不包含登录。

官方来源：https://github.com/Panniantong/agent-reach
