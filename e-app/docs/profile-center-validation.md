# 企业端 APP「我的」与 PC 个人中心对齐

## 本次范围

参考 `enterprise_pc/RuoYi-Vue3/src/views/enterprise/profile/index.vue`，将 APP「我的」完善为个人资料、偏好设置、通知设置三个分区，使用 AppColors、白底描边卡片、8px 卡片圆角和4px按钮圆角。不修改底部导航或后端、数据库、现有 api/ 函数签名。

## 真实接口与字段

- 个人资料：`GET /system/user/profile`，读取 `data` 用户信息及顶层 `roleGroup`、`postGroup`。显示姓名、登录账号、角色、岗位、部门、手机号、邮箱、性别、个人简介与服务端最近登录信息。缺失值显示空态，不将服务端最近登录记录误标为 APP 当前会话。
- 资料修改：`PUT /system/user/profile`，仅提交 `nickName`、`phonenumber`、`email`、`sex`、`remark`。部门和账号只读。取消不写入；保存失败保留表单，成功后重新读取资料。
- 密码修改：`PUT /system/user/profile/updatePwd`，JSON 体为 `oldPassword`、`newPassword`。新密码6–20字符、与旧密码不同、二次确认一致。服务端当前实现保留本会话并使其他会话失效；APP 不自行注销当前会话。不记录密码。
- 头像：`POST /system/user/profile/avatar`，multipart 字段为 `avatarfile`，从响应顶层 `imgUrl` 取回地址。沿用现有上传通道，不修改它的签名。头像支持 jpg/jpeg/png/gif/bmp/webp，验证扩展名、文件头及小于5MB的体积；读取时也限制大小。取消文件选择不上传，错误不假报成功。
- 企业设置与退出登录保留。退出需确认，确认后调用原企业壳回调。

## 本机设置与未实现能力

PC 的偏好和通知仅用 localStorage 存储，未发现相应服务端接口。APP 对应使用已有 FlutterSecureStorage，键为 `enterprise_profile_preferences_<userId>`，按账号区分并保留重启后的设置。

- 可保存偏好面试时长、日历同步偏好、通知频率偏好及面试提醒/简历入库/候选人消息/系统更新的接收偏好。
- 页面明确说明这些仅为本机偏好，日历同步、通知频率执行和手机推送策略仍在开发，不声称已经接入推送、调度规则或外部日历。
- 继续使用简体中文、UTC+08:00。其他语言与时区执行能力未接入，不提供无效切换。
- 微信绑定、双重验证、历史登录记录显示“功能开发中”。手机号、邮箱编辑为资料联系方式修改，不声称已验证绑定。
- 本机设置读取错误独立展示，不阻断个人资料；保存期间防重复操作和跨分区覆盖。

## 验证

`profile_data_source_test.dart` 使用 HTTP 适配器核对真实路径、方法、字段、multipart 和错误解包，测试账号间设置隔离、头像大小和格式限制。`profile_page_test.dart` 使用合成资料覆盖编辑、取消、保存失败、防重复、密码验证、头像选择、通知回读、退出确认及320dp与横屏键盘布局。

本地只读联调已确认个人资料接口 code=200，所需用户字段和角色/岗位分组存在；未对真实账号执行测试资料、密码或头像修改。自动测试不能替代登录 Pixel_10a 后对选图、密码修改、保存回读的人工验收。
