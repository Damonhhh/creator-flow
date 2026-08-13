# 视频生产失败模式

日期：2026-06-29  
范围：AI 主线视频生产链路  
用途：把反复出现的生产问题压缩成可以直接执行的质量门，不要求新用户读取私有历史项目。

## 1. 字幕看似有文件，实际没对上声音

- 症状：SRT、`captions-data.js` 或结构验证存在，但成片字幕提前、滞后、断词、落到上一句/下一句，或者字幕里混入了口播没有说的证明标签、步骤名和解释文字。
- 根因：用平均分配、手写估算、旧 SRT 缩放，或把字幕当成补充讲解层，让它替画面完成信息任务。
- 硬修法：最终音频后重跑 ASR/强制对齐；字幕文本只跟最终口播，显示层只在真实 cue 边界内拆分。证明标签、步骤名、关键词强调和额外解释放到独立视觉层；抽开头、中段 proof、中段 argument、收尾点。
- 当前拦截位置：`run-video-draft-qa.ps1` 已检查 `captions-data.js` 文本、断词、`asr-align-report.json` 新鲜度。
- 是否需要进入脚本：已部分进入脚本；人工语义抽帧仍保留。

## 2. 首屏 0-3 秒没有主视觉

- 症状：第一帧只有背景、字幕、孤立人物，或标题、卡片、素材堆成一团。
- 根因：脚本 QA 只导出帧，没有把第一眼构图当硬门槛。
- 硬修法：0.00s、0.03s、3.00s 三帧人工打开；首屏只保留一个主标题、一个主视觉、一个钩子和最多一个辅助层。
- 当前拦截位置：`run-video-draft-qa.ps1` 生成 opening frame 检查提示，并拦截开头视频过载。
- 是否需要进入脚本：保留人工目检；后续可增加布局/亮度/空白区检测。

## 3. 素材只有清单，没有进入节奏

- 症状：有 `source-candidates.md`，但成片仍是静态卡片、Pexels texture、无语义截图，或者几句口播一直共用一段泛 B-roll，主要意思全靠字幕承担。另一种常见误判是“素材文件数看起来够”，实际同一底图跨多个语义段重复出现十几到二十秒。
- 根因：素材只按主题搜，没有按每条完整口播语义分配 `prove / explain / analogize / transition / close` 画面任务；Agent Reach 的搜索词也没有包含口播主体、可见动作和目标时间点。Material 只数文件，没有统计每个主素材的使用次数、累计屏幕时长和连续停留时长。
- 硬修法：先给每条完整口播句子或语义单元分配 `LINE##` 和一个主画面任务，再用 Agent Reach 按“口播主体 + 画面任务 + 可见动作”找外部素材。`source-candidates.md` 记录 query、route/command、URL、可用 timestamp/页面区域和对齐理由；`material-beat-map.md` 记录句子、时间、任务、素材、motion 和 fallback。连续两句只有在同一主体/动作下才能共用任务，并写明共享 task ID。Material 完成前另做 screen-time repetition budget：逐个主素材记录使用次数、累计秒数和最长连续停留；60-90 秒竖版通常准备 12-18 个独立主场景，同一底图跨语义复用必须标记为短 callback，不能靠换字幕、裁切或推拉假装新镜头。
- 当前拦截位置：`new-video-source-candidates.ps1` 生成本机路由可用性、Agent Reach 搜索字段和 `visual-task-v1` 句子级 beat-map 模板；`test-video-material-mix.ps1` 检查 source、角色标签、Agent Reach 证据、句子级任务、共享 `VT##` 的连续时间/主体/动作、stock-heavy、占位符和 motion 字段，并把 PASS/FAIL 写回 `project-state.json`。Assembly 写 `visual-task-coverage.json`，`test-video-visual-task-coverage.ps1` 检查每个 `VT##` 是否覆盖全部计划 `LINE##`。
- 是否需要进入脚本：规划和实现追踪已进入脚本；成片是否真的对齐口播，继续由 `human-visual-review-vNN.md` 的 `Visual-task coverage` 人工目检。

## 4. 抽象名词没有动作链

- 症状：资产、流程、入口、风险、成本这类核心词只变成静态标题卡。
- 根因：visual plan 写了“信息卡 / 方法卡”，没有写这个名词如何进入、分类、连接、验证或失败。
- 硬修法：`material-beat-map.md` 必须给核心名词写 `motion job:`，例如 `motion job: split old path into steps; route request into result`。
- 当前拦截位置：`stage-material.md` / `stage-assembly.md`，`new-video-source-candidates.ps1` 已生成 `motion-job-v1.1` beat-map 模板；`test-video-material-mix.ps1` 已检查抽象核心词和 explain beats 是否声明 semantic motion job，并在 v1.1 下要求 action、subject、change、fallback 四个字段。
- 是否需要进入脚本：已进入启动模板和 strict mode；后续可再扩展到更复杂的自动化实现校验。

