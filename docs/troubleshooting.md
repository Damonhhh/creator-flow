# 故障排查

## Core 显示 `ready: false`

先看输出中 `required: true` 且 `available: false` 的项目。确认 PowerShell、Python、ffmpeg 和 ffprobe 能从新的终端直接调用，再重新运行 Core 探测。修改 PATH 后要新开终端。

## Full 缺少 HyperFrames 或 IndexTTS2

Full 是所选完整路线的能力检查，不是最低运行门。没有 HyperFrames 时可以使用另一套装配器；没有 IndexTTS2 时把 `tts.local.json` 保持为 `existing-audio`。未安装的路线应标为不可用，不能写成 PASS。

若选择 HyperFrames，可先运行 `initialize-video-renderer.ps1 -ProjectDir <video-dir>` 查看缺项和拟执行命令。只有你确认愿意下载后，才加 `-AcceptDownload`。脚本不会静默安装 Node.js、FFmpeg 或 TTS。

## 找不到 `.local.json`

在仓库根把 `config\*.example.json` 分别复制为同名 `.local.json`。不要修改 example 文件来保存个人路径或密钥。相对路径以仓库根为基准。

## `new-video-project.ps1` 拒绝创建

脚本不会覆盖已有项目。换一个新的 `-Name`，或明确选择另一个空的 `-Destination`；不要为了重跑模板删除已有制作内容。

## ffmpeg 能运行，但 QA 仍失败

能力存在只说明命令可调用。检查输入视频是否真实可读、音轨和字幕是否匹配、路径是否指向当前 render。自动 QA 通过后仍需要 human review，脚本不会替人判断画面是否可读、裁切是否合理或证据是否可信。

## 第三方视频生成不可用

确认相应 provider 已在 `providers.local.json` 启用，并从 CLI、环境变量或本地配置提供 API Base 与密钥环境变量。仓库不提供默认中转地址。若配置不完整，回到静态素材、本地动效或其他已验证供应商。

## wrap-up 拒绝生成发布包

按报错补齐当前 render、自动 QA、绑定 render SHA256 的人工视觉复核、双封面与发布文案复核。不要手工创建虚假 PASS 文件绕过门槛。

仍无法定位时，先读[项目契约](project-contract.md)，再按当前 stage 查阅[六阶段执行图](../.agents/skills/zimeiti-video-workflow/references/pipeline.md)。
