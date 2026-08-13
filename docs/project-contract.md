# 视频项目契约

每个视频项目至少保留：

```text
draft/
  visual-plan/material-beat-map.md
  web-assets/source-candidates.md
assets/
review/
publish/
account-profile.md
writing-style.md
knowledge-sources.md
source-content.md
project-state.json
```

`project-state.json` 是当前阶段的机器可读入口。工作流依次推进 `Topic`、`Script TTS`、`Material`、`Assembly`、`QA` 和 `Publish Wrap Up`；阶段产物、阻塞项与下一步必须落盘，不能只存在于一次对话中。

## 状态不是验收

- 模板从 `Topic / topic_ready` 开始，只说明项目具备选题输入。
- `source-candidates.md` 中的候选不等于已经授权或采用。
- 自动 QA PASS 只允许进入人工复核，不允许直接收尾。
- 人工视觉复核必须写入 `review\human-visual-review-vNN.md`，并绑定当前 render SHA256；成片变化后旧复核失效。
- `review\` 和 `publish\` 不预置成功记录。

## 正式收尾门槛

正式 wrap-up 前至少需要：当前成片、自动 QA 报告、绑定当前成片的人工视觉复核、竖版封面、横版封面、发布文案复核记录和明确的输出路径。缺少任一项就保留阻塞状态，不伪造 PASS。

最小目录可以由 `scripts\new-video-project.ps1` 创建；完整执行规则见[六阶段执行图](../.agents/skills/zimeiti-video-workflow/references/pipeline.md)。