## 5. 封面流程合格，但不像封面

- 症状：有 PNG/JPG，也有标题，但像信息卡截图、临时 PPT 或本地排版作业。
- 根因：只检查文件和尺寸，没有按缩略图点击资产看主视觉、标题、层级和情绪。
- 硬修法：按 `docs\cover-system.md` 先生成视觉底图，再本地中文排版；竖版 1080x1920 和横版 4:3 分别构图，实际打开检查。
- 当前拦截位置：`invoke-video-wrap-up.ps1` 检查双封面和尺寸；视觉 QA 仍靠人工。
- 是否需要进入脚本：尺寸已进脚本；视觉点击感保留人工门槛。

## 6. 收尾被误当成“给一个 MP4”

- 症状：回复里说完成，但缺封面、发布包、待发布同步、合集/平台目录或收尾状态。
- 根因：“成片 QA 通过”和“发布闭环完成”混在一起。
- 硬修法：用户说收尾、可以发、停在这版时，执行 `zimeiti-video-wrap-up` 和 `invoke-video-wrap-up.ps1`；缺产物先回对应阶段。
- 当前拦截位置：`zimeiti-video-wrap-up` skill、`wrap-up-checklist.md`、`invoke-video-wrap-up.ps1`。
- 是否需要进入脚本：已进入脚本；继续维护 manifest 和 hash 绑定。

## 7. 发布文案没有做下游收口

- 症状：标题、正文、首评像内部总结、生产报告或旧角度复读；标题先把结论讲完，正文又把口播答案完整复述，用户扫完文字已经没有点开视频的必要。
- 根因：上游企划校验没有在 publish 包阶段重新落到平台文案，或只检查“写全没有”，没有检查“还剩什么必须点开才知道”。
- 硬修法：正式发布包必须有符合 `config\publish.local.json` 的 `review\publish-copy-pass-vNN.md`，记录复核方法、问题和改写文件。标题必须点名受众或处境、给出个人风险并保留未解问题；正文首屏继续放大同一条风险，不能把视频核心答案提前摘要完；首评沿用同一情绪线，只要求一个能直接回答的具体动作。标题、正文、首评三处各自写得通但不在同一条线上，仍判 FAIL。
- 当前拦截位置：`zimeiti-video-wrap-up` skill、`wrap-up-checklist.md`、`invoke-video-wrap-up.ps1`。
- 是否需要进入脚本：已进入脚本，wrap-up 按本地配置检查 publish-copy pass 的文件名、状态和方法字段。
- 经验：形式 PASS 不等于文案有效。若标题提前说完结论、正文复述完整答案，仍应判定为 FAIL，并统一标题、正文和首评的阅读动机。

## 8. 制作备注泄漏到口播或画面

- 症状：观众听到或看到“页面上展示”“不占口播时间”“这里做成卡片”等剪辑指令。
- 根因：没有把观众口播、画面文案、制作备注分层。
- 硬修法：写入 `录音稿.txt` 前删除或改写制作备注；渲染前扫 `录音稿.txt`、`captions-data.js`、`index.html`。
- 当前拦截位置：`stage-script-tts.md`、`stage-qa.md`、`run-video-draft-qa.ps1`。
- 是否需要进入脚本：已进入脚本，draft QA 扫描 `录音稿.txt`、`captions-data.js`、`index.html` 的制作备注词。

## 9. 热点又被讲回旧结论

- 症状：换了热点名，最后仍是知识库、工作流、验收、回滚、提示词这些旧结论。
- 根因：把热点当旧方法论证据，而不是先找新事实、新风险、新机制或新交付物。
- 硬修法：选题前做近三条去重；删掉热点名仍能套用的角度直接作废；标题、封面、前三秒保护本期新鲜点。
- 当前拦截位置：Topic 阶段的选题评分规则和本文件。
- 是否需要进入脚本：部分可在日报/选题报告要求 repetition risk；最终仍需人工判断。

## 10. 口播时长和画幅决策太晚

- 症状：已经做 beat map 或 HyperFrames 后才发现 90 秒以上视频该横版，返工重排。
- 根因：画幅不是在最终口播后、素材规划前落盘。
- 硬修法：锁定 `录音稿.txt` 后估算或生成音频；超过 90 秒默认 1920x1080，90 秒以内默认 1080x1920；标准证据写入 `draft\orientation-decision.json`，例外必须写 reason。
- 当前拦截位置：`stage-script-tts.md`、`stage-assembly.md`、`test-video-orientation-decision.ps1`、`run-video-draft-qa.ps1`。
- 是否需要进入脚本：已进入脚本；legacy 项目可读取 `status.md` / `material-beat-map.md` / `design.md` 的明确画幅证据。

## 11. 视觉素材播完后空窗或黑框

