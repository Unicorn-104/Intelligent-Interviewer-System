# 阶段三子功能 2：JD 文档导入与核对发布验证

## 范围与环境

- 企业端入口：JobPublishPage，先解析、核对并应用，再编辑、预览和发布。
- Flutter 3.47.3 / Dart 3.13.3；项目 SDK 下限为 ^3.13.0。
- file_picker 锁定 13.1.0，使用 FilePicker.pickFile；取消返回 null。
- 本功能提交包含已批准的数据层、UI、测试与文档；真实验收期间不修改业务源码或 Android 配置。
- 原有未跟踪 backend/doc/backup/ 与 backend/doc/enterprise_job_publishing.md 保留，不纳入提交。

## 接口与字段

POST /enterprise/jd/parse-document；multipart/form-data，单文件字段名 file。
扩展名 PDF/DOCX（大小写兼容），大小上限 10 * 1024 * 1024 字节，拒绝空文件。
Bearer Token 复用企业端安全存储；发送超时60秒、接收超时180秒，不自动重试。
接口只返回 AjaxResult.data 草稿，不落库、不创建岗位。

| 字段 | 核对与回填 | 发布去向 |
| --- | --- | --- |
| title / dept / city | 可空文本；有值回填，缺失不清空已有输入 | 现有 createJob 对应字段 |
| salaryMin / salaryMax | 元/月；整组比较和替换，缺失端留空待补全 | 对应月薪字段，不转成 K |
| experience | 保留原始经验文本及自定义选项 | experience |
| education | 1中专/2大专/3本科/4硕士/5博士 | education |
| jobType | 1全职/2兼职/3实习 | jobType |
| responsibilities / requirements | 文本数组，逐行编辑 | 同名正文数组 |
| skills | name + required；1必备、0加分、null未注明 | skills，保留 null |
| summary | 用户主动选择“加入工作职责”后追加 | responsibilities，不单独保存 |
| softRequirements | 用户主动选择“加入任职要求”后追加 | requirements，不单独保存 |
| warnings | 空白、换行等原样展示，仅供人工核对 | 不作为发布正文提交 |

核对区提示“AI 结果仅供参考”“摘要和软性要求会追加到正文，不会单独保存”。
应用草稿时读取最新表单：空字段填入、相同值跳过、不同已有值展示前后差异并二次确认。
取消选择、解析失败、取消覆盖都保留原输入。离开确认后取消请求并忽略迟到结果。

## 自动化测试清单

- jd_document_picker_test.dart：取消、两格式及大小写、旧 .doc、空文件、10MB边界、超限、未知大小流、读取失败、读取长度不符。
- jd_document_api_test.dart：AjaxResult.data 解包、非法结构、字段错误和业务失败。
- enterprise_upload_file_test.dart：实际 multipart 编码、file 字段、文件名、MIME、Token、超时、HTTP和业务错误、取消以及普通JSON请求配置隔离。
- jd_import_draft_test.dart：类型、枚举、薪资成组、空字段保留、required=null、警告原文、最新输入差异、正文追加和长度上限。
- job_publish_jd_import_test.dart：导入不发布、确认后编辑发布一次、覆盖取消、解析期间编辑、重复点击、请求取消与迟到响应、正文追加、窄屏横屏。
- test/support/：合成文件和HTTP适配器，不连接真实网络、数据库或存储真实个人数据。

命令均在 e-app/ 执行：

~~~powershell
flutter analyze --no-pub
flutter test
flutter build apk --debug
~~~

最终自动化结果：

- flutter analyze --no-pub：No issues found。
- flutter test：224 项全部通过。最初3项交互测试因懒加载目标定位失败，已仅调整 tapJdKey 先滚动定位再断言；业务断言保持不变，随后全量通过。
- Debug APK：成功。第一次原生插件构建遇到 C盘 Pub Cache 与 D盘项目的 Kotlin 增量缓存跨根路径错误；flutter clean 后，仅对构建进程临时设置 GRADLE_OPTS，成功构建，assembleDebug 约73.7秒。
- 临时参数为 -Dorg.gradle.project.kotlin.incremental=false -Dkotlin.incremental=false，进程结束后恢复环境变量；未修改 Android 配置或 PUB_CACHE。
- 已逐一比较9个 Android 配置文件，构建前后完全一致。
- APK 路径：build/app/outputs/flutter-apk/app-debug.apk，已安装到 Pixel_10a。

成功构建的临时配置方式（在 e-app/ 执行）：

~~~powershell
$previousGradleOpts = [Environment]::GetEnvironmentVariable('GRADLE_OPTS', 'Process')
try {
  [Environment]::SetEnvironmentVariable('GRADLE_OPTS', '-Dorg.gradle.project.kotlin.incremental=false -Dkotlin.incremental=false', 'Process')
  flutter build apk --debug
} finally {
  [Environment]::SetEnvironmentVariable('GRADLE_OPTS', $previousGradleOpts, 'Process')
}
~~~

## Pixel_10a 受控集成

~~~powershell
flutter test integration_test/stage_three_jd_import_test.dart -d emulator-5554
~~~

脚本复用生产页面，通过注入选择器、解析器和内存提交函数验收。
覆盖PDF/DOCX两条流程、核对与正文追加、编辑后单次内存发布、取消/空文件/超限、解析中编辑、防重复、覆盖取消、退出取消与迟到响应。
集成中的文件提供器为内存合成对象；输入通过公开 controller 注入，避免把原生输入法行为混入受控验证。
这不替代原生文件选择、真实HTTP或真实数据库写入验收。

