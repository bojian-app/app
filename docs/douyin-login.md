# 抖音移动应用登录

抖音入口使用官方 SDK 原生授权。仅在用户明确同意协议并主动点击后初始化 SDK；取消或授权失败不会创建会话，未知账号需点击“确认注册并登录”。微信与抖音账号分别识别，不按昵称、手机号或跨应用标识自动合并。

## 应用配置

- Client Key：`awll007zjoe179hs`，仅为应用公开标识，可通过 Dart define `DOUYIN_CLIENT_KEY` 配置。变更后须同时更新 iOS URL Scheme 和桥接代码中的应用校验。
- 登录回调：`https://bojian.kelance.cn/douyin/`。
- Android applicationId：`cn.kelance.bojian`；开放平台中的包名和应用签名必须与安装包一致。
- 当前安装包签名 MD5：`b1e2c83b09bcdea35a00ce4bd15bae42`。如授权页提示 `10011`，核对包名；`10017` 核对签名；`10015` 核对是否使用了移动应用的 Client Key。SDK 的失败回调保留数值错误码，不再把所有失败视为用户拒绝；原始 SDK 文本、授权码与令牌不用于错误提示。
- iOS Bundle ID：`cn.kelance.bojian`；URL Scheme 使用 Client Key，域名关联沿用 `applinks:bojian.kelance.cn`。
- iOS 域名关联文件需为 `C6Z4939YD6.cn.kelance.bojian` 同时保留 `/wechat/*` 和 `/douyin/*`；可发布的文件位于 `ios/universal-links/`。回调落地页不处理、展示或存储 URL 中的授权码，回调请求不写访问日志。
- SDK scope 仅 `user_info`，关闭可选 SDK 行为统计，不请求手机号、视频、关系或分享权限。

Android 使用官方 Maven 源的 `opensdk-china-external`、`opensdk-common`、`openokhttp-china-external`，统一固定为 `0.2.0.10`。官方文档列出的 `0.2.0.11` 引用了在文档指定仓库不可获取的 `polaris:1.1.9.0.1-bugfix`，因此当前固定可解析的前一版本，未移除安全依赖或使用第三方二进制镜像。

iOS 使用 CocoaPods 的 `DouyinOpenSDK 4.2.5`，与项目已有 Swift Package Manager 插件共存。先运行 `flutter pub get`，然后**在 ios 目录**执行 `pod install`；Flutter 的 podhelper 会跳过已有 Swift 包，避免重复接入微信等 SDK。官方当前二进制支持 iOS 真机，Apple Silicon 的 arm64 模拟器不在该 SDK 支持范围内，真实授权需真机验证。

## 服务端接口与密钥

`POST /api/v1/auth/douyin/mobile/exchange`：

```json
{
  "code": "一次性原生授权码",
  "agreement_versions": {"terms": "1.0", "privacy": "1.0"}
}
```

携带现有 `x-device-id`、`x-platform`、`x-app-version` 等请求头。服务端通过表单 POST 向 `https://open.douyin.com/oauth/access_token/` 换码，验证成功状态、OpenID、令牌与有效期；身份以应用 Client Key 与官方返回的 OpenID 生成摘要，只用于 `DOUYIN` 身份。抖音令牌和原始身份不会返回 App，也不自动读取手机号。

服务端配置只从环境变量读取，必须同时设置：

```dotenv
DOUYIN_CLIENT_KEY=应用公开标识
DOUYIN_CLIENT_SECRET=仅存放于服务端私有配置
```

真实 Secret 不应写入此文档、`.env.example`、客户端或 Git。缺少配置时返回 `DOUYIN_LOGIN_UNAVAILABLE`，不会伪造登录成功。用户已提供的私有配置保存于服务端私有环境文件，具体部署结果以本轮验证记录为准。

未知账号返回原有 `registration_required`、一次性注册确认凭证和有效期；仅在明确同意后调用 `/auth/registrations/confirm`。确认凭证绑定设备和平台，五分钟失效。登录后手机号未绑定时仍可短信绑定或暂时跳过，绑定使用 `BIND_PHONE` 用途。

## 验证边界

自动化使用模拟 SDK／网关与隔离本机数据库验证回调 state、取消、失败、超时、重复请求、账号状态变化、明确注册、身份隔离、会话更新及手机号跳过；不会代替用户点击真实抖音授权。真机联调需使用与开放平台包名、签名一致的安装包，且服务端及回调配置已经发布。

官方参考：[Android 接入](https://developer.open-douyin.com/docs/resource/zh-CN/dop/develop/sdk/mobile-app/access/android)、[Android 授权](https://developer.open-douyin.com/docs/resource/zh-CN/dop/develop/sdk/mobile-app/permission/android/permission-develop-guide)、[iOS 接入](https://developer.open-douyin.com/docs/resource/zh-CN/dop/develop/sdk/mobile-app/access/ios)、[获取 access_token](https://developer.open-douyin.com/docs/resource/zh-CN/dop/develop/openapi/account-permission/get-access-token)。
