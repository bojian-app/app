# 项目开发流程

本项目的功能开发、缺陷修复及代码、测试、配置、项目规范变更，必须先读取并使用项目技能：

- [bojian-issue-workflow](.agents/skills/bojian-issue-workflow/SKILL.md)

提交前仅使用以下三个已安装的 Flutter 技能作为技术审查依据，按最终改动选择适用内容：

- [flutter-apply-architecture-best-practices](.agents/skills/flutter-apply-architecture-best-practices/SKILL.md)：架构分层、状态与数据职责。
- [flutter-add-widget-test](.agents/skills/flutter-add-widget-test/SKILL.md)：组件行为及相关测试。
- [flutter-fix-layout-issues](.agents/skills/flutter-fix-layout-issues/SKILL.md)：布局约束、溢出及显示问题。

审查最终拟提交内容，处理问题并复查；记录明确结论。审查通过即可直接放行已有授权的提交和推送，无需额外确认或另设审查技能。测试通过不能替代代码审查。

用户约定：先创建或关联 GitHub Issue，说明问题、准备变更的内容和验收标准，再开发与验证、完成提交前代码审查；提交记录使用“一句话概述＋具体变更小点”并关联 Issue；代码成功推送且验收完成后，记录结果再关闭 Issue。提交和推送沿用当次任务已有授权，不因使用技能而扩大授权。

纯咨询、只读排查和安装已有版本不需要新建 Issue。用户对当前任务的明确指示优先。
