from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path


def load_module():
    script = Path(__file__).resolve().parents[1] / "scripts" / "generate_mainline_topic_decision.py"
    spec = importlib.util.spec_from_file_location("generate_mainline_topic_decision", script)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def cp(*values: int) -> str:
    return "".join(chr(value) for value in values)


def test_extracts_recommendation_when_numbered_section_points_to_fallback_heading():
    module = load_module()
    lines = [
        "# 2026-05-24 AI" + cp(0x9009, 0x9898, 0x65E5, 0x62A5),
        "",
        "## 4. " + cp(0x63A8, 0x8350, 0x5F53, 0x5929, 0x6700, 0x9002, 0x5408, 0x505A, 0x7684, 0x4E00, 0x6761),
        "",
        "## " + cp(0x4ECA, 0x65E5, 0x6539, 0x505A, 0x5E38, 0x9752, 0x9898),
        "",
        "**" + cp(0x63A8, 0x8350, 0x9898, 0x76EE) + "：Workflow / Agent / Human**",
        "",
        "### " + cp(0x6807, 0x9898, 0x5907, 0x9009),
        "",
        "- " + cp(0x771F, 0x6B63, 0x6709, 0x7528, 0x7684, 0x0020, 0x0041, 0x0049, 0x0020, 0x5DE5, 0x4F5C, 0x6D41),
        "",
        "### " + cp(0x6838, 0x5FC3, 0x89C2, 0x70B9),
        "",
        "- " + cp(0x8FB9, 0x754C, 0x5148, 0x4E8E, 0x5DE5, 0x5177),
    ]

    section = module.extract_recommended_section(lines)

    assert module.parse_topic(section) == "Workflow / Agent / Human"
    assert module.parse_subsection_bullets(section, "### " + cp(0x6807, 0x9898, 0x5907, 0x9009)) == [
        cp(0x771F, 0x6B63, 0x6709, 0x7528, 0x7684, 0x0020, 0x0041, 0x0049, 0x0020, 0x5DE5, 0x4F5C, 0x6D41)
    ]


def test_run_does_not_emit_manual_confirmation_placeholder_for_valid_daily_brief():
    module = load_module()
    with tempfile.TemporaryDirectory() as temp_dir:
        workspace = Path(temp_dir)
        content_root = workspace / cp(0x5185, 0x5BB9, 0x4F01, 0x5212)
        inbox = content_root / ("00-" + cp(0x6536, 0x4EF6, 0x7BB1))
        inbox.mkdir(parents=True)
        daily = inbox / ("2026-05-24-AI" + cp(0x9009, 0x9898, 0x65E5, 0x62A5) + ".md")
        daily.write_text(
            "\n".join(
                [
                    "# daily",
                    "## 4. " + cp(0x63A8, 0x8350, 0x5F53, 0x5929, 0x6700, 0x9002, 0x5408, 0x505A, 0x7684, 0x4E00, 0x6761),
                    "## " + cp(0x4ECA, 0x65E5, 0x6539, 0x505A, 0x5E38, 0x9752, 0x9898),
                    "**" + cp(0x63A8, 0x8350, 0x9898, 0x76EE) + "：Workflow / Agent / Human**",
                    "### " + cp(0x6807, 0x9898, 0x5907, 0x9009),
                    "- " + cp(0x8FB9, 0x754C, 0x4E0D, 0x5206, 0x6E05, 0xFF0C, 0x0041, 0x0049, 0x8D8A, 0x7528, 0x8D8A, 0x4E71),
                ]
            ),
            encoding="utf-8",
        )

        result = module.run(date="2026-05-24", workspace=workspace, write=False)

    assert result["topic"] == "Workflow / Agent / Human"
    assert result["recommended_title"]
    assert "人工确认" not in result["topic"]
    assert "人工确认" not in result["recommended_title"]
    assert result["takeaway_type"]
    assert result["viewer_gain"]
    assert result["traffic_hook"]
    assert "热点事实" in result["hotspot_package"]
    assert "角度候选" in result["hotspot_package"]


