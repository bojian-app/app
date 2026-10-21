# 模板 DOM 兼容修复自审（Issue #35）

范围：`assets/templates/market_renderer.js` 与独立浏览器回归脚本。未改动其他进行中的移动端功能。

自审结论：通过。按 flutter-apply-architecture-best-practices 检查职责，字段填充与分页仍在已有渲染层，未引入请求、业务状态或 Flutter 页面耦合。未修改 Flutter Widget/布局约束，flutter-add-widget-test 与 flutter-fix-layout-issues 的组件修改流程不适用；保留并执行已有文档与原生导出测试。

处理的问题：
- 同时兼容问号、#if、或条件；只有独立条件元素增加块嵌套深度，防止行内条件吞掉外层结束。
- 空集合、缺失集合及空白条目为空；缺失技能名称不会误填本人姓名，循环内仍可引用全局联系方式。
- 未闭合结构报错，条目数量与页数有上限。

验证：真实 Chromium 检查条件别名、或条件、嵌套条件、空/缺失集合、条目作用域、非法结构、多页内容；`flutter test test/resume_market_document_test.dart test/resume_native_export_test.dart` 4 项通过。后端镜像内嵌脚本与此文件逐字节同步。

运行浏览器回归：`PLAYWRIGHT_MODULE=/absolute/path/to/playwright/index.mjs CHROMIUM_PATH=/path/to/chrome node tool/test_market_renderer.mjs`。

限制：本任务不发布 App 安装包，移动端修复需随下一版客户端发布。浏览器测试不能替代所有手机 WebView 的实机验收。
