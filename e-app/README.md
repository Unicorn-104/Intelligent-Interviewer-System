# E-APP 企业招聘移动端

Flutter 企业端应用，复用仓库 `backend` 的若依登录、招聘总览、岗位管理、即时通讯、会议场次和个人资料接口。视觉令牌与交互规则参考 `c-app/DESIGN.md`。

## 运行

```powershell
flutter pub get
flutter run
```

APP 默认访问服务器后端 `http://114.55.175.79/prod-api`，由后端连接服务器数据库。普通运行、构建和重启均使用该地址，无需额外参数；APP 不保存数据库账号密码。

连接本机开发后端时，可通过编译参数覆盖（Android 模拟器示例）：

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## 已接入接口

- `GET /captchaImage`、`POST /login`、`GET /getInfo`、`POST /logout`
- `GET /system/dashboard/overview`
- `GET/POST /system/enterprise/jobs/**`
- `GET/POST/PUT /system/im/**`
- `GET /system/conference/session/current`
- `GET /system/user/profile`

候选人列表通过企业岗位详情中的真实候选人数据聚合。当前后端尚未实现接口文档中的 `/api/v1/**` HR 专用路由，应用不使用静态业务数据替代。