- 症状：媒体卡在 beat 后半段变空、黑屏、冻结，或同一短素材反复弹播。
- 根因：没有检查素材时长、编码、关键帧和 fallback。
- 硬修法：素材进入 HyperFrames 前用 `ffprobe` 查时长和编码；短素材拆 B/C clip handoff；每个 media card 覆盖完整 beat 或有 intentional still fallback。
- 当前拦截位置：`run-video-draft-qa.ps1` 已检查 HyperFrames HTML 里的 `video` / `img` 空 `src`、本地资源缺失、带时间轴视频的可播放时长、CSS background 本地资源、显式 intentional still fallback、HDR/HLG/BT.2020 硬风险，以及 codec/keyframe 预处理 warning；人工 QA 继续看结构性空窗、冻结和 fallback 体验。
- 是否需要进入脚本：已部分进入脚本；复杂 wrapper、canvas 内部空窗、真实视觉冻结和 fallback 观感仍需要人工抽帧或后续更深脚本。

## 12. QA PASS 被当成交付 PASS

- 症状：脚本通过后仍有不可读证据卡、临时态切场、字幕抢戏、封面缺失或同步路径没换新版本。
- 根因：机器检查只能发现结构问题；如果人工复核没有固定文件名、当前成片哈希和收尾脚本门槛，它就会退化成“应该看一下”的口头要求。
- 硬修法：自动 QA 通过后只进入 `awaiting_human_review`；人工打开抽帧/接触表后写 `review\human-visual-review-vNN.md`，记录当前成片 SHA256 和八项检查。`test-video-human-visual-review.ps1` 通过后才能进入收尾。
- 当前拦截位置：`run-video-draft-qa.ps1` 生成有上限的 `review\qa-frames-current\` 和 pending 模板；`test-video-human-visual-review.ps1` 校验人工复核；`invoke-video-wrap-up.ps1` 在同步前强制校验复核与成片哈希一致。
- 是否需要进入脚本：已进入双门槛；脚本拦结构并验证证据契约，人工负责观感判断。
## 13. CSS background 媒体缺失

- 症状：画面看起来空、黑、缺主视觉，但没有缺失 `<img>` 或 `<video>` `src`，因为素材藏在 CSS `background-image: url(...)` 里。
- 根因：HyperFrames `index.html`、inline `style`、`<style>` 块或本地 CSS 文件引用了本地背景图/视频，却没有检查文件是否存在。
- 硬修法：把 CSS background 当成真实媒体槽位；本地相对 `url(...)` 必须存在，`http(s)`、协议相对 `//`、`data:`、`blob:`、纯渐变/纯色不算本地媒体槽。
- 当前拦截位置：`run-video-draft-qa.ps1` 已解析 inline style、`<style>` 块和 `hyperframes-app` 下本地 CSS 文件；缺失本地 background media 会带来源标签和解析路径进入 draft QA Issues。
- 是否需要进入脚本：已进入脚本；复杂 wrapper/canvas 内部空窗仍保留在后续 backlog。

## 14. `motion-job-v1.1` 字段契约不完整

- 症状：beat map 写了 `motion job:`，但剪辑执行时仍不知道哪个可见对象移动、状态怎么变化、失败时用什么 fallback。
- 根因：旧 `motion-job-v1` 只证明有动作词，没有证明动作能被画面执行。
- 硬修法：新标准 beat map 使用 `motion job: <action>; subject: <visible object>; change: <from state -> to state>; fallback: <fallback plan>`。
- 当前拦截位置：`new-video-source-candidates.ps1` 已生成 `motion-job-v1.1`；`test-video-material-mix.ps1` 在 v1.1 下要求 explain 或 abstract beats 包含 action、subject、change、fallback 四个字段；stage-assembly 要求实现时可见。
- 是否需要进入脚本：字段契约已进入脚本；motion job 是否真的落到 HyperFrames 动作实现仍是后续脚本 backlog 和人工 QA 点。

## 15. 媒体 fallback 和编码预检缺口

- 症状：短视频素材撑不到 beat 结束，或 HLG/HDR/BT.2020 源让 HyperFrames 预览/渲染不稳定；稀疏 keyframe 让 seek 和预览不顺。
- 根因：素材时长、fallback 意图、颜色元数据和 keyframe 密度没有在 draft QA 暴露。
- 硬修法：短 timeline video 需要 handoff clip 或显式 still fallback 标记，例如 `data-intentional-still-fallback="true"` 或 `data-fallback="intentional-still"`；视频源优先 H.264、30fps、yuv420p、SDR BT.709、密集 keyframe；HDR/HLG/BT.2020 默认重编码，只有人工确认后才能加 `data-hdr-approved="true"` 或 `review\encoding-exceptions.json`。
- 当前拦截位置：`run-video-draft-qa.ps1` 已阻断短素材无 handoff/fallback、阻断未批准 HDR/HLG/BT.2020，批准的 HDR 进入 Warnings；codec、pixel format、keyframe gap 和大文件 keyframe probe skip 进入 Warnings。
- 是否需要进入脚本：已部分进入脚本；复杂 wrapper 空窗、canvas 空窗、真实视觉冻结仍需人工抽帧或后续更深检测。

