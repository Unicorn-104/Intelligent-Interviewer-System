# HR 聊天头像与附件

## 功能与接口

聊天使用 HR 会话头像；本人先显示登录态头像，再通过 `GET /app/profile` 刷新。复用最新 dev 的公共资源地址校验与网关前缀处理，失败显示姓名首个字符。

图片、文件或拍照均在预览确认后上传。图片允许 JPG/JPEG/PNG/GIF/BMP 并校验文件头；文件允许 PDF、Office、TXT、ZIP；单个 10MB，文件名最多 180 字符。上传失败保留草稿及重试；发送结果不明时提示刷新核对，不自动重发。取消选择和确认不发送。

| 接口 | 用途 |
| --- | --- |
| `GET /system/im/sessions/{id}/messages` | 读取含附件的历史，兼容 isMine/sendTime 与旧字段 |
| `POST /common/upload` | multipart file 上传 |
| `POST /system/im/messages` | type=2 图片、type=3 文件，带 attachmentUrl |
| `POST /app/messages/hr/{id}/chat` | 既有文本发送 |
| `PUT /system/im/sessions/{id}/receipts` | 既有已读回执 |

图片仅显示圆角原比例缩略图（最大 210×280），点击放大；无额外气泡、文件名和时间已读。文件可下载后通过系统保存对话框保存。原岗位、面试邀请、改期卡片继续使用。

## 安全、验收与回滚

附件沿用现有公开 `/profile/` 协议，不具备按会话参与者授权读取保证。只接受当前 API 同源附件，拒绝外站、路径穿越、查询与片段；下载不带 Token、不跟随跳转，检查大小和完整性。RustFS 凭据保留后端，不增加数据库表。

本分支测试结果见 PR。需人工验证 HR/E-App 图片及文件双向发送、头像加载、保存对话框与取消、相机/相册拒绝、弱网恢复、Android 真机与 iOS。历史模拟器运行不作为本次服务器验收。

回滚客户端对应提交；不删除已有聊天或文件。本次没有新增孤儿文件清理协议。
