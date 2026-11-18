# 企业简历快照改造 · MySQL 8 隔离综合演练报告

- 演练日期：2026-11-10
- 仓库：Intelligent-Interviewer-System，分支 feature/eapp-core-services-zx
- 演练性质：验证为主，不修改生产 Java / 正式 SQL / Flutter / 六态；缺陷只报告并给最小修复方案
- 结论速览：场景 A–G 与 06 验证全部真实执行；**12 项 PASS、2 项 FAIL（DR-2、DR-3），无 P0**；DR-1 已在测试侧隔离。暂不具备无条件正式迁移条件，需先修复 DR-1/DR-2/DR-3 并在真实库 information_schema 复核。

---

## 一、演练目的

在与生产完全隔离的一次性环境中，用真实 MySQL 8（而非 H2/Mockito 替代）验证：
1. 迁移 SQL 01–05 能否在 MySQL 8 正确执行、首次迁移与旧版升级是否正常；
2. 历史回填是否准确，有无重复绑定、数据丢失、字段错位、时间伪造；
3. 8.5 多重集 SHA-256 能否准确识别结构化差异；
4. 历史 PDF 迁移、归档完整性与异常处理是否正确；
5. 06 回写是否安全、幂等、不越权；
6. 回滚能否安全归档恢复；
7. C-App 与 E-App 简历是否真正独立。

## 二、环境配置

| 项 | 真实值 |
|---|---|
| 数据库真实版本 | **MySQL 8.0.46**（容器内 `select version()`） |
| 镜像 | mysql:8.0（本地 1.1GB） |
| 容器编排 | Testcontainers 2.0.5（testcontainers / junit-jupiter / mysql） |
| 数据库/账号 | recruit_drill / drill（独立测试账号，非生产） |
| 端口 | 随机映射，无固定端口 |
| 存储 | 不挂载数据卷；PDF 用临时目录 + Fake 内存端口 |
| 生命周期 | withReuse(false)，JVM 退出由 Ryuk 自动销毁 |

隔离纪律：未连接生产/服务器/共享/Compose 业务库，未读取生产连接配置，未访问真实 S3/MinIO，未使用生产 AccessKey。结束后 `docker ps -q` 计数 0，`docker ps -a --filter ancestor=mysql:8.0` 无残留。

## 三、执行步骤

1. 执行前检查：git status / diff --check（exit 0），确认源表真实 DDL 缺失、分析表真实主键为复合三列；
2. 搭建 DrillEnv（共享容器 + 支持 DELIMITER 的脚本解析）、DrillBaseline（可重置基线）、DrillResults（结果收集）；
3. 真实容器跑场景 A/B/C/D/F/G 与 06；Fake 内存端口跑场景 E；
4. 回归：3 个 Mockito 单测 + 2 个 Testcontainers 并发 IT；
5. 汇总 CSV、证据与本报告，清理临时日志。

## 四、A–G 场景结果

| 场景 | 验证要点 | 结果 | 证据 |
|---|---|---|---|
| A 首次迁移 | 五表创建、分析表 6 新列、2 快照、gap=0、无重复、子表复制、历史时间保留、AI 来源识别、幂等 | **PASS** | entTables=5, snap=2, gap=0 |
| B 旧版升级 | 补列、time_source 收紧 NO、按真实时间 BACKFILL_REAL、幂等；严重缺列探针 | **PASS + FAIL** | 见 DR-2 |
| C 重复投递/AI | 唯一快照组绑定、多组不绑定、无组 unknown、MATCHED 不覆盖、幂等 | **PASS** | 4A app=1004; 4B NULL; 4C unknown |
| D 哈希校验 | NULL/空串、字段边界、大小写/空格/全半角/Unicode、长 TEXT、多重集双向、12 日期 | **PASS** | 边界全 0; 8.5.4 双向各 1; datePairs=12 |
| E PDF 迁移 | 8 可达分类、2 类不制造、异常全 MANUAL_REVIEW、14 列、公式防护 | **PASS** | classifications=8; 三态分离 |
| F 回滚 | 真实复合主键守卫；单列主键下 RENAME 归档、manual-only、恢复 | **FAIL + PASS** | 见 DR-3；hist=4,new=2 |
| G 独立性 | 源修改/删除后快照零变化、重复投递独立、跨企业拦截 | **PASS** | immutable after UPDATE/DELETE |
| 06 回写 | 默认注释、十六进制、守卫、幂等、隔离库回写 | **PASS** | 写后 1 行→重跑 0 行 |

## 五、SQL 实际执行结果

