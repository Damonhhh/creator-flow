# CreatorFlow 工作流线程图

这张图把 CreatorFlow 里同时运行的几条线放在一起：视频往前做，用户在关键点做判断，外部工具按需接入，QA 发现问题后退回真正负责的阶段。

![CreatorFlow 从选题到发布的四线程路线图](assets/creatorflow-workflow-roadmap.png)

下面的 Mermaid 版本保留了完整节点和连接关系，适合继续修改或核对细节。

```mermaid
flowchart TB
  subgraph MAIN["主生产线程：把一个选题做成发布包"]
    direction LR
    T["Topic<br/>选题 · 评分"] --> S["Script TTS<br/>脚本 · 音频 · 字幕 · 画幅"]
    S --> M["Material<br/>来源 · 逐句素材 · visual plan"]
    M --> A["Assembly<br/>组装 · 渲染"]
    A --> Q["QA<br/>进入验收"]
    P["Publish Wrap Up<br/>封面 · 文案 · 发布包 · 收尾"]
  end

  subgraph USER["用户判断线程：流程不替你做的决定"]
    direction LR
    U0["补入账号定位<br/>个人判断 · 写作风格 · 知识来源"] --> U1["确认这个题值不值得做"]
    U1 --> U2["锁定脚本和声音路线"]
    U2 --> U3["补回私人素材<br/>确认生成素材"]
    U3 --> U4["看当前成片的关键帧"]
    U4 --> U5["确认封面、文案和发布包"]
  end

  U0 -. "个人输入" .-> T
  U1 -. "通过或否决" .-> T
  U2 -. "人工锁定" .-> S
  U3 -. "验收素材" .-> M
  U5 -. "发布前确认" .-> P

  subgraph DEP["按需依赖线程：只处理当前阶段缺少的工具"]
    direction LR
    D0["进入 Script TTS<br/>Material 或 Assembly"] --> D1["检测当前阶段"]
    D1 --> D2{"有缺项？"}
    D2 -- "没有" --> D6["回到原阶段"]
    D2 -- "有" --> D3["说明用途、官方来源、命令、风险<br/>剩余步骤和替代路线"]
    D3 --> D4{"明确同意一个动作？"}
    D4 -- "同意" --> D5["只执行这一步"]
    D5 --> D1
    D4 -- "不同意，有替代" --> D6
    D4 -- "不同意，也无替代" --> D7["停在当前阶段<br/>记录 blocker"]
  end

  S -. "阶段入口" .-> D0
  M -. "阶段入口" .-> D0
  A -. "阶段入口" .-> D0

  subgraph CHECK["证据与返工线程：谁的问题退回谁"]
    direction LR
    E0["开工前读 project-state.json"] --> E1["每个阶段留下完成证据<br/>文件 · 命令结果 · 人工记录"]
    E1 --> E2["更新 currentStage<br/>stageStatus · nextAction · blockers"]
    AQ["自动 QA"] -->|"PASS"| HQ["人工关键帧复核<br/>绑定当前成片 SHA256"]
    AQ -->|"FAIL"| R{"问题归属"}
    HQ -->|"PASS"| DONE["可以进入发布收尾"]
    HQ -->|"FAIL"| R
  end

  Q --> AQ
  U4 -. "人工查看" .-> HQ
  DONE --> P
  R -- "题目" --> T
  R -- "脚本或音频" --> S
  R -- "素材或 visual plan" --> M
  R -- "组装或渲染" --> A
  D7 -. "写入阻塞" .-> E2
  T -. "完成后写证据" .-> E1
  S -. "完成后写证据" .-> E1
  M -. "完成后写证据" .-> E1
  A -. "完成后写证据" .-> E1
  P -. "完成后写证据" .-> E1

  classDef main fill:#E8F1FF,stroke:#2563EB,color:#0F172A,stroke-width:2px;
  classDef human fill:#FFF3D6,stroke:#D97706,color:#451A03,stroke-width:1.5px;
  classDef dependency fill:#F3E8FF,stroke:#9333EA,color:#2E1065,stroke-width:1.5px;
  classDef evidence fill:#E7F8EF,stroke:#15803D,color:#052E16,stroke-width:1.5px;
  classDef decision fill:#FFF7ED,stroke:#EA580C,color:#431407,stroke-width:2px;

  class T,S,M,A,Q,P main;
  class U0,U1,U2,U3,U4,U5 human;
  class D0,D1,D3,D5,D6,D7 dependency;
  class E0,E1,E2,AQ,HQ,DONE evidence;
  class D2,D4,R decision;
```

## 怎么读这张图

- 主线只负责生产。一个阶段没有文件、命令结果或人工验收记录，就不算完成。
- 用户判断线会在关键点和主线交汇。CreatorFlow 可以整理选项、执行和检查，但账号定位、内容判断、私人声音和发布决定仍然归使用者。
- 依赖线是旁路。安装 Agent Reach、IndexTTS2 或 HyperFrames 只会解决当前工具缺口，不会自动把生产状态推进到下一阶段。一次 `-AcceptAction` 只授权一个准确动作。
- QA 包含两道门：自动检查和人工关键帧复核。任意一道失败，都要退回题目、脚本、素材或组装的真正责任阶段。

## 六个阶段各自交什么

| 阶段 | 开工条件 | 主要交付 | 进入下一阶段前 |
| --- | --- | --- | --- |
| Topic | 用户想法、信号或来源线索 | 选题结论、评分、风险和证据 | 人能用一句话说清观众会带走什么 |
| Script TTS | 已通过的选题 | 锁定脚本、实际音频、SRT 和画幅决定 | 脚本、音频和字幕时间一致 |
| Material | 锁定脚本和方向 | 来源候选、逐句视觉任务、本地素材和 visual plan | 每个句子有可执行的视觉任务，缺口已补齐或明确免除 |
| Assembly | 素材和 visual plan 已完成 | 可检查的组装工程和候选成片 | 工程检查通过，每个视觉任务在成片中真正出现 |
| QA | 候选成片和项目证据 | 自动 QA 报告、关键帧和绑定成片 SHA256 的人工复核 | 自动 QA 和人工复核都通过 |
| Publish Wrap Up | 已验收成片 | 成片、封面、发布文案、`publish\` 包和收尾状态 | 确认最终路径、跳过的动作和同步结果 |

更细的输入、输出、检查命令和失败返回规则，见[六阶段执行图](../.agents/skills/zimeiti-video-workflow/references/pipeline.md)。
