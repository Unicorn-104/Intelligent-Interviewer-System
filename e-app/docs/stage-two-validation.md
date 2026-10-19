# 企业端阶段二验证记录

日期：2026-10-15。分支：`feature/eapp-core-services-zx`。

## 实现范围

- 首页专用 `home_api.dart`：`getOverview`、`getCurrentUserInfo`、`getNoticeUnreadCount`，三个名字新增前均未被占用。
- 三个函数统一复用 EnterpriseApiClient；原有 13 个 API 文件及旧概览、用户资料、Repository 调用保持原样。
- HomeDataSource 只调用 API 函数，负责聚合、字段映射、时间与状态过滤，不直接发送 HTTP 请求。
- 企业名来自岗位发布选项 company.name，用户昵称来自 getInfo。
- 公告未读数来自 GET /system/notice/unreadCount 的 data，null 返回 0。
- 三张本地渐变卡片：PageView、5 秒自动切换、圆点指示器；隐藏或后台暂停。
- 近期面试调用已有 listInterviews，传 from 下界，保留未来待确认/已确认预约并升序排序，首页默认三条。
- 岗位投递概览使用 applicantCount 累计口径，保持岗位发布时间排序，不展示伪造的新投递人数或投递时间。
- 两个“更多”均进入独立列表页，支持分页与重试。
- 快捷统计使用 overview.stats，缺失待终审显示 —，真实零值显示 0。
- JobDetailPage.initialTab 默认 0，首页岗位入口传 1；原调用方不改。

## 测试修正与全量扫描

- 轮播标签和原数量断言不变；手动切换后 pumpAndSettle 等待动画完成。
- 显式 SemanticsHandle 放入 try/finally，在测试结束前 dispose。
- 首页三条、独立面试列表四条及累计投递列表断言限定各自页面子树；跳转/返回等待动画稳定。
- 已搜索 test/ 下导航、固定帧等待、跨页面查找和显式语义句柄。其他导航测试已有等待步骤；未找到第二处显式 SemanticsHandle。
- 本轮仅修测试，lib/ 下全部业务源码与修正测试前的快照一致。

## 本轮顺序验证结果

| 检查 | 结果 |
| --- | --- |
| flutter analyze --no-pub | 通过，No issues found，退出码 0 |
| flutter test | 全部 82 项通过，退出码 0 |
| flutter build apk --debug | 通过，26.7 秒，退出码 0 |
| Pixel_10a 安装 | adb install -r 成功，保留应用数据 |
| 正式入口启动 | 用户完成真实登录，首页真实数据已验收 |
| 真实首页设备验收 | 通过，统计节点与截图逐项一致 |
| 受控 API 的设备验收 | 8 个用例通过，另含测试框架 tearDownAll 完成事件 |

APK：`build/app/outputs/flutter-apk/app-debug.apk`。
大小：199,140,822 字节。
SHA-256：`2ee82e33ae4022630772c2c07297cd2f85b87ba776ccf67937d3ae91b5b43dbb`。

## 已覆盖的自动化行为

数据聚合、开始时间下界、取消/完成过滤、跨页补足与排序、重复分页保护、累计投递口径、缺失字段与真实零值、独立区块错误与重试、空态/骨架、五秒轮播/暂停恢复/指示器、独立列表跳转、详情默认 Tab 兼容性。
首页 Widget 布局覆盖 320×640、900×420、420×900 及模拟安全区；全量测试同时保留现有页面渲染回归。
这些自动化检查不替代真实服务和设备验收。

## Pixel_10a 真实后端验收

用户在 Pixel_10a 完成真实登录后，Agent 使用正式 APK 核验，未修改真实业务数据：