def test_parse_topic_supports_heading_followed_by_bold_topic():
    module = load_module()
    topic = "AI 短期内不会一下子打穿整份白领工作"
    section = [
        "### " + cp(0x63A8, 0x8350, 0x9898, 0x76EE),
        "",
        f"**{topic}**",
        "",
        "### " + cp(0x6807, 0x9898, 0x5907, 0x9009),
        "- title",
    ]

    assert module.parse_topic(section) == topic


def test_parse_topic_supports_inline_recommend_heading():
    module = load_module()
    topic = "从今天起，AI Agent 不是免费劳动力了"
    section = [
        "### 推荐：" + topic,
        "",
        "### " + cp(0x6807, 0x9898, 0x5907, 0x9009),
        "- title",
    ]

    assert module.parse_topic(section) == topic


def test_parse_topic_supports_plain_labeled_recommend_topic_with_bold_value():
    module = load_module()
    topic = "Google Colab CLI 出来后，AI Agent 多了一个远程算力工位"
    section = [
        "推荐选题：**" + topic + "**",
        "",
        "### " + cp(0x0033, 0x0030, 0x0020, 0x79D2, 0x5F00, 0x5934, 0x65B9, 0x5411),
        "> opening",
    ]

    assert module.parse_topic(section) == topic


def test_preflight_accepts_today_recommendation_section():
    module = load_module()
    with tempfile.TemporaryDirectory() as temp_dir:
        workspace = Path(temp_dir)
        content_root = workspace / cp(0x5185, 0x5BB9, 0x4F01, 0x5212)
        inbox = content_root / ("00-" + cp(0x6536, 0x4EF6, 0x7BB1))
        inbox.mkdir(parents=True)
        daily = inbox / ("2026-06-01-AI" + cp(0x9009, 0x9898, 0x65E5, 0x62A5) + ".md")
        daily.write_text(
            "\n".join(
                [
                    "# daily",
                    "## 4. " + cp(0x4ECA, 0x65E5, 0x63A8, 0x8350, 0x9009, 0x9898),
                    "",
                    "### " + cp(0x63A8, 0x8350) + "：" + "从今天起，AI Agent 不是免费劳动力了",
                    "",
                    "### " + cp(0x6807, 0x9898, 0x5907, 0x9009),
                    "- AI Agent 从今天开始要算账了",
                    "",
                    "### " + cp(0x6838, 0x5FC3, 0x89C2, 0x70B9),
                    "- 先写预算，再开 Agent。",
                ]
            ),
            encoding="utf-8",
        )

        result = module.preflight(date="2026-06-01", workspace=workspace)

    assert result["ok"] is True
    assert result["topic_preview"] == "从今天起，AI Agent 不是免费劳动力了"


def test_preflight_accepts_chinese_numbered_today_recommendation_section():
    module = load_module()
    with tempfile.TemporaryDirectory() as temp_dir:
        workspace = Path(temp_dir)
        content_root = workspace / cp(0x5185, 0x5BB9, 0x4F01, 0x5212)
        inbox = content_root / ("00-" + cp(0x6536, 0x4EF6, 0x7BB1))
        inbox.mkdir(parents=True)
        daily = inbox / ("2026-06-02-AI" + cp(0x9009, 0x9898, 0x65E5, 0x62A5) + ".md")
        daily.write_text(
            "\n".join(
                [
                    "# daily",
                    "## " + cp(0x56DB, 0x3001, 0x4ECA, 0x65E5, 0x63A8, 0x8350),
                    "",
                    "### " + cp(0x63A8, 0x8350, 0x9898, 0x76EE),
                    "",
                    "**AI Agent 瑕佸洖鍒颁綘鐨勭數鑴戞湰鍦颁簡**",
                    "",
                    "### " + cp(0x6807, 0x9898, 0x5907, 0x9009),
                    "- title",
                ]
            ),
            encoding="utf-8",
        )

        result = module.preflight(date="2026-06-02", workspace=workspace)

    assert result["ok"] is True
    assert result["topic_preview"] == "AI Agent 瑕佸洖鍒颁綘鐨勭數鑴戞湰鍦颁簡"