## 16. TTS 参考音没有走固定配置

- 症状：项目 render 已经进入 review，但旁白不是从固定参考音和最终音频时间线生成，后续字幕、口型或节奏都变成临时状态。
- 根因：生产 TTS 被当成可互换 backend，而不是 Script TTS 阶段的交付契约；参考音路径、生成方式和字幕时间线没有绑定在同一份配置上。
- 硬修法：正式旁白必须使用可复现的长文本 TTS 或用户提供的最终旁白。参考音只从 `config\tts.local.json` 或显式参数读取；需要身份绑定时校验 SHA256。
- 当前拦截位置：`stage-script-tts.md` 保留当前生产路径；`run-mainline-topic-decision.ps1` 缺少现成旁白和可用 TTS 配置时明确失败；`run-video-draft-qa.ps1` 阻断 timing stub 进入 review/final。
- 是否需要进入脚本：已进入脚本；声音风格是否使用正确参考音仍需在 TTS 阶段记录 reference audio 和人工听检。

## 17. 强兴趣案例被写成抽象方法论

- 症状：题材本身有强钩子，例如美女、赚钱、涨粉、风险、反常识，但脚本开头先讲 `三层路径`、`角色付费系统`、`飞轮`、`可调用资产`、`四个文件夹` 这类抽象名词。
- 根因：把创作者拆解后的结论，当成了观众第一秒想知道的东西；忽略了观众先关心的是谁、出了什么结果、为什么有效。
- 硬修法：先用 `对象 + 结果 + 我们讲它怎么做到` 打开，再补反差、证据边界、动作化机制和观众能带走的判断清单。
- 当前拦截位置：`stage-script-tts.md`、`review\script-structure-learning-v01.md`、后续项目的 `draft\production-carryover.md`。
- 是否需要进入脚本：先作为人工硬门槛；后续可把 script-lock-note 增加为自动检查项。

## 18. 高密度拆解被做成静态图文讲义

- 症状：播放数据或选题反馈证明内容方向有效，但画面仍被评价为静态图文偏多、略显单调；关键机制只用文字卡或多宫格呈现，观众看不到点击、浏览、筛选、进入、订阅、返回等动作。
- 根因：脚本已经把商业逻辑讲清楚，但素材和组装阶段没有把逻辑转成视觉路径；为了塞干货，段落之间也缺少呼吸点。
- 硬修法：高密度案例拆解必须在 beat map 里写出动态路径和节奏重置。筛选用户、分层付费、公开区、入口、订阅区这类节点，要用 click path、browse path、split-screen swap、quick switch、highlight、zoom 或 1-2 秒 visual reset 表达。
- 当前拦截位置：`stage-material.md`、`stage-qa.md`、后续项目的 `draft\production-carryover.md`。
- 是否需要进入脚本：先进入人工 QA 和 material beat map；后续可把长静态卡、缺少 motion-job 的 explain beat、缺少呼吸点作为更细的自动化检查。

## 19. 动效视频结束后回到首帧或空框

- 症状：Jimeng / Seedance 等短动效素材播完后，画面突然跳回素材第一帧，形成轻微“回弹”；或者 5 秒动效结束后，右侧主视觉退成暗背景/空框，观众会觉得素材“播完就没了”。
- 根因：依赖浏览器或渲染器对 `<video>` 播放结束的默认冻结行为；当素材 active duration 结束、seek 边界或 fallback 触发时，视频可能回到 `currentTime=0`，而不是保留尾帧。
- 硬修法：动效素材进入 HyperFrames 后必须有显式尾帧承接。做法可以是抽取 tail frame 并在 `data-start + data-duration` 前后覆盖显示，或预处理视频为“原片 + 尾帧 clone pad”；不要把首帧 still 当作结束 fallback。
- 当前拦截位置：`stage-assembly.md` 人工硬门槛；QA 抽帧时至少检查若干 `videoEnd + 0.1s` 帧，确认不是首帧回弹。
- 是否需要进入脚本：先进入人工 QA 和 assembly stage；后续可在 HyperFrames HTML 检查 `motion-tail` / tailframe 资产，或自动导出 video end contact sheet。

## 20. 生图和即梦动效只留下提示词，没有进入素材规划