设备受控脚本尚未执行；脚本已经静态分析，但不能标记为设备运行通过。正式 APK 的真实 DOCX 流程按下节单独记录。

## 正式 APK 与真实后端人工验收

2026-10-16，用户确认后端已重新启动并在 Pixel_10a 登录 admin 后，完成本轮真实 DOCX 验收。
本轮操作前持续检查内存：MemTotal=4006168kB、dalvik.vm.heapsize=576m，可用内存约2.0–2.2GiB；应用 PID=13258 始终未变。

| 步骤 | 实际操作与结果 | 结果 |
| --- | --- | --- |
| 发布入口 | 岗位→发布岗位；企业信息正常加载，导入卡片 AI 标识为紫色，显示文件限制与“AI 结果仅供参考” | 通过 |
| 原生 DOCX 选择与解析 | 系统 Downloads 选择 jd-import-acceptance.docx（1,164,318字节）；真实接口返回草稿，界面从处理中进入“正在解析”，随后出现核对面板 | 通过 |
| 识别字段 | 岗位名称、测试研发部、18000–28000元/月、3-5年、本科、全职符合文档；原文没有城市，核对面板明确显示缺失 | 通过 |
| 原始警告 | 展示未提及城市、Git级别未注明、必填信息核对、DOCX无页数元数据等后端原文警告 | 通过 |
| 覆盖取消 | 解析前输入 MANUAL_KEEP_20261016_1107；应用时弹出当前值与导入值差异；点击“保留原内容”并关闭面板，确认原输入仍在 | 通过 |
| 正文追加 | 重新核对，主动点“加入工作职责”“加入任职要求”，再确认覆盖；摘要追加至职责末尾，两条软性要求追加至要求正文 | 通过 |
| 技能编辑 | 原始 Git required=null 在核对区、表单及编辑器中均显示“未注明”；手动改为“加分”保存，预览显示 Git·加分 | 通过 |
| 编辑与预览 | 标题编辑为 JD_IMPORT_TEST_20261016_1107；预览显示正确标题、月薪、追加正文及技能标识，尚未执行发布 | 通过 |
| 发布与刷新 | 只点击一次“确认发布”；返回岗位列表，提示“岗位发布成功，已更新岗位列表”，新岗位出现在列表顶部，状态“在招”，显示“查看岗位”入口 | 通过 |
| 测试数据下线 | 仅对该测试岗位点击“下线”，确认框核对唯一标题后提交；切换“已下线”筛选重新请求，仍显示该岗位“已下线”，按钮为“上线” | 通过 |

追加后的工作职责为：实现岗位文档解析接口、编写自动化测试、负责企业招聘系统文档解析与岗位发布。
追加后的任职要求为：具有Java和Spring Boot项目经验、良好的团队协作能力、清晰的书面沟通能力。
文档缺失的城市没有清空已有企业城市杭州。原始 Git 未注明标识经用户明确编辑为加分，发布预览为 required=0；required=null 的直接提交保留另由单元和Widget测试覆盖。

测试数据唯一标题：JD_IMPORT_TEST_20261016_1107。
通过现有状态接口设置为0（下线），再由服务端“已下线”筛选列表回查确认；未物理删除，未改动既有岗位和预约。
本轮未直接查询数据库，也不猜测客户端界面未展示的岗位数值ID。

证据位于忽略的 build/jd-import-final-acceptance/，不纳入提交：

- manual-input-before-parse.png、docx-upload-observed.png、docx-parse-result.png。
- overwrite-confirmation.png、manual-input-preserved.png。
- soft-requirements-and-warnings.png、appended-body-confirmed.png。
- git-skill-editor.png、final-preview-skills.png。
- published-list-refresh.png、offline-test-job-confirmation.png、offline-server-filter-verified.png。
- memory-checks.txt 记录每次界面操作前的内存和进程检查。

## 验收边界与先前中断

- 本轮通过的是用户指定的真实 DOCX 完整流程，不将其他未执行项目标记通过。
- 本轮没有重新执行 PDF 原生真实解析、原生空文件/超限选择或物理窄屏横屏；对应逻辑和布局已有单元/Widget测试，不能代替原生验收。
- 本轮未单独截获上传过程的中间字节数变化；真实字节进度回调有上传单元测试覆盖，设备截图记录到的是上传后的“正在解析”，没有伪造百分比。
- 先前一次文件选择期间进程被回收：ApplicationExitInfo 明确记录 LOW_MEMORY，后续一次诊断重现成功。该失败不计作通过。
- 先前一次发布选项连接超时：用户确认当时后端进程已停止；服务重启后本轮入口与解析正常。该超时记录不计作通过。
- 发布表单与选择结果在进程被回收后的恢复能力尚未实现，按用户要求留到后续独立健壮性提交，不混入本功能提交。

## 限制与回滚

- 客户端取消只停止等待/接收结果，不保证已开始的服务端LLM工作被终止。
- 解析结果不是发布结果；summary、softRequirements没有独立保存字段，须主动追加正文。
- 未执行的设备/真实接口项目保持“待验收”，不以单元测试替代。
- 最终提交前核对本功能路径；现有根忽略规则会隐藏 e-app 部分源码，需精确强制暂存，禁止全仓暂存。
- 本轮 DOCX 验收通过后，按授权创建独立提交 feat(enterprise): 支持导入 JD 文档并核对发布；不推送。
- 功能回滚可回滚最终功能提交，删除新增导入入口并恢复依赖及锁文件；后端和数据库没有本功能迁移。
- 本次合成岗位已通过唯一标题核对后下线保留；后续清理仍需人工确认，不按标题模糊批量删除。