- 01 前置检查、02 结构迁移（业务 DDL 全封装存储过程，顶层 CALL 注释）、03 回填（DML）、04 只读核对、05 回滚（封装过程）均在真实容器执行。
- 04 应无输出检查项（含 3、4、5、6、6.5、7、7.5、8、8.5、9、10、10.5）在正确数据下无异常行，gap=0；UNVERIFIED/unknown 等合法待核实数据未被误判。
- 重 CALL、重跑 03 均幂等，不产生重复绑定或重复快照。

## 六、PDF 验证结果

- 14 列结构（source_path…detail）经反射确认组件数为 14，顺序与用户锁定清单一致；布尔 TRUE/FALSE。
- copy_verified 仅表示当前源/目标字节一致；archive_integrity 依赖迁移时独立固化的参考哈希，不用目标当前哈希自证；authenticity 默认 FALSE。
- 历史程序不制造 COPIED_AND_VERIFIED、LIVE_ORIGINAL_COMPLETE；404 与 403/超时/5xx 按错误码区分（404→缺失，其余→MANUAL_REVIEW）。
- CSV 公式注入防护：`=`、`@`、`+`、`-`、Tab、CR 前缀前置单引号。

## 七、独立性验证结果

- 数据层：C-App 源简历 UPDATE/DELETE 后，E-App 快照主表及技能/工作子表查询结果零变化，企业 PDF 引用与源引用分属不同命名空间。
- 重复投递生成独立 app_id/ers_id，uk_ers_app 生效，互不覆盖；跨企业查询计数 0。
- 读取入口（selectScreenableCandidates、selectSnapshotByApp、快照子表、硬过滤技能、AI 绑定）静态均指向快照表。
- 边界：Flutter UI 实际字段未在容器内实跑；两个列表入口的 Mapper/Service/Flutter 全链路结论见第九节遗留项。

## 八、单元测试与集成测试结果

| 测试 | 数量 | 结果 |
|---|---|---|
| HistoricalResumeMigrationConsoleTest | 8 | 全绿 |
| HistoricalResumePdfMigratorTest | 12 | 全绿 |
| PdfFileVerificationTest | 16 | 全绿 |
| ApplicationStatusConcurrencyIT（独立容器） | 6 | 全绿 |
| OfferServiceConcurrencyIT（独立容器） | 5 | 全绿 |

Mockito 单测 36 + 并发 IT 11，全部通过。并发 IT 仅在各自一次性 Testcontainer 内运行，未连外部库。
（注：OfferServiceConcurrencyIT 因 TalentPoolServiceImpl 新增 EntResumeSnapshotService 依赖，测试精简配置缺该 bean 导致上下文无法启动；已在测试配置补 Mockito bean，不触碰生产代码，详见 DR-4。）

## 九、发现的问题

### DR-1（P1，已测试侧隔离）
- 位置：01/02/05 共 10 处实际列引用（information_schema.statistics）。
- 复现：正式 SQL 直接在容器执行。
- 实际：`Unknown column 'subpart'`；预期：正常查询。
- 根因：MySQL 8 真实列名为 `SUB_PART`，脚本误用 `subpart`。
- 最小修复：10 处实际引用统一改为 `SUB_PART`（注释中的 2 处无害）。本轮用 DrillMigration 词边界替换生成修正副本，未覆盖正式文件。

### DR-2（P1，FAIL）
- 位置：02 p_ent_schema_migrate 快照主表补列段（约 378–414）。
- 复现：构造缺 ers_snapshot_at 的旧表，CALL p_ent_schema_migrate。
- 实际：`Unknown column 'ers_snapshot_at'`（UPDATE 先引用、未先 ADD）。
- 预期：缺列时自动补列、不报错。
- 根因：补列段只 ADD ers_version_verified、ers_time_source，漏 ADD ers_snapshot_at；诊断段却把它列为可能缺失列，口径不一致。
- 最小修复：在 UPDATE（约 396 行）前加 `IF NOT EXISTS ADD ers_snapshot_at datetime`。

### DR-3（P1，FAIL）
- 位置：05 p_ent_rollback 守卫2（约 70–80）。
- 复现：真实复合三列主键表上 CALL p_ent_rollback。
- 实际：中止，消息“原表主键不是单列主键”，RENAME 未发生。
- 预期：回滚可执行（或明确不支持并给替代路径）。
- 根因：守卫2要求单列主键，但真实表（new.sql:1311）为复合三列主键，且 02 未新增单列主键；前置假设与真实结构冲突。
- 最小修复（二选一，需评审）：① 回滚按复合主键口径重写定位与回填；② 先经评审新增单列主键迁移，再执行回滚。