- 症状：脚本刚落好就直接写生图提示词；没有先检查外部视频和内部已有素材是否够用。`draft\visual-plan` 虽然有生图或即梦/Seedance 提示词，但不知道它补的是哪个时间段、哪些图必须生成动效、哪些只做本地动画、素材返回后该叫什么名字、失败时用什么 fallback。最后仍可能是一串 AI 海报和文字卡。
- 根因：把外部生成当成“给用户一批提示词”，没有把它放进“脚本锁定 -> 时间轴素材覆盖 -> 缺口判断 -> 生成补位 -> 导入验收”的素材流程；也没有建立 `IMG##` / `MOV##` ID、动效必要性、10 秒上限、尾帧要求、导入命名和 `ffprobe` 验收。
- 硬修法：先按口播时间轴检查外部第一手/证明素材和内部可复用资产，只对剩余缺口启动生成分支，并在 `draft\visual-plan\generated-motion-asset-plan.md` 记录 `Generation branch: not-needed / required`、缺口和卡片化风险。每张生图标出 beat、role、visual job、是否 `motion-required / local-motion / static-support / reject`；每条即梦动效标出 source image、4-6 秒默认时长且不超过 10 秒、一个 visible action、end-state/tail frame、fallback。提示词包、返回素材命名图、motion intake 使用同一套 ID。
- 当前拦截位置：`stage-material.md` 和 `material-generated-motion-assets.md`；`new-video-source-candidates.ps1` 生成带素材覆盖判断的 `generated-motion-asset-plan.md`；`test-video-material-mix.ps1` 检查分支状态、required 分支占位符、ID/动效决策和 10 秒上限。
- 是否需要进入脚本：已进入素材阶段模板和轻量 QA。生成画面是否真正可用、是否仍像海报，以及动效是否自然，继续由人工素材验收和成片关键帧检查负责。

## 21. 时间码或调试状态条泄漏到成片 UI

- 症状：画面角落出现 `00:58`、scene start、英文 production marker、debug chip、QA/timecode 小卡等内部标识，看起来像剪辑软件残留或系统提示。
- 根因：把组装时用于定位 beat 的时间码、场景名、英文 marker 直接复用为可见组件；QA 只看布局是否溢出，没有把“这是不是观众该看到的文字”当门槛。
- 硬修法：可见顶部状态条只能使用观众语义：中文场景标签、步骤进度、章节名或来源边界。时间码、内部 marker、debug label 必须隐藏或只留在源码/验证文件里。
- 当前拦截位置：`stage-assembly.md` 的“Remove production labels”规则和 `stage-qa.md` 人工看帧；每次人工 QA 要扫 0-3 秒、中段 proof、清单、结尾顶部/角落 UI。
- 是否需要进入脚本：先作为人工硬门槛；后续可把常见词如 `timecode`、`scene start`、`QA`、`debug`、`ROLL OUT SIGNAL` 等加入可见文案扫描。

## 22. 封面尺寸通过，但旧审美经验没有生效

- 症状：竖版、横版、发布包和 manifest 都存在，脚本也 PASS，但封面仍像网格/PPT/信息卡/抽象科技图；或只是在旧项目英雄图、旧门/通道/红叉隐喻上换字；或 `publish/` 顶层混入旧底图、源 MP4、staging 文件，最后被同步到待发布目录。
- 根因：把封面系统理解成尺寸和文件清单，没有执行 `docs\cover-system.md` 的审美门槛，也没有把视觉反馈沉淀为日常质量规则。
- 硬修法：每次正式封面必须有当前主题生成底图或明确批准的系列资产，再做本地中文标题；拒绝纯本地脚本网格/面板/抽象 icon 封面；拒绝“昨天封面换字”；打开竖版和横版最终 PNG，并生成或记录缩略图检查；写入 `review\cover-qa-vNN.md`，明确 PASS/FAIL、封面系统检查、缩略图检查和被拒绝项。`publish/` 顶层只保留规范发布资产，额外源 MP4 和 staging 文件不得同步。
- 当前拦截位置：`stage-publish-wrap-up.md`、`zimeiti-video-wrap-up` checklist、`invoke-video-wrap-up.ps1`；脚本检查封面尺寸、发布包、配置的 publish-copy pass，并要求 `review\cover-qa-vNN.md`，同时跳过顶层非规范 MP4 的同步。
- 是否需要进入脚本：已进入脚本证据门槛；“像不像点击资产”仍需要人工目检，但必须有 `cover-qa` 文件留痕。

## 23. 技术机制讲解只有术语，没有可视过程

- 症状：口播里讲的是编码、权限、隐藏标记、路由、调用链、模型/公司/工具差异等技术机制，但画面只是静态文字卡；关键术语只在字幕里出现，结尾观点也像普通总结页，没有留下视觉记忆点。
- 根因：把“技术点解释清楚”误当成“观众能看见机制”。HyperFrames 已经能做文字动效、SVG/HTML 关系线、动态图表、局部放大、状态流转和全屏观点卡，但素材和组装阶段没有把这些动作写进 beat map。
- 硬修法：技术解释必须拆成四类视觉动作：机制过程可视化、专名实体锚点、关键术语强调、结尾观点收束。机制过程用字符变化、状态芯片、路径连接、动态图表或前后对比；公司/工具/协议用官方截图、产品 UI、仓库页、合法 logo 或中性文字徽章；关键技术词用放大、描边、聚焦、扫光、下划线等短强调；结尾观点用一屏一句的收束卡。音效只在已有授权素材或可控音频混合时使用，不为音效牺牲交付稳定性。
- 当前拦截位置：`stage-material.md` 负责写入 beat map 和 `production-carryover.md`；`test-video-material-mix.ps1` 轻量检查技术解释类项目是否声明 `process visual / entity anchor / key term / closing thesis` 字段；`stage-assembly.md` 负责用 HyperFrames 实现；`stage-qa.md` 人工检查技术机制是否真的动起来、关键术语是否有视觉锚点、结尾是否是 deliberate closing beat。
- 是否需要进入脚本：字段声明已进入脚本；真正“是否好看”和“是否像机制”仍需人工关键帧检查。