def test_preflight_accepts_today_variant_recommended_section_and_bold_recommend_topic():
    module = load_module()
    with tempfile.TemporaryDirectory() as temp_dir:
        workspace = Path(temp_dir)
        content_root = workspace / cp(0x5185, 0x5BB9, 0x4F01, 0x5212)
        inbox = content_root / ("00-" + cp(0x6536, 0x4EF6, 0x7BB1))
        inbox.mkdir(parents=True)
        daily = inbox / ("2026-06-05-AI" + cp(0x9009, 0x9898, 0x65E5, 0x62A5) + ".md")
        daily.write_text(
            "\n".join(
                [
                    "# daily",
                    "## " + cp(0x63A8, 0x8350, 0x4ECA, 0x5929, 0x6700, 0x9002, 0x5408, 0x505A, 0x7684, 0x4E00, 0x6761),
                    "",
                    "**" + cp(0x63A8, 0x8350, 0x9009, 0x9898) + "：" + "ChatGPT 记忆变强后，普通人该怎么搭自己的 AI 长期记忆？**",
                    "",
                    "### " + cp(0x6807, 0x9898, 0x5907, 0x9009),
                    "- title",
                ]
            ),
            encoding="utf-8",
        )

        result = module.preflight(date="2026-06-05", workspace=workspace)

    assert result["ok"] is True
    assert result["topic_preview"] == "ChatGPT 记忆变强后，普通人该怎么搭自己的 AI 长期记忆？"


def test_run_keeps_memory_topic_frontstage_even_with_cost_note_in_supporting_evidence():
    module = load_module()
    with tempfile.TemporaryDirectory() as temp_dir:
        workspace = Path(temp_dir)
        content_root = workspace / cp(0x5185, 0x5BB9, 0x4F01, 0x5212)
        inbox = content_root / ("00-" + cp(0x6536, 0x4EF6, 0x7BB1))
        inbox.mkdir(parents=True)
        daily = inbox / ("2026-06-05-AI" + cp(0x9009, 0x9898, 0x65E5, 0x62A5) + ".md")
        daily.write_text(
            "\n".join(
                [
                    "# daily",
                    "## " + cp(0x5019, 0x9009, 0x9009, 0x9898),
                    "### " + cp(0x9009, 0x9898) + " 1：" + "ChatGPT 记忆变强后，普通人该怎么搭自己的 AI 长期记忆？",
                    "- " + cp(0x4E8B, 0x4EF6, 0x4E8B, 0x5B9E) + "：" + "OpenAI 更新 Dreaming 记忆系统。",
                    "- " + cp(0x4E3A, 0x4EC0, 0x4E48, 0x503C, 0x5F97, 0x666E, 0x901A, 0x4EBA, 0x5173, 0x6CE8) + "：" + "很多人最大的问题是每次都要重新解释自己是谁。",
                    "- " + cp(0x4E0E, 0x672C, 0x8D26, 0x53F7, 0x7684, 0x8FDE, 0x63A5, 0x70B9) + "：" + "可以直接连接 Common Brain 和项目规则。",
                    "- " + cp(0x53EF, 0x7528, 0x89C6, 0x9891, 0x7D20, 0x6750, 0x65B9, 0x5411) + "：" + "OpenAI 页面；无记忆 vs 有记忆对比。",
                    "## " + cp(0x63A8, 0x8350, 0x4ECA, 0x5929, 0x6700, 0x9002, 0x5408, 0x505A, 0x7684, 0x4E00, 0x6761),
                    "**" + cp(0x63A8, 0x8350, 0x9009, 0x9898) + "：" + "ChatGPT 记忆变强后，普通人该怎么搭自己的 AI 长期记忆？**",
                    "### " + cp(0x0033, 0x0030, 0x0020, 0x79D2, 0x5F00, 0x5934, 0x65B9, 0x5411),
                    "- ChatGPT 开始会整理长期记忆，但普通人更该先搭自己的三层记忆。",
                    "### " + cp(0x6838, 0x5FC3, 0x89C2, 0x70B9),
                    "1. 个人偏好：写作口吻、工具偏好、输出格式。",
                    "2. 项目规则：目标、目录、AGENTS 和工作流。",
                    "3. 验收记录：哪里失败过，下次先查什么。",
                    "### " + cp(0x7D20, 0x6750, 0x6E05, 0x5355),
                    "- OpenAI Dreaming 官方页证据板",
                    "- 辅助证据：GitHub Copilot AI Credits 说明长期 Agent 任务需要预算。",
                    "### " + cp(0x6807, 0x9898, 0x5907, 0x9009),
                    "- ChatGPT 记忆变强了，但普通人更该学会这 3 层记忆",
                    "- 别再只背提示词了，你需要的是自己的 AI 长期记忆",
                ]
            ),
            encoding="utf-8",
        )

        result = module.run(date="2026-06-05", workspace=workspace, write=False)

    assert result["takeaway_type"] != "成本变化"
    assert "更贵" not in result["recommended_title"]
    assert "记忆" in result["topic"]


