# 开发者认证水晶徽章

资源：`developer_crystal_v1.png`，1254 × 1254 RGBA PNG，保留内置生成工具输出的透明通道。通过 imagegen 技能的内置 image_gen 工具生成；以用户提供的第一枚蓝银水晶勋章为风格参考，新生成素材，未复制参考截图或使用通用图标。

2026-10-20 按用户“宽高一致”的反馈，通过内置 image_gen 编辑原徽章：拓宽水晶主体、缩短纵向比例，使包含顶部金色挂饰的完整可见轮廓接近 1:1。保留资源路径以供现有组件直接加载，保留生成的透明通道；测试按 alpha ≥ 128 的主体边界检查宽高比，容差 2%（在 26px 显示尺寸下不足 1px）。

按用户“页面上显示缩小 1/3”的反馈，显示尺寸统一为原来的 2/3：昵称旁与个人详情默认占用约 17.33 × 17.33 逻辑像素（26 × 2/3），滚动收起时缩为 12 × 12（18 × 2/3）；不展示可见文字标签。仅当前账号服务端认证通过时展示。认证说明保留于无障碍标签和长按提示。Flutter 按 192 像素缓存解码，避免加载全尺寸图像占用额外内存。

原始生成提示词（内置工具，transparent_background=true）：

```text
Use case: stylized-concept. Asset type: a SINGLE standalone premium gemstone achievement medal for a mobile profile identity badge. Create one original icy blue and silver faceted crystal medal, reminiscent of the refined first-tier crystal awards in high quality game profile UI. A crisp dimensional hexagonal/octagonal platinum bezel surrounds a luminous pale sapphire crystal, with a distinctive large angular diamond-cut centerpiece and elegant geometric facets reflecting ice blue, deep sapphire blue and silver-white. At the top a very small champagne-gold three-stripe suspension clasp, directly connected to the crystal, as on a collectible medal. Frontal presentation, slight three dimensional bevels, tasteful polished metal, sharp architectural cuts, exquisite balanced symmetry, clean intentional highlights rather than soft bloom. Sophisticated jewel craftsmanship, readable strong silhouette at only 24 pixels tall. Transparent background with real alpha; tightly framed centered single object occupying approximately 85% of square canvas height, minimal clear margin, no drop shadow outside the medal. No letters, no text, no labels, no code brackets, no checkmark, no shields, no banners, no panel, no wings, no laurels, no crowns, no extra objects, no floating sparkles. This is one production-ready cutout jewel asset, not a UI screenshot or design sheet. Render at 1024x1024.
```

等宽等高版本最终编辑提示词（内置工具，transparent_background=true，以上一轮比例调整结果为编辑目标）：

```text
Edit the supplied medal image. Make the ACTUAL VISIBLE OBJECT exactly as wide as it is tall. This is a proportion correction only: take the whole current medal and WIDEN it horizontally, making the widest outside points of its left and right silver tips span precisely the same distance as the distance from the gold tip at the top to the bottom silver tip. No longer vertically elongated. Use a SQUARE 1:1 outline envelope for the entire jewel INCLUDING the tiny gold top element. Keep the blue crystal, polished silver faceted metal, gold top accents, existing symmetric jewel design, frontal view. Center with equal transparent margins, keep real alpha transparency. It should be a balanced broad octagonal badge. No added elements, no text, no shadow, no background. Target opaque silhouette bounding box width = height, deviation less than 1%.
```