## 24. 即梦/Seedance 动效存在，但没有注册进 HyperFrames 时间线

- 症状：用户已经给了 Jimeng / Seedance 动效视频，项目里也有 `MOV##` 文件，但成片实际仍像静态图层；或者源码用 JS 动态创建 `<video>`，预览看似可播，HyperFrames 渲染日志却显示 `videoCount:0` 或少于预期。
- 根因：把“文件存在”或“DOM 运行时能插入视频”误当成“HyperFrames 已注册媒体”。渲染器只识别它能扫描和排程的真实媒体元素；运行时临时生成、被 CSS 隐藏、没有稳定 ID / `data-start` / `data-duration` / `data-track-index` 的视频，可能不会进入最终 timeline。
- 硬修法：外部动效进入组装阶段后，核心 `MOV##` 必须成为可扫描的真实 `<video>` 媒体层，使用稳定 ID、明确 `src`、`data-start`、`data-duration`、`data-track-index` 和 fallback 标记。渲染后必须检查 HyperFrames inspect/render log 的 `videoCount`，并在 assembly review 写明注册数量、使用的 `MOV##` 列表和抽帧证据。只看静帧或只看文件夹不算通过。
- 当前拦截位置：`stage-assembly.md` 人工硬门槛；`run-video-draft-qa.ps1` 可捕捉空 `src`、缺本地资源和短视频 fallback，但“预期 MOV 数量 vs render videoCount”仍需 assembly review 记录。
- 是否需要进入脚本：后续可把 `draft\visual-plan\motion-video-intake.md` 或 `MOV##` 引用数与 HyperFrames inspect/render log 的 `videoCount` 做一致性检查；当前先作为组装和 QA 的人工硬门槛。

## 25. 即梦/Seedance 已注册，但被静态卡片压成背景

- 症状：HyperFrames render log 已显示 `videoCount > 0`，assembly review 也写了 `MOV##`，但成片里动效只像暗背景或纹理；大白板、表格、证明卡、字幕框或半透明静态图压在上面，观众看不出用户生成的 5 秒动效被真正使用。
- 根因：把“媒体注册成功”误当成“视觉使用合格”；CSS 层级、透明度、vignette、静态 fallback、board/card z-index 没有按 motion beat 重排。结果是动效存在于 timeline，却没有承担主视觉工作。
- 硬修法：外部动效如果被标为 `motion-required`，组装时必须成为当前 beat 的主视觉或明确的前景证据层。静态 fallback 只能弱化到兜底，不得盖住动效；大表格/卡片正文只能拆成小标签、局部高亮或下一 beat 展示。渲染后必须抽取 motion beat 的关键帧或 contact sheet，证明动效画面是可见主体。
- 当前拦截位置：`stage-assembly.md` 人工硬门槛；assembly review 必须同时记录 `videoCount` 和“可见使用证据”，包括至少 3 个 motion beat 抽帧或 contact sheet。
- 是否需要进入脚本：先作为组装和 QA 的人工硬门槛；后续可扩展视觉检查，检测 motion scene 上方是否存在大面积高亮 card/table overlay。

## 26. 动效时间线只看播完后，漏掉开播前或中间空窗

- 症状：5 秒 Jimeng / Seedance 动效本身能播放，播完后也有尾帧，但同一 scene 在动效开始前、两段动效之间，或者最后一段动效之后仍出现暗底、空框、只有点线背景的窗口；观众会感觉“播放完就没了”或“动效还没来之前就是空的”。
- 根因：QA 只检查 `videoCount`、motion active frame、`videoEnd + 0.1s`，没有把 scene start 到 scene end 当成一个连续覆盖区间；`secondaryMotions` 延后开始时，`has-motion` 样式把静图压得太暗，导致前置窗口失去主视觉。
- 硬修法：每个 motion-required scene 必须列出覆盖区间：pre-motion deliberate still、active motion clip、tail-frame/end-state、next-motion handoff、static-support。第一段动效晚于 scene start 时，必须先用可见静图或前景资产顶住主视觉，并在动效开始前淡退，避免盖住动效。
- 当前拦截位置：`stage-assembly.md` 已增加全时段 coverage hard gate；assembly review 必须抽 `sceneStart + 1s`、motion active、`videoEnd + 0.1s`、下一段前后等关键帧，不能只抽动效播放中。
- 是否需要进入脚本：先进入人工 QA 和 assembly review；后续可读取 `SCENES`、`secondaryMotions`、tail-frame layers 自动生成 coverage gap 表。
## 27. HyperFrames media moved into sub-compositions and renders blank