def test_slugify_is_case_insensitive_for_workflow_agent_topics():
    module = load_module()

    slug = module.slugify("为什么 AI Workflow Agent Human judgment 边界很重要")

    assert slug == "ai-workflow-agent"


def test_frontstage_guard_prefers_feature_difference_over_repeated_boundary_bucket():
    module = load_module()

    takeaway_type = module.choose_takeaway_type_with_frontstage_guard(
        "Codex 终于能操作 Windows 了，普通人能让它干什么？",
        "OpenAI 发布 Codex Windows Computer Use 和远程控制能力，支持看屏幕、点击和输入",
        "任务边界、文件边界、验收边界",
        "Windows 是普通人最常见的工作环境",
    )

    assert takeaway_type == "功能差异"


def test_choose_better_candidate_prefers_frontstage_codex_angle():
    module = load_module()
    lines = [
        "## 候选选题",
        "### 选题 1：Codex 终于能操作 Windows 了，普通人现在能让它干什么？",
        "- 事件事实：OpenAI 发布 Codex Windows Computer Use，支持看屏幕、点击和输入。",
        "- 为什么值得普通人关注：Windows 是最常见的工作环境，现在多了真实桌面动作。",
        "- 与本账号连接点：可以直接展示本地桌面任务。",
        "- 可用视频素材方向：Windows 录屏；release note 信息卡；手机盯进度。",
        "- 风险或不适合点：不要把发布能力讲成人人立刻可用。",
        "### 选题 2：别急着让 AI 控制电脑，先给 Codex 写清 3 个边界",
        "- 事件事实：桌面 Agent 容易点错、改错、跑错命令。",
        "- 为什么值得普通人关注：很多人会一句话让它全自动。",
        "- 与本账号连接点：可以直接讲 AGENTS 和 QA。",
        "- 可用视频素材方向：边界清单卡。",
        "- 风险或不适合点：如果不做真实演示，容易变成泛安全建议。",
    ]

    better = module.choose_better_candidate(
        lines,
        "Codex 终于能操作 Windows 了：普通人让 AI 接管电脑前，先准备好 3 个安全边界。",
    )

    assert better is not None
    assert "Codex" in better["topic"]
    assert "干什么" in better["topic"]
    assert better["repeated_score"] == 0


if __name__ == "__main__":
    test_extracts_recommendation_when_numbered_section_points_to_fallback_heading()
    test_run_does_not_emit_manual_confirmation_placeholder_for_valid_daily_brief()
    test_parse_topic_supports_heading_followed_by_bold_topic()
    test_parse_topic_supports_inline_recommend_heading()
    test_parse_topic_supports_plain_labeled_recommend_topic_with_bold_value()
    test_preflight_accepts_today_recommendation_section()
    test_preflight_accepts_chinese_numbered_today_recommendation_section()
    test_preflight_accepts_today_variant_recommended_section_and_bold_recommend_topic()
    test_run_keeps_memory_topic_frontstage_even_with_cost_note_in_supporting_evidence()
    test_slugify_is_case_insensitive_for_workflow_agent_topics()
    test_frontstage_guard_prefers_feature_difference_over_repeated_boundary_bucket()
    test_choose_better_candidate_prefers_frontstage_codex_angle()
    print("generate_mainline_topic_decision tests passed")
