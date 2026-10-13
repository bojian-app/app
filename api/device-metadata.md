# 登录设备型号

2026-10-09：Android 通过系统 Build.MANUFACTURER / Build.MODEL / VERSION.RELEASE 获取真实硬件型号与系统版本；iOS 通过 UIDevice 和 uname 获取设备类型、硬件标识与系统版本。

客户端请求携带可选的 `X-Device-Model` / `X-OS-Version`，值使用 URI component 编码。身份仍使用原有设备 ID，型号仅用于展示。服务端解码后拒绝控制字符、无效编码及超长值。

迁移 037 给 user_sessions 增加 device_model 与 os_version。登录写入、令牌刷新更新；设备列表请求补齐当前登录设备信息，必须同时匹配登录用户、session、设备 ID 和平台。旧客户端不携带新头时保留已有型号。

历史设备没有上报过型号时继续显示平台信息，不根据其他设备猜测型号。当前手机在打开账号安全时会补齐型号，其他设备需要更新客户端才能上报。

发布包基于 `/tmp/bojian-realtime-source` 的实时通讯 r2 生产基线，仅增加 device-metadata.patch。生产镜像为 `bojian-api:device-metadata-20261009-r1`。部署脚本核对原镜像与二进制，失败时回滚 compose 镜像。新增列可与旧版本共存。

验证：175 项 Flutter 测试通过、flutter analyze 无问题。Go HTTP API 测试通过。独立 PostgreSQL 数据库验证设备列表隔离、型号持久化、错误设备身份无法覆盖当前设备、非法请求头处理。Android release 构建成功；iOS 桥接未在 iOS 真机验证。