- Symptom: To reduce a large `index.html`, real `<video>` / `<audio>` elements are moved into `compositions\*.html`. Lint reports `media_in_subcomposition`, or preview/render risks black/blank media even though files exist.
- Root cause: HyperFrames only seeks and decodes real media reliably when the media elements are direct children of the host root composition. Sub-compositions are suitable for graphic structure, not for hiding timeline media assets.
- Fix: Keep real videos, audio, Jimeng/Seedance MOV clips, proof clips, and B-roll as host-root media elements with stable `id`, `src`, `data-start`, `data-duration`, and `data-track-index`. Use sub-compositions only for non-media graphic scaffolding, or document an explicitly verified HyperFrames-supported media pattern before changing this rule.
- Current guardrail: `stage-assembly.md` now states that real media must remain in the host root. Assembly notes must record attempted sub-composition media splits as rejected if lint reports `media_in_subcomposition`.

## 28. 长视频没有先给观看契约

- 症状：20 分钟以上的干货视频完全没有告诉观众这期为什么长、该怎么用、为什么值得收藏；或者反过来，把观看引导做成独立首屏、前置卡片或长段互动请求，压过真正的内容钩子。
- 根因：没有区分“内容钩子”和“观看引导”的主次。观看引导应该服务已经成立的钩子，而不是替代钩子；收藏理由也必须绑定到检查表、步骤、风险清单、工具入口或系列路线等具体用途。
- 硬修法：先让第一轮正常开场或反差钩子成立，再在 10-20 秒内自然补一条短口播。不要抢 0-3 秒，也不要拖到 40 秒以后才提醒。默认只使用原画面和常规字幕，不新增 front bumper，不替换首屏，不为互动请求单独停顿。只有用户明确要求时才把它做成独立视觉段。
- 当前拦截位置：`stage-script-tts.md` 负责把引导写成一句能顺口念出的口播；`stage-assembly.md` 负责保持原视觉序列；`stage-qa.md` 人工检查它是否自然、简短、没有喧宾夺主。
- 是否需要进入脚本：作为 20 分钟以上高密度长视频的人工硬门槛；QA 检查开场段是否存在观看引导，同时检查首屏和钩子没有被引导语替换。

## 30. 行动建议只有任务名，没有可照做的最小实例

- 症状：视频告诉普通人“让 AI 接一段真实任务”，随后只列出初稿、整理、检索、重复沟通等任务名；观点成立，画面也有流程箭头或任务卡，但观众仍不知道第一步该贴什么、该怎么下指令、会得到什么结果、自己要检查什么。
- 根因：把“任务分类”和“流程图”误当成“可执行示范”。选题阶段承诺了具体闭环，Script TTS 没有锁定一个微型案例，Material/Assembly 又用通用图标、齿轮、卡片或官方流程图替代了真实输入输出。
- 硬修法：面向普通人的 AI 行动建议至少给一个最小闭环：`原始输入 → 给 AI 的明确指令 → 结构化输出 → 人工验收点`。例如会议纪要可以展示原始记录、按“结论/负责人/截止时间/待确认”整理的指令、四列表格，以及人名/时间/结论三项核对。真实或模拟聊天框、前后对比和结果表属于 `explain`；齿轮、图标、泛办公 B-roll 只能做 `texture`。如果本期只负责建立趋势判断，必须明确把具体案例承诺给下一期，不能一边承诺“可照做”一边只交任务名。
- 当前拦截位置：`stage-script-tts.md` 检查 viewer-facing deliverable 是否落到一个微型实例；`stage-material.md` 把四段闭环映射成可见状态变化；`stage-qa.md` 检查观众是否能从画面复述第一步和验收点。当前先作为人工硬门槛，不要求所有观点视频强塞教程。
- 是否需要进入脚本：暂不新增自动脚本字段；先观察至少第二个项目是否重复暴露，再决定是否扩展 topic/script validation。

## 31. 数字人口型导出成功，但 CUDA 环境或逐帧视觉已经失败

