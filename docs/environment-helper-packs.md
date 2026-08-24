# 环境辅助包（轻量版）

CreatorFlow 的依赖按生产阶段分开。仓库提供四个轻量辅助包，帮助网络正常的 Windows 使用者检查环境，并在本人确认后从官方来源下载需要的组件。

如果使用者无法稳定访问 GitHub、Hugging Face、npm 或 PyPI，不要让他反复重试这些轻量包。改用已经包含第三方文件的 [Windows 离线资源包](offline-resource-packs.md)，通过网盘或移动硬盘单独分享。

| 压缩包 | 什么时候需要 | 包含什么 | 不包含什么 |
| --- | --- | --- | --- |
| `CreatorFlow-Core-Windows.zip` | 第一次运行前 | Core 检查、官方下载入口、说明 | Python、FFmpeg 二进制 |
| `CreatorFlow-Material-AgentReach.zip` | 需要自动发现素材来源时 | Agent Reach 检查与单动作授权入口 | 登录状态、Cookie、渠道凭据 |
| `CreatorFlow-TTS-IndexTTS2.zip` | 需要本地生成旁白时 | 分步安装入口、缓存迁移参数、说明 | 模型权重、声音样本、显卡驱动 |
| `CreatorFlow-Assembly-HyperFrames.zip` | 需要参考渲染器组装成片时 | Node/FFmpeg 检查、项目级初始化入口 | Node.js、FFmpeg、预装 npm 缓存 |

## 为什么公开仓库不直接携带第三方环境

- 第三方软件和模型有自己的许可证、版本与分发规则，需要作为独立离线包处理。
- 模型与 `node_modules` 体积大，很快过期，也可能不适合另一台电脑。
- 登录、Cookie、API Key、声音样本和本机路径不能进入公开包。
- 每台电脑的磁盘、显卡和 PATH 不同，安装后必须重新检测，不能靠“文件已经下载”判断成功。

四个包都遵守同一条规则：默认只检查和说明；需要下载时，使用者必须传入一个准确的 `-AcceptAction`。一次授权只执行一个动作。

## 生成压缩包

在 CreatorFlow 根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\export-environment-helper-packages.ps1 -Force
```

输出位置：

```text
.generated\environment-packs\
  CreatorFlow-Core-Windows.zip
  CreatorFlow-Material-AgentReach.zip
  CreatorFlow-TTS-IndexTTS2.zip
  CreatorFlow-Assembly-HyperFrames.zip
  environment-packs-manifest.json
```

这些轻量压缩包只包含文本脚本、说明和校验清单。生成脚本会拒绝把 `.exe`、`.dll`、模型权重、密钥或本机绝对路径打进包里。实际二进制和模型只进入独立分发的离线资源包，不进入 GitHub。
