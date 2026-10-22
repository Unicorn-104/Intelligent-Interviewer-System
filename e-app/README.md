# E-APP 企业招聘移动端

Flutter 企业端应用，复用仓库 `backend` 的若依登录、招聘总览、岗位管理、即时通讯、会议场次和个人资料接口。视觉令牌与交互规则参考 `c-app/DESIGN.md`。

## 运行

```powershell
flutter pub get
flutter run
```

APP 当前默认访问本机后端 `http://10.0.2.2:8080`（Android 模拟器访问宿主机），用于测试最新功能。本机后端通过私有数据源配置连接服务器数据库；APP 不保存数据库账号密码。

需要访问公网后端时，可通过编译参数覆盖：

```powershell
flutter run --dart-define=API_BASE_URL=http://114.55.175.79/prod-api
```

真机测试时，将接口地址覆盖为本机电脑的局域网地址与8080端口。

## 已接入接口

- `GET /captchaImage`、`POST /login`、`GET /getInfo`、`POST /logout`
- `GET /system/dashboard/overview`
- `GET/POST /system/enterprise/jobs/**`
- `GET/POST/PUT /system/im/**`
- `GET /system/conference/session/current`
- `GET /system/user/profile`

候选人列表通过企业岗位详情中的真实候选人数据聚合。当前后端尚未实现接口文档中的 `/api/v1/**` HR 专用路由，应用不使用静态业务数据替代。