- 症状：口型引擎能导出 MP4，时长、音轨和解码都正常，但嘴部发糊、下半脸像贴片、嘴唇消失，甚至从连续帧中出现整块黑色遮罩；只看文件存在或抽一两帧容易误判为成功。
- 根因：把“脚本跑完”当成视觉通过；没有先核对 GPU compute capability 与 PyTorch/CUDA wheel 的支持列表，也没有按训练帧率和官方模型配置运行；或者底片本身正在说另一句话，新旧口型在同一块嘴部区域互相打架。RTX 50 系显卡若仍使用旧 `cu118` 环境，可能在表面可运行的同时持续产生错误 CUDA 内核结果。
- 硬修法：先做 3-4 秒基准，不直接跑整段；核对 `torch.__version__`、`torch.version.cuda`、`torch.cuda.get_arch_list()` 和 FP16 卷积；使用引擎官方模型权重、配置文件与训练帧率。基准底片优先选择嘴部闭合或接近中性、没有旧发音口型、同时保留自然眨眼和身体微动的连续片段。导出后检查全部面部帧的 dense contact sheet，并让用户看正常速度。任何黑脸、双口型、贴片、嘴唇消失、下巴跳变或连续糊嘴直接 FAIL；解码 PASS 只能进入候选，不能代替视觉 PASS。
- 当前拦截位置：数字人实验先留在 `draft\digital-human-tests`；短基准输出必须有逐帧接触表和 `human-visual-review-*.md`。用户正常速度确认前不得扩到完整时长、替换主线成片或同步发布包。
- 是否需要进入脚本：暂时作为人工硬门槛；后续若数字人路线进入常规生产，再把 GPU 架构自检、25fps 输入和 dense face contact sheet 写成专用预检脚本。

## 32. 大标题贴近白板/卡片导致播放器里抖边

- 症状：单帧看标题似乎能读，但正常播放时，大号中文标题边缘像在抖、闪、跳，尤其是标题右侧贴着白板、证据卡、人物或高对比边框时。自动 QA 可能仍然 PASS。
- 根因：标题安全区太紧，旁边又有前景卡片、播放器缩放、H.264 边缘压缩，或标题背后的背景在做极慢缩放。观众看到的是“抖动”，不是设计感。
- 硬修法：大标题先划安全区，再放白板/卡片；不要让后绘制的证据板盖住标题笔画。问题段可以把标题改短，做成自然两行，加稳定浅色底板，或关掉标题背后的慢缩放。修完后必须抽连续帧 contact sheet，不只看一张截图。
- 当前拦截位置：`stage-qa.md` 已要求检查 scene midpoint / full-entry peak。用户报告抖动时，人工目检记录必须写明时间戳、修复后的标题布局和连续帧证据。

## 33. 批量原图回传撑爆 Codex 续跑请求

- 症状：素材回收或人工看图已经执行了很久，随后界面反复显示“正在重新连接”，后端返回 `408 Request Timeout` 和 `Request body read timed out`。同一轮重试通常继续失败，任务看起来像网络断了，但普通短任务仍能工作。
- 根因：一次工具调用批量回传多张原分辨率图片，`image_url` / data URL / base64 被完整记录为工具输出。后续模型续跑会携带本轮工具结果，几十 MB 的请求体无法在后端读取时限内完成。已确认的两个失败轮次都累计约 47 MB 工具输出，最大单条结果约 25-27 MB；主要来源是一次打开 8-11 张原图。
- 硬修法：先用文件名、尺寸、大小和哈希做无二进制预检；再生成带文件名的接触表，每张最多 12 个素材、最长边不超过 2400 px、JPEG 质量约 80。接触表使用 normal/high detail。只有接触表留下明确疑点时才打开单张原图，一次只看一张；大于 4 MB 时先裁切或缩放疑点区域。禁止把 data URL/base64 通过文本、JSON 或 shell 输出转发，也禁止在一次调用里批量返回原图。
- 当前拦截位置：`stage-material.md` 与 `material-generated-motion-assets.md` 的 returned still intake。Material/QA 看图必须采用“接触表总检 + 单张例外复核”，大批量素材要拆成多轮。已经塞入超大工具结果的失败轮不能靠原样重试恢复，应中断并用精简交接在新任务继续；项目文件和已落盘素材不受影响。
- 是否需要进入脚本：当前先用工作流硬门槛拦截；后续可增加自动接触表脚本和单轮视觉载荷检查，但不能依赖模型自行记住不要批量原图。

## 34. 高频亮色转场造成整屏闪烁

- 症状：几乎每次切镜都叠一层黄色、白色或其他高亮全屏特效。单次只有几帧，连续播放仍会形成频繁闪屏，抢走人物、字幕和素材本身的注意力。
- 根因：把每个场景边界都当成需要“设计转场”，或者当前工具做不出自然衔接时，继续用全屏亮色遮罩模拟转场。
- 硬修法：默认直接切；只有章节变化或自然气口才使用转场，优先采用 0.10-0.20 秒的短叠化。禁止把高亮全屏遮罩当作常规切屏。当前工具不能实现合格转场时，切换到已指定的剪辑工具链（如 OpenMontage/FFmpeg），不要继续堆补丁。渲染后对每个转场抽取前、中、后至少三帧并正常速度观看，检查闪白、闪黄、黑帧、重影和字幕叠影。
- 当前拦截位置：`stage-assembly.md` 负责控制转场密度、类型和工具降级；`stage-qa.md` 要求逐个转场看片并留接触表证据。用户已经指出“闪”或“影响感官”的版本不得交付。
