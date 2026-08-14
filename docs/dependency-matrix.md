# 依赖矩阵

| 能力 | Core 必需 | 用途 | 缺失时不可用 | 可接受的降级 |
| --- | --- | --- | --- | --- |
| PowerShell 5.1 / 7 | 是 | 入口、配置解析与质量门 | 全部 stage 的标准脚本 | 无 |
| Python 3 | 是 | 选题、音频与辅助检查 | Python 驱动的处理和测试 | 无 |
| FFmpeg | 是 | 音视频处理、抽帧与编码 | Assembly、QA、wrap-up 的媒体操作 | 无 |
| ffprobe | 是 | 时长、流和编码探测 | QA 无法验证真实媒体 | 无 |
| Node.js / npm | 否 | 前端项目依赖与检查 | HyperFrames 路线 | 使用另一套满足契约的装配器 |
| HyperFrames | 否 | 参考 Assembly 渲染器 | 参考渲染、`npm run check` | 导入其他渲染器产物并重新过 QA |
| IndexTTS2 | 否 | 本地 TTS | IndexTTS2 声音路线 | 使用 existing-audio 或其他 TTS |
| ASR | 否 | 从最终音频重建字幕 | 自动字幕重建 | 提供经过核对的 SRT |
| Grok-compatible adapter | 否 | 第三方生成动态素材 | 对应 Material 分支 | 静态素材、本地动效或其他供应商 |
| MiniMax adapter | 否 | 云端或本地生成动态素材 | 对应 Material 分支 | 静态素材、本地动效或其他供应商 |
| AI Hot / NewsNow compatible endpoints | 否 | 实时发现选题候选 | `-LiveCollection` 的对应来源 | 使用本地 JSON、RSS 或跳过实时发现 |
| Platform Uploader | 否 | 把已验收发布包上传平台 | 自动上传 | 保留发布包并手动发布 |

Core 命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-capabilities.ps1 -Profile Core
```

Full 命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-workflow-capabilities.ps1 -Profile Full
```

`available: false` 代表能力未就绪。可选项不应让 Core 失败；被当前配置选中的路线如果缺能力，则对应 stage 必须停止。先说明用途、官方下载来源和拟执行命令，并征得同意，才能下载或安装。API Base 只从 CLI、环境变量或本地配置读取，仓库不内置第三方中转服务地址。实时发现还必须显式加上 `-LiveCollection`；AI Hot 使用 `--aihot-endpoint` / `AIHOT_PUBLIC_ENDPOINT`，NewsNow 兼容源使用 `-NewsNowApiBase` / `NEWSNOW_API_BASE`，并且只接受 HTTPS。