- 轮播自动观察页码序列为 2、2、3、3；手动滑动与圆点点击通过。
- 当前无未来面试，首页和独立列表均显示“暂无即将进行的面试”；不是用测试数据伪装真实数据。
- 近期面试“更多”进入独立页面，返回正常。
- 岗位投递显示累计口径，“更多”进入独立列表，点击岗位后“投递候选人”Tab 被选中。
- 四项统计在合并的无障碍节点中逐项读取：在招岗位 2、待面试 2、待终审 —、本周完成 0；与同一时刻设备截图一致。
- 原统计脚本误把合并节点当成四个独立节点，已按多行文本逐项匹配；没有修改业务代码、预期值或截图。
- 铃铛进入真实公告页并可返回；非零徽标和标记已读后的精确刷新通过下述受控服务补验。

## Pixel_10a 受控接口验收

测试入口：`integration_test/stage_two_home_test.dart`。
它通过 `--dart-define=API_BASE_URL=http://10.0.2.2:18990` 连接本机合成服务，实际走原 API 函数、Dio、EnterpriseApiClient 和页面加载流程。
合成服务不连接真实后端、不记录 Authorization、不读取或输出账号及令牌。
测试界面标注“受控验收”，不把合成数据验收描述成真实业务数据。

| 场景 | 设备验证结果 |
| --- | --- |
| 4 条面试、5 条岗位 | 首页两类均只显示 3 条；“更多”进入独立列表，面试完整显示 4 条 |
| 轮播 | 自动五秒切换、手动滑动、三圆点选中通过 |
| 公告未读与返回刷新 | 首页徽标 4，公告页标记 4 条已读后返回；未读接口累计调用 2 次，徽标消失 |
| 未读边界 | 100 显示 99+；null 返回 0 并隐藏徽标 |
| 加载态 | 接口延迟 1.2 秒，页面实际展示骨架 |
| 空态 | 面试、累计投递、统计均显示各自空态；0 未读隐藏徽标 |
| 企业信息失败 | HTTP 403 后显示失败/重试；恢复接口后重试成功，其他区块保留 |
| 未读数失败 | HTTP 500 后显示失败/重试；重试成功，其他区块保留 |
| 面试失败 | 模拟超时错误响应后重试成功，其他区块保留；本项验证超时错误展示，不冒充真实传输超时 |
| 投递失败 | HTTP 500 后重试成功，其他区块保留 |
| 统计失败 | HTTP 500 后重试成功，其他区块保留 |
| 请求次数 | 五个失败区块各自接口均恰好请求 2 次（失败一次、重试一次） |
| 物理窄屏 | 840×1680，逻辑 320×640，区块可滚动，无溢出 |
| 物理横屏 | 2424×1080，逻辑约 923×411，无溢出，横向安全区与 20px 内容边距通过坐标断言 |
| 标准竖屏 | 1080×2424，逻辑约 411×923，无溢出 |

首次加载态脚本存在并发 pumpWidget/pump 冲突，已修正 await 顺序后完整重跑通过；未放宽业务数据或请求次数断言。
设备验收未发现需要修改的真实业务问题。

## 重现设备验收

在不同终端分别启动两个仅监听本机的辅助服务，再运行：

```powershell
python test_driver/device_capture.py
python test_driver/stage_two_api_server.py
flutter drive --driver=test_driver/stage_one_driver.dart --target=integration_test/stage_two_home_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:18990
```

截图保存在 build/stage-one-device/screenshots/stage2_*；真实数据截图和结构化结果在 build/stage-two-diagnostics/。
所有截图、日志、测试构建和本机配置不提交。
验收后已恢复原始分辨率、竖屏与正式入口 APK，交付 APK 仍使用原真实后端配置；临时 baseUrl 不进入源码或交付 APK。

## 提交门禁

真实后端与受控接口设备验收均通过。提交前已重新执行 `flutter analyze --no-pub`（No issues found）和 `flutter test`（82 项全部通过），并检查确切文件清单，只提交阶段二。
Backend、原有 13 个 API、screens、mock、旧概览/Repository、pubspec.yaml/lock 均保持阶段二开始时内容。
仅创建本地提交 `feat(enterprise): 首页轮播与待办聚合`；不推送。
