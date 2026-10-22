# App 扫码登录：官网接入

对应 Issue：https://github.com/fahnzjan/bojian-mobile/issues/32

本次提供 App 与服务端能力，不新增官网页面。服务端代码需单独发布并执行迁移 `052_app_qr_login.sql` 后，线上官网才可接入。不要将 App 新版安装成功视为服务端已经上线。

## 流程与身份

1. 用户在官网明确同意用户协议、隐私政策后，官网创建短期二维码。
2. App 已登录用户从“我的 → 左侧菜单 → 扫一扫”扫描二维码。
3. 服务端将二维码认领给该用户及当前手机会话，网页状态变为 `SCANNED`。
4. App 显示博简官网登录授权和当前账号。用户点击“同意”后才变为 `CONFIRMED`，成功关闭扫码页；点击“拒绝”则变为 `CANCELED`。过期后恢复扫一扫并提示重新扫码，不显示独立过期页。
5. 创建二维码的原浏览器使用独立凭据一次性交换，得到自己的 `WEB` 会话；手机会话保留。网页会话支持现有令牌刷新、退出及账号安全中的设备撤销。

网页登录成功后，服务端在建立 `WEB` 会话的同一事务中保存 `LOGIN_SUCCEEDED` 通知，标题为“官网登录成功”，正文包含登录设备。现有实时通知事件会刷新 App 消息页的“系统通知”和未读数；通知可长期查看并标记已读。仅在 App 点击同意但浏览器尚未交换、取消、过期或失败时不会发送成功通知，重复或并发交换不会重复发送。通知不包含扫码凭据或登录令牌；历史已完成登录不补发。此行为已随 2026-10-21 服务端更新发布，现有 App 已支持该通知格式，无需重装。

官网固定来源：`https://bojian.kelance.cn`；API 根地址：`https://bojian.kelance.cn/api/v1`。二维码两分钟有效，不延长原请求，刷新应创建新请求。App 仅接受下列格式，不打开二维码中的网页、不把扫码当作授权：

```text
https://bojian.kelance.cn/app-login#v=1&session=<43字符随机ID>&token=<43字符扫码凭据>
```

官网须将 `qr_content` 原样编码为二维码。fragment 中的 `token` 是扫码凭据，不能替代浏览器凭据。不得将 `browser_token`、access token、refresh token 放进二维码、URL、分析事件或日志。

## 官网调用契约

以下接口均为 `POST`，JSON 体、JSON 信封响应，响应含 `Cache-Control: no-store`。创建、查询和交换的三个请求头保持一致：

```http
Content-Type: application/json
X-Device-Id: web:<16至96位随机字母数字、下划线或连字符>
X-Platform: WEB
X-App-Version: 1.0.0
```

`X-App-Version` 长度 1–32 字符。设备 ID 应由官网为该浏览器生成并持久化，刷新令牌时沿用同一 ID。官网 BFF 转发浏览器真实 User-Agent，服务端仅据此显示浏览器名称，名称不作为安全身份。跨来源部署须在现有 `CORS_ALLOWED_ORIGINS` 中列出真实官网来源，勿使用通配来源。

| API 路径（根地址后） | 请求体 | 作用 |
| --- | --- | --- |
| `/auth/app-qr-sessions` | `{"agreement_versions":{"terms":"1.0","privacy":"1.0"}}` | 创建，HTTP 201 |
| `/auth/app-qr-sessions/{session}/status` | `{"browser_token":"..."}` | 查询状态，每两秒一次；不要重叠轮询 |
| `/auth/app-qr-sessions/{session}/exchange` | `{"browser_token":"..."}` | 明确确认后一次性交换，HTTP 200 |

创建响应示例：

```json
{
  "data": {
    "session_id": "<43字符ID>",
    "status": "WAITING",
    "qr_content": "https://bojian.kelance.cn/app-login#session=...&token=...&v=1",
    "browser_token": "<43字符浏览器凭据，仅返回一次>",
    "expires_at": "2026-10-20T10:02:00Z",
    "poll_after_seconds": 2
  },
  "meta": {"request_id": "..."}
}
```

查询仅返回 `session_id/status/expires_at/poll_after_seconds`，不返回账号、手机号、头像或登录令牌。

| 状态 | 官网行为 |
| --- | --- |
| `WAITING` | 显示二维码，等待扫描 |
| `SCANNED` | 显示“已扫码，请在 App 确认”，继续轮询 |
| `CONFIRMED` | 停止轮询，原浏览器发起一次交换 |
| `CANCELED` | 停止轮询，显示已取消，允许生成新二维码 |
| `EXPIRED` | 停止轮询，允许生成新二维码 |
| `EXCHANGED` | 已使用，禁止重复交换；若本地没有会话，重新生成二维码 |

交换响应沿用既有登录格式：`access_token/access_expires_in_seconds/refresh_token/refresh_expires_at/user{id,public_id}`。如果交换的响应丢失，二维码仍已使用，需重新扫码，不能重放换取旧令牌。

