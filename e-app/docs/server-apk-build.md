# 企业端服务器安装测试包

构建目标：Android Release APK，后端地址通过编译参数指定，默认模拟器开发地址不变。

本次目标：`https://114.55.175.79/prod-api`。

## 私有 CA

根目录的PFX为服务器TLS证书容器，含私钥，受.gitignore保护。仅从中导出公开根CA到assets/certificates/baota_root.pem，PFX、口令和私钥不放入assets、源码或安装包。导出的证书链及服务器IP SAN已验证，App同路径Dart网络代码严格校验访问公开验证码HTTP200、业务200。

显式启用TRUST_BAOTA_CERTIFICATE后，在runApp前加载公开CA并安装BackendHttpOverrides。私有CA信任限定于API配置中的HTTPS主机（含同主机的TLS/WSS任意端口，覆盖LiveKit入会地址，如 wss://同主机:8444/livekit）；其他主机或明文HTTP/WS继续走系统默认信任，不改系统证书库。仍校验证书链、有效期与主机身份，不允许接受所有证书回调。私有CA请求不自动跟随重定向，避免扩大信任边界。

## 构建

```powershell
flutter build apk --release --no-pub --build-number=3 `
  --dart-define=API_BASE_URL=https://114.55.175.79/prod-api `
  --dart-define=CANDIDATE_APP_URL=https://114.55.175.79/user `
  --dart-define=TRUST_BAOTA_CERTIFICATE=true
```

原始输出：build/app/outputs/flutter-apk/app-release.apk。

> **CANDIDATE_APP_URL 说明**：求职者通过手机浏览器打开此地址下的 `/conference-join?token=xxx` 入会。
> 必须是 HTTPS 公网地址（手机浏览器 getUserMedia 要求安全上下文），不能用 localhost 或 HTTP IP。
> 构建后应在 APK 内确认该值不再是默认的 `http://localhost:5180`。

现有android/app/build.gradle.kts的release使用debug签名。本包供安装联调测试，并非应用商店发布包。用户提供的服务器TLS证书不用于Android应用签名。正式分发需配置独立且受保护的应用签名密钥。

构建号仅用命令参数覆盖，不修改pubspec中的应用版本。普通开发构建不传TRUST_BAOTA_CERTIFICATE，仍使用原系统信任和默认模拟器地址。

## 验证边界

相关私有CA边界、上传、SSE与消息客户端定向27项测试、格式和静态检查；APK中只包含公开CA，检查不含PFX或私钥资源。已在Pixel_10a保留数据安装并冷启动，未捕获TLS或启动异常；公网验证码接口HTTP200、业务200，当前captchaEnabled=false，因此不显示图形验证码框。没有代用户登录、投递或发送消息。不等同全部远端接口和业务流程验收，也不修改远端服务或数据库。

## 2026-10-27 构建记录

当前Flutter SDK的Release插件注册出现integration_test开发插件残留。构建阶段临时排除该开发插件、离线解析后完成Release构建，完成后恢复原pubspec开发依赖及锁文件并重新离线解析；没有永久删除测试依赖。

APK版本1.0.0，versionCode=2，minSdk=24，targetSdk=36；包含arm64-v8a、armeabi-v7a、x86_64。包大小62,175,581字节（约59.3MiB），v2签名验证通过，签名为项目现有Android Debug证书。交付路径：build/deliverables/e-app-1.0.0+2-server-114.55.175.79.apk。

SHA-256：97F5D8A8B92C062914DCD3F99D174B433659A115094256ED810445C351F96508。

## 2026-10-30 构建记录（修复邀请链接 localhost:5180）

本次补传 `--dart-define=CANDIDATE_APP_URL=https://114.55.175.79/user`，修复 E-App 发起面试时求职者收到的链接指向 `http://localhost:5180/conference-join` 的问题。

构建时同样临时注释 `integration_test` dev 依赖以规避 GeneratedPluginRegistrant 残留，构建后已恢复 pubspec.yaml。

APK版本1.0.0，versionCode=3，包大小97.7MB。交付路径：build/deliverables/e-app-1.0.0+3-server-114.55.175.79.apk。

SHA-256：0F11E5475970F89150586172B87FCBB8E32B815074ECE055415BCD9E8714FD00。

已验证 libapp.so 内含 `https://114.55.175.79/user`，不含 `http://localhost:5180`。求职者 Web 入口 `https://114.55.175.79/user/conference-join` 公网 HTTPS 可达（200）。

APK资源公钥CA与导出根CA一致，未包含PFX/P12/JKS/keystore文件，三个架构libapp.so均确认含目标API地址。27项相关定向测试、修改文件静态与格式检查通过；不等同真实账号及所有远端业务接口验收。
