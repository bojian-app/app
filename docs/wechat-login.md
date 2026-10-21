# 微信登录配置

App 登录页提供微信及抖音登录。抖音移动应用已审核通过，使用官方 SDK 授权并由服务端换取身份，配置与验证见 [抖音移动应用登录](douyin-login.md)。手机号登录入口及独立页面已移除；登录后的短信手机号绑定仍可使用，也可暂时跳过。

微信登录在用户同意协议并主动点击后，使用 Fluwx no-pay 插件调用原生 SDK，验证随机 state，随后把一次性授权码交给后端判断账号状态。已有账号直接登录；未注册时展示“该账号尚未注册”，仅在用户选择“确认注册并登录”后创建账号并登录。取消、拒绝、未安装微信及登录失败不会建立会话。取消授权或注册时只恢复登录按钮，不显示取消文案；真正失败的提示位于登录按钮下方、协议之前。

每次主动发起微信登录均设置 `NormalAuth(nonAutomatic: true)`，关闭近期已授权账号的自动授权，要求微信重新展示官方授权确认页。Android 与 iOS 插件分别传递到 `SendAuth.Req.nonAutomatic` 和 `SendAuthReq.nonautomatic`；真实显示效果需真机验收。退出博简仍只清除博简会话，不撤销微信平台授权；未退出时重新打开 App 仍恢复已有会话。

取消授权收到 SDK 回调时立即恢复登录入口；如果用户从微信直接返回 App 而没有回调，返回前台等待一秒接收已排队的成功回调，仍无结果则按取消恢复。Android 的多个微信应用选择器可能只引发 inactive/resumed 而不进入后台，因此本次授权期间失焦后恢复焦点也启用该兜底。选择器显示时或选中微信继续跳转、再次失焦时不触发取消；iOS 仍要求确实进入后台再返回，临时失焦不取消。前次授权的非空 state 回调不会结束当前请求；原有两分钟超时保留。

当前移动应用 AppID：`wx049616c5bdaf4ff2`。AppSecret 只设置在后端 `WECHAT_MOBILE_APP_SECRET`，客户端和仓库不保存。

Android 注册信息：

- 包名：`cn.kelance.bojian`
- 当前测试包（debug 证书）签名 MD5：`b1e2c83b09bcdea35a00ce4bd15bae42`
- 本机 `%USERPROFILE%\.android\debug.keystore` 实际 MD5：`9d09337c5d06e426ed924cb7dd94ffc6`（**与上面那个不同**，这台机器签出来的 debug 包无法通过微信校验）
- 正式包（release 证书）签名 MD5：`041be49bd42cc4b8e8ae534eee604765`
- 微信 SDK 回调由插件注册的 `cn.kelance.bojian.wxapi.WXEntryActivity` 接收。
- **上架前必须把微信开放平台的「应用签名」改成正式包的 MD5**，否则签名校验失败、微信登录直接不可用；改完用正式包真机回归一次授权与回跳。

iOS 注册信息：

- Bundle ID：`cn.kelance.bojian`
- Universal Link：`https://bojian.kelance.cn/wechat/`
- URL scheme：上述移动应用 AppID。
- 关联域名：`applinks:bojian.kelance.cn`，线上 `.well-known/apple-app-site-association` 已声明 `C6Z4939YD6.cn.kelance.bojian` 和 `/wechat/*`。
- 原生微信客户端授权回跳仍需使用签名的 iOS 真机包验证。

后端接口：`POST /api/v1/auth/wechat/mobile/exchange`，请求字段为 `code` 和 `agreement_versions`（`terms`、`privacy`），携带原有设备、平台、版本请求头。后端使用移动应用专用 AppID/AppSecret 验证微信身份，保留其他客户端使用的网站扫码及既有认证接口。微信账号按应用身份识别，不根据昵称自动合并现有手机号账号。

插画及图标来源见 [登录素材与授权](login-assets.md)。

未注册响应只包含 `registration_required`、一次性 `registration_token` 和有效期，不包含登录令牌或用户。只有用户确认后才调用 `/auth/registrations/confirm`，提交 `confirmed=true`、确认凭证及协议版本。取消、返回或退出登录不会调用注册接口，已有账号不会出现注册确认弹窗。确认凭证绑定原设备，五分钟失效，内容由服务端加密保存，不能重复使用。

验证覆盖：原生授权成功、取消、拒绝、回调 state 不匹配、未安装及无法打开微信；页面同意协议、重复点击、登录会话保存、失败和取消不登录、退出后的晚到授权；手机号绑定、跳过后继续使用及隐私文档回归。真实授权需要由测试者在微信中确认。

参考：[Fluwx 插件文档](https://pub.dev/packages/fluwx_no_pay)、[微信移动应用登录指南](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/WeChat_Login/Development_Guide.html)。


## 登录后的手机号绑定

微信登录不会返回微信绑定的手机号。App 根据 `GET /me` 的 `phone_masked` 判断当前账号是否已绑定，资料加载成功且尚未绑定时，使用统一 Cupertino 确认样式弹出绑定界面；可选择“暂时跳过”，本次会话内不会重复提示。下次登录或恢复会话时仍未绑定则再次提示，后续也可以从“隐私与设置—账号安全—手机号”主动绑定。资料加载失败时保持未知状态，不误判为未绑定。

绑定复用图形验证与短信服务，不调用手机号登录或注册接口：

- `POST /me/phone/sms-codes`：携带登录令牌，提交 `phone`、`captcha_token` 和 `purpose=BIND_PHONE`；验证码限定当前账号与绑定用途，有效期五分钟，按手机号和账号限制发送频率。
- `POST /me/phone`：携带当前登录令牌并提交 `phone` 与六位 `code`，成功返回 `phone_masked`。服务端在事务内保存手机号、身份关联及安全事件；客户端刷新绑定状态，账号 ID、现有会话及业务数据不变。
- 已绑定相同号码的成功请求可以安全重试；已绑定其他号码的账号不能通过本接口换号。号码属于其他账号时返回 `PHONE_IN_USE`，提示使用其他号码，不自动合并账号。
- 取消图形验证、发送失败、验证码错误或过期时不会绑定。错误验证码会消费本次凭证，需重新获取。未登录、用途不匹配或其他账号申请的验证码均不可绑定。
- 用户退出登录或账号切换后，晚到的验证码和绑定响应不会写入新账号；旧资料响应也不会覆盖已确认的绑定状态。

新增服务端接口需要部署对应后端版本，才能在设备上完成真实短信绑定。