建议官网使用同源 BFF：由 BFF 保管浏览器凭据和 API 令牌，给浏览器签发 `Secure; HttpOnly; SameSite=Lax` 会话 Cookie，校验 Origin/CSRF，并随官网会话管理撤销。不要将后端登录令牌返回给任意跨站调用或记录到前端日志。浏览器关闭或导航离开时停止轮询。临时二维码过期即不能授权；如需清理过期记录，可在已有维护任务中执行 `DELETE FROM app_qr_login_sessions WHERE expires_at < now() - interval '1 day'`。

可直接导入的无 UI 客户端示例见 [examples/app-qr-login.mjs](examples/app-qr-login.mjs)，建议在官网 BFF 调用。示例只封装协议，不写浏览器存储或日志。UI 仅拿 `sessionID/qrContent/expiresAt`，BFF 保持实例或将对应秘密放入受保护的服务端会话；生产实例不得跨用户共享。后续登录方式沿用官网既有的会话存储实现。

## App 接口

均需当前手机的 `Authorization: Bearer <access_token>`：

| API 路径 | 请求体 |
| --- | --- |
| `/me/app-qr-sessions/{session}/scan` | `{"scan_token":"..."}` |
| `/me/app-qr-sessions/{session}/confirm` | `{"scan_token":"...","confirmed":true}` |
| `/me/app-qr-sessions/{session}/cancel` | `{"scan_token":"..."}` |

响应包含 `session_id/status/website/client_name/created_at/expires_at`。只有 Android/iOS 的有效会话可认领，并绑定认领者及该手机会话。同一手机可重试扫码、确认、取消；其他账号或同账号的另一会话不能抢认领。确认与取消冲突按事务顺序处理；浏览器已经交换后不能通过二维码撤销，应使用设备撤销或退出接口。

App 离开扫码页面、进入后台或进入确认页会释放/停止相机。相机权限拒绝可在系统设置允许后重试。识别在本机进行，相机帧不发送给登录接口。账号变化后清空该页面状态，旧异步结果不能批准新账号。

## 错误与验收

- `APP_QR_INVALID` (422)：二维码或明确确认字段无效。
- `APP_QR_NOT_FOUND` (404)：不存在、扫码/浏览器凭据错误或原浏览器设备不匹配。
- `APP_QR_MOBILE_REQUIRED` (403)：非有效 Android/iOS 会话扫码。
- `APP_QR_CLAIMED` (409)：其他账号或手机会话已认领。
- `APP_QR_STATE_INVALID` (409)：尚未确认、已取消或已交换；不要循环交换。
- `APP_QR_EXPIRED` (410)：过期，在官网重建并重扫。
- `APP_QR_SOURCE_INVALID` (403)：手机已退出/被撤销、账号停用或被限制，需重新登录 App 再扫。
- `RATE_LIMITED` (429)：遵守重试间隔。创建每 IP 每分钟最多 10 次，轮询受既有全局限流约束。

联调时检查：扫描后不自动登录；取消和过期不能换令牌；复制二维码到另一浏览器仍不能以扫码凭据交换；确认后同时交换只有一个成功；新网页会话能刷新/撤销，手机仍登录。自动化集成测试使用独立本机 PostgreSQL，每项测试独立 schema 并在结束时删除；没有访问生产数据库。

扫码库按 [mobile_scanner 官方说明](https://pub.dev/packages/mobile_scanner) 接入，使用默认随包附带的 Android 识别模型，不依赖首次启动时的 Google Play Services 模型下载；相机启停由独立组件通过库控制器串行管理，先停止相机再处理登录二维码。

## 2026-10-21 登录成功系统通知发布

- 已发布服务端镜像 `bojian-api:app-qr-login-notification-20261021-r1`，二进制 SHA256：`4a44af8cfcda7779f6b5c28cb95de2b87ec49d691460a1fa698c60ab285cd351`。
- 基于线上 `app-qr-login-20261020-r1` 的校验源码快照，仅追加登录成功通知及相应测试；无新增迁移，运行环境变量不变，只重建 API 容器。
- 发布目录与回退资料：`/home/ubuntu/bojian-releases/app-qr-login-notification-20261021-r1`；`backup/database-before.dump` 已用 `pg_restore --list` 校验。旧镜像及原 Compose 配置保留，回退时使用旧配置仅重建 API，不恢复整库。
- 发布快照全量 Go 测试、vet 和 Linux 构建通过；独立本机 PostgreSQL 运行了扫码及登录通知事务回归。App 消息/实时相关 15 项测试、静态检查通过。
- 线上 API healthy、重启数 0，公网 health/ready 200，真实二维码创建/状态可用，提前兑换与匿名确认被拒绝；通知实时触发器启用。其他容器未重建。未代用户执行真实账号登录，实际新登录后可在消息页查看通知；历史登录不补发。
- 已获本次服务端发布授权；未提交、未推送，Issue #32 保持开放。
