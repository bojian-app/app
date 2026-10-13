账号设备管理，2026-10-09

- `GET /api/v1/me/sessions`：返回当前账号未撤销且未过期的会话，当前会话优先。字段为 `id`、`device_id`、`platform`、`app_version`、`logged_in_at`、`is_current`。
- `DELETE /api/v1/me/sessions/{id}`：仅允许撤销当前账号的目标会话；其他账号、已退出或不存在的会话返回 404。返回 `revoked` 和 `is_current`。
- 申诉沿用 `POST /api/v1/appeals`，`subject_type=USER`、`subject_id=当前用户 ID`；账号注销沿用现有接口。

后端补丁：`account-sessions.patch`，已同步至 bojian-backend。线上镜像 `bojian-api:account-sessions-20261009-r1`。以线上 comment-reactions 版本源码构建；重建基线 SHA-256 与运行版本一致。

验证：Flutter 设置页 6 项测试通过；独立 PostgreSQL 容器执行 `TestAccountSessionIsolation`，覆盖会话归属、过期/撤销过滤、目标设备退出、当前设备退出、重复请求。未操作真实账号会话。发布脚本检查镜像与程序校验值，失败回滚。
