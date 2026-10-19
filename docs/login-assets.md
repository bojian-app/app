# 登录素材与授权

## 开源插画

- 作者与项目：Pablo Stanley，[Open Doodles](https://www.opendoodles.com/)。
- 来源：作者画廊中的阅读线稿，[原始 SVG](https://opendoodles.s3-us-west-1.amazonaws.com/reading.svg)。
- 授权：作者[授权说明](https://www.opendoodles.com/about)明确采用 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)。完整授权文本与来源保存在 `assets/login/OPEN-DOODLES-LICENSE.txt`，随插画一同打包。
- 项目文件：`assets/login/reading.svg`。保留原图全部路径与构图，将黑色线条改为深灰 `#34383E`，粉色书本改为淡蓝灰 `#DCE5F1`，以小幅线稿呈现。
- 下载日期：2026-10-17。该图片直接来自作者画廊，没有经过 AI 生成或重绘。之前的 IRA Design 与 AI 插画保留在工作区，已不注册为应用资源。

## 登录图标

图标直接采用官方 App Store 应用页由发行者提供的 512×512 JPEG 原图，在 Flutter 中按一致的 24 像素尺寸和圆角显示。图标用于识别对应登录方式，属于各自权利人的应用标识，不适用 Open Doodles 的 CC0 授权。

| 本地文件 | 原应用与发行者 | 官方应用页 |
| --- | --- | --- |
| `assets/login/wechat.jpg` | 微信 / WeChat | [微信](https://apps.apple.com/cn/app/id414478124) |
| `assets/login/douyin.jpg` | 抖音 / Beijing Douyin Technology Co., Ltd. | [抖音](https://apps.apple.com/cn/app/id1142110895) |

原图下载地址（2026-10-17 官方 Lookup API 返回）：

- [微信原图](https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/61/70/2e/61702e05-0531-165f-5cd3-012c8b5b3b20/AppIcon-0-0-1x_U007epad-0-1-0-sRGB-0-85-220.png/512x512bb.jpg)
- [抖音原图](https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/b9/10/a6/b910a676-a3ee-42b6-3c82-e824bd391aca/AppIcon-0-0-1x_U007emarketing-0-0-0-7-0-0-85-220.png/512x512bb.jpg)

## 当前入口状态

微信与抖音使用原生授权登录；抖音移动应用已审核通过，接入配置见 [抖音移动应用登录](douyin-login.md)。手机号登录入口、页面及电话图标已移除，登录后的手机号绑定仍可暂时跳过。第三方 Client Secret 仅由服务端私有配置保存，不写入应用图标、客户端或素材文档。
