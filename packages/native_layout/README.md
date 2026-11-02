# 博简原生模板协议 v1

`native_layout.dart` 同时用于正式 App 和 `tools/native_renderer` 的发布前渲染检查。修改排版规则时同时重建两个目标，并更新 `native-layout-v1-20261031` 的渲染器版本和对应模板检查结果。

作者上传目录包：`manifest.json`、`index.html`、`assets/`。**无需提供 `layout.json`**；服务端解析 HTML 字段和 CSS，生成 layout 并记录源文件与素材 SHA-256。上传包即使含旧 layout，也不会使用它。生成的 layout 使用 `format: bojian-native-layout`、`schemaVersion: 1.0`。目录包上限 8 MiB，解压上限 16 MiB，单文件 8 MiB，layout 256 KiB，素材 64 个。当前仅接受 A4 794×1123、PNG 和无外部引用的 SVG。

支持组件：text、svg、image、column、row、wrap、richText、sectionHeading、section、repeat、gridRepeat、intentionCell。字段沿用 marketResumeFields。字体使用 App 随附的阿里巴巴普惠体；不加载模板自带字体或网络字体。

旧 HTML 模板继续使用原有引擎。新目录包由服务端编译并同时保存 HTML 兼容版和 native 数据；新 App 使用 Flutter，旧 App 使用 HTML。编译器 `html-native-v1-20261031` 支持 V2 字段协议下的单栏 A4、弹性行、经历循环、证书网格、图标笔刷标题与富文本。当前不支持任意 HTML/CSS；定位、浮动、复杂网格等结构返回带元素位置的转换错误，不静默降级。字体统一使用 App 内置字体。转换完成后仍须执行同一 Flutter 渲染器的示例/空白检查并通过审核，才能发布。

原生预览和 PDF 导出共用 TextPainter 测量结果；PDF 装饰层为图片，文字仍可复制。原生模板 Word 使用按测量坐标定位的可编辑文字框，并固定分页与断行，避免正文重排后与装饰层错位。大幅增删内容应在 App 中修改并重新导出；阅读器字体替代仍可能改变字形。后台检查和审核 PDF 由同一 Flutter 包的 Web 编译产物生成，仅用于示例检查。

发布前：在 app/tools/native_renderer 执行 flutter build web --release --no-web-resources-cdn，并将 build/web 部署到 API 镜像 /opt/bojian-native-renderer。目录不向公网提供。后台以本地 Chromium 驱动 Flutter，通过明确的 ready 信号再输出预览。
