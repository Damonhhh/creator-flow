# Video Failure Pattern Index

Use this compact index during normal production. Read the matching section in `docs\failure-patterns.md` only when its trigger applies, the issue repeats, or a stage reference explicitly requests the details. The public workflow does not require access to historical private projects.

| ID | Failure pattern | Primary stage | Trigger/profile |
| --- | --- | --- | --- |
| FP01 | 字幕文件存在但未对齐声音 | Script TTS / Assembly / QA | narration, captions |
| FP02 | 首屏 0-3 秒没有主视觉 | Assembly / QA | all video |
| FP03 | 素材只有清单，没有进入节奏 | Material | mainline video |
| FP04 | 抽象名词没有动作链 | Material / Assembly | explainer |
| FP05 | 封面流程合格，但不像封面 | Publish Wrap Up | cover |
| FP06 | 收尾被误当成只给 MP4 | Publish Wrap Up | formal wrap-up |
| FP07 | 发布文案没有做下游收口 | Publish Wrap Up | public copy |
| FP08 | 制作备注泄漏到口播或画面 | Script TTS / QA | all video |
| FP09 | 热点又被讲回旧结论 | Topic | timely topic |
| FP10 | 口播时长和画幅决策太晚 | Script TTS / Assembly | all video |
| FP11 | 视觉素材播完后空窗或黑框 | Assembly / QA | timeline media |
| FP12 | QA PASS 被当成交付 PASS | QA / Publish Wrap Up | all delivery |
| FP13 | CSS background 媒体缺失 | Assembly / QA | HyperFrames |
| FP14 | motion-job-v1.1 字段不完整 | Material / Assembly | explainer |
| FP15 | 媒体 fallback 和编码预检缺口 | Assembly / QA | imported video |
| FP16 | TTS 参考音没有走本地配置或显式参数 | Script TTS | generated narration |
| FP17 | 强兴趣案例被写成抽象方法论 | Topic / Script TTS | case teardown |
| FP18 | 高密度拆解被做成静态图文讲义 | Material / Assembly / QA | dense teardown |
| FP19 | 动效视频结束后回到首帧或空框 | Assembly / QA | motion clip |
| FP20 | 生图/动效只留提示词，没有进入素材规划 | Material | generated media |
| FP21 | 时间码或调试状态条泄漏到成片 | Assembly / QA | visible UI |
| FP22 | 封面尺寸通过，但旧审美经验没有生效 | Publish Wrap Up | cover |
| FP23 | 技术机制只有术语，没有可视过程 | Material / Assembly / QA | technical explainer |
| FP24 | 外部动效存在但未注册进时间线 | Assembly / QA | Jimeng/Seedance |
| FP25 | 外部动效已注册但被静态卡片遮挡 | Assembly / QA | Jimeng/Seedance |
| FP26 | 动效时间线漏掉前置或中间空窗 | Assembly / QA | motion coverage |
| FP27 | HyperFrames media 进入 sub-composition 后黑屏 | Assembly | HyperFrames media |
| FP28 | 长视频没有先给观看契约 | Script TTS / Assembly / QA | dense long-form |
| FP29 | TTS 用长静音凑时长，口播出现机械气口 | Script TTS / QA | cloned long narration; see `docs\tts-natural-pace-acceptance.md` |
| FP30 | 行动建议只有任务名，没有可照做的最小实例 | Script TTS / Material / QA | ordinary-audience AI advice |
| FP31 | 数字人口型导出成功，但 CUDA 环境或逐帧视觉已经失败 | Material / QA | digital-human lip sync |
| FP33 | 批量原图回传撑爆 Codex 续跑请求 | Material / QA | generated still intake, multi-image inspection |
| FP34 | 高频亮色转场造成整屏闪烁 | Assembly / QA | scene cuts, chapter transitions |

## Stage Routing

- Topic: FP09, FP17.
- Script TTS: FP01, FP08, FP10, FP16, FP17, FP28-FP30.
- Material: FP03, FP04, FP14, FP18, FP20, FP23, FP30.
- Assembly: FP01, FP02, FP04, FP10, FP11, FP13-FP15, FP18-FP21, FP23-FP28, FP34.
- QA: FP01, FP02, FP08, FP11-FP15, FP18, FP19, FP21-FP34.
- Publish Wrap Up: FP05-FP07, FP12, FP22.

## Additional Routing

- FP32: Large title collides with board/card and shimmers. Primary stage: Assembly / QA. Trigger/profile: title-card, evidence board, slow background scale, player jitter.