### DR-4（P2，测试基础设施，已修复）
- 位置：OfferServiceConcurrencyIT.OfferTestConfig。
- 根因：企业快照改造给 TalentPoolServiceImpl 注入 EntResumeSnapshotService，精简测试配置未同步。
- 修复：测试配置补 `@Bean` 返回 Mockito mock；Offer 链路不触发 createForApplication，不影响断言。不涉及生产代码。

## 十、遗留风险与未验证项

1. **真实源表 DDL 缺失**：t_res_base 及四子表 CREATE TABLE 在仓库不存在。涉及真实字段类型/精度/日期的结论基于标注夹具，不能冒充真实；须在真实库 information_schema 复核（12 日期、DECIMAL、VARCHAR/TEXT、字符集排序）。
2. 真实分析表主键、源表日期精度待实际库确认；DR-3 即源于此结构差异。
3. Flutter UI 层字段未在容器内实跑：selectCandidatesByPosition（主代码无调用，遗留待清理）、selectResultsByPosition（mapper 仍读 t_res_skill，但 Service 硬过滤已用快照技能、Flutter 仅取 totalScore/六维）。当前判定非阻断；若实测页面展示当前简历字段则升级阻断。
4. DDL 隐式提交：回滚/迁移无法靠单一事务整体回退，须维护窗口、分阶段执行并保留全量备份。
5. 隔离通过 ≠ 生产通过；单测通过 ≠ 生产生效。

## 十一、是否达到正式迁移条件

- **数据库正式迁移：暂不具备无条件执行条件。** 核心功能逻辑（快照、回填、哈希、独立性）已在真实 MySQL 8.0.46 验证通过，但存在 3 个 P1（DR-1/2/3）必须先修复并复审，再于真实库 information_schema 核对结构后，由用户手动分阶段执行。
- **历史 PDF 迁移：程序逻辑与 14 列证据链已验证，具备在修复/确认 DR-1 后小范围试点的条件；** 真实性仍须人工证据，禁止自动升级 COMPLETE/MANUAL_VERIFIED。
- **C/E 独立性：数据层已验证成立**（修改/删除源不影响快照、跨企业隔离）；Flutter 展示层留待实机确认。
- 无 P0；P1 共 3 项均为可定位、可最小修复的兼容性问题，不改变整体设计。

## 十二、下一步（需用户手动）

1. 评审并修复 DR-1、DR-2、DR-3（按各最小修复方案，修改正式 SQL），修复后回归本演练确认全绿；
2. 在真实库只读 information_schema 核对源表/分析表结构与日期精度，确认与夹具假设一致；
3. 审核 06（默认注释），确认无误后由用户本人按手册分阶段手动执行，先备份、维护窗口；
4. 实机走查两个列表入口与 Flutter 页面，确认无当前简历字段泄漏；
5. 本轮不自动进入生产迁移、不连接服务器、不部署、不 commit/push，等待审核。

---

## 附：P1 离线修复进展（2026-11-10，静态修复，未复测）

> 本节为后续追加，不改变上一轮 12 PASS / 2 FAIL 的真实历史；未复测项一律不标 PASS。

| 缺陷 | 状态 | 离线处理 |
|---|---|---|
| DR-1 字段名 | **SQL 已修改，待复测** | 01/02/05 共 9 处真实列引用 subpart→SUB_PART（另 3 处注释同步），grep 无残留；校验语义/守卫/匹配范围未改 |
| DR-2 缺列 | **SQL 已修改，待复测** | 02 在 UPDATE 引用前新增 IF NOT EXISTS 补列（ers_snapshot_at datetime DEFAULT NULL），默认 NULL、无 NOW()/CURRENT_TIMESTAMP，幂等 |
| DR-3 主键 | **设计评审完成，方案待批准** | 已确认复合三列主键在 DB 层阻断追加式；推荐方案 B（asr_id 自增主键 + 三元组普通索引），待用户审核 SQL |
| 场景 H 多版本验收 | **NOT_RUN** | 新增 DrillScenarioHIT（重构前阻断 + 重构后 2 llm/1 manual 三版本共存），本轮禁容器未运行 |

- 新增待审核 SQL（仅生成不执行）：`DR3_主键只读核对.sql`、`DR3_主键重构_待审核.sql`（含诊断/冲突检测/正向/回滚/执行顺序/失败恢复）。
- 05 守卫2 保留不删，与方案 B 配套（重构后单列 asr_id 方可通过）；仅补充依赖注释，守卫逻辑不变。
- 离线检查：sql_static_check（9 文件 ALL PASS，exit 0）、top_level_ddl_check（0 裸 DDL，PASS）、field_diff_logic_test（16/16 PASS）、git diff --check（exit 0）。
- 待办：下一阶段单独授权后，在 MySQL 8 隔离环境复测 DR-1/DR-2 并执行场景 H；通过后再评估正式迁移。
