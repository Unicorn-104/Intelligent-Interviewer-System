# 企业简历快照 MySQL 8 隔离演练报告（第二轮：DR-3 / H 场景 / 05 完整回滚）

- 演练日期：2026-11-10
- 演练性质：一次性 Testcontainers 隔离容器，离线，未连接任何持久化数据库
- 数据库真实版本：MySQL 8.0.46（容器内 `SELECT VERSION()` 核实）
- 基础组件：Testcontainers 2.0.5、Docker 29.3.1 / Docker Desktop 4.67.0、JDK 17（Temurin 17.0.18）、Maven 3.9.11

## 一、授权范围与隔离边界

- 仅在本机一次性 MySQL 8 Testcontainers 容器内执行迁移 SQL、DDL、DML 与回滚 SQL。
- 未连接、未修改服务器数据库、远程开发库及其他本地持久化库。
- 未访问真实对象存储（E 场景使用 FakeSource/FakeTarget 纯算法验证）。
- 未修改正式业务代码以迁就测试；未部署、未提交、未推送。
- 容器 `withReuse(false)`、不挂载数据卷；Ryuk 0.14.0 负责 JVM 退出自动回收。

执行命令：
```
mvn -o -pl ruoyi-system -am test "-Dtest=Drill*IT" "-Dsurefire.failIfNoSpecifiedTests=false"
```

## 二、测试结果总览

**Tests run: 14, Failures: 0, Errors: 0, Skipped: 0 — BUILD SUCCESS（退出码 0，总耗时 42.4s）**

| 测试类 | 用例数 | 结果 |
|---|---|---|
| DrillSmokeIT | 1 | PASS |
| DrillScenarioABIT | 2 | PASS |
| DrillScenarioCDIT | 2 | PASS |
| DrillScenarioEFIT | 1 | PASS |
| DrillScenarioFIT | 2 | PASS |
| DrillScenarioGIT | 1 | PASS |
| DrillScenarioHIT | 4 | PASS |
| DrillZeroSixIT | 1 | PASS |
| 合计 | 14 | 全 PASS |

## 三、逐项结果

| 场景 | 测试方法 | 实际结果 | 状态 |
|---|---|---|---|
| Smoke | mysqlStartsAndReportsVersion8 | 版本 8.0.46 | PASS |
| A | scenarioA_firstMigration | 首次迁移全流程通过 | PASS |
| B | scenarioB_legacyUpgrade | 旧版幂等升级通过 | PASS |
| C | scenarioC_repeatedApplicationAndAiBinding | app_id/snapshot_id 绑定正确 | PASS |
| D | scenarioD_hashAndMultiset | 哈希与多重集无差异 | PASS |
| E | scenarioE_classificationAndEvidence | 五分类与证据分层正确 | PASS |
| F | f1_realCompositePkBlockedByGuard | 守卫2拦截、未 RENAME | PASS |
| F | f2_singlePkFullRollback | 归档4行/新表2行/manual-only不写入 | PASS |
| G | g_lifecycleIndependence | 快照生命周期独立 | PASS |
| H | h1_compositePkBlocksSecondInsert | Duplicate entry、仍1行 | PASS |
| H | h2_rebuildAllowsThreeVersions | group4/llm3/manual1 共存 | PASS |
| H | h3_preciseUpdateAndSourceIsolation | triple命中4/asr_id命中1 | PASS |
| H | h4_tieTimestampDeterministicOrdering | 稳定取 tieB | PASS |
| 06 | zeroSix_generatedSqlAndDbWriteback | 生成与回写通过 | PASS |

## 四、数据库结构核验报告（05 回滚后 vs 原始 DDL）

原始 DDL 基准：`e-app/new.sql` 1311–1320（6 列、复合三列主键、一个普通索引、无 asr_id）。
f2 在容器内真实执行 `CALL p_ent_rollback()` 后，通过 information_schema 断言核验：

| 核验项 | 原始 DDL | 回滚后实测（断言通过） | 结论 |
|---|---|---|---|
| 主键 | PRIMARY(company,position,candidate) | PRIMARY 恰三列，首列 asr_company_id | 一致 |
| asr_id | 不存在 | information_schema 0 命中 | 已删除 |
| 02 新增六列 | 不存在 | app_id/snapshot_id 等 0 命中 | 已删除 |
| 字段总数 | 6 | 过程 2.5 删6列、2.6 删 asr_id，恢复原始6列 | 一致 |
| 普通索引 | idx_aca_candidate_updated | distinct 索引名仅2个（PRIMARY+idx_aca） | 一致 |
| DR3 三元组索引 | 不存在 | 2.4-bis 已删，索引清单无残留 | 一致 |
| 归档表 | — | hist 表 4 行零删除，llm/manual 全保留 | 完整 |
| 新表记录 | 每组唯一 | 2 行（组70最新llm、组72），manual-only组71不写入 | 正确 |
| 重复三元组防护 | 主键物理唯一 | 2.7 窗口 rn=1 且 source='llm'，每组最多一条 | 有效 |
| 快照五表 | 保留 | t_ent_resume_% 计数 5 | 未删除 |

结论：回滚后表结构与原始 DDL 在列、主键、索引三个维度完全一致；全部多版本数据在归档表完整保留，无任何 DELETE。

## 五、首轮失败 — 定位 — 修复 — 复测记录

首次全套运行结果为 12 PASS / 2 ERROR，失败均集中在 DrillScenarioFIT，根因为测试类与重写后的 05 不同步（非正式 SQL 缺陷）：

1. f1 报错 `hist_20261109 doesn't exist`：05 新增第五部分顶层 SELECT，旧测试在"定义过程"阶段即执行这些语句，而此时尚未 RENAME。
   修复：rollbackProc() 改为仅截取存储过程定义（DROP PROCEDURE 至 DELIMITER ;），不含第一/五部分。
2. f2 报守卫5"DR3 三元组普通索引缺失"：测试手工构造的单列主键表未含 DR3 索引；且末尾仍断言已删除的 uk_asr_company_position_candidate。
   修复：手工表补 idx_asr_company_position_candidate 与 idx_aca_candidate_updated；断言改为核验复合主键恢复、asr_id 删除与索引集合。

修复后先单跑 DrillScenarioFIT（2 PASS），再复跑全套（14/14 PASS）。全程未降低断言、未修改正式迁移方案。

## 六、容器 / 网络 / 数据卷清理核验

测试结束后实测：
- `docker ps -a`：无本轮 Testcontainers 容器（mysql、ryuk 均已销毁）；仅余非本轮的停止态 local-redis，未触碰。
- `docker network ls`：仅默认 bridge/host/none，无 testcontainers 自定义网络。
- `docker volume ls`：空，无数据卷（本轮容器未挂载卷）。
- 镜像 mysql:8.0、testcontainers/ryuk:0.14.0 作为本地缓存保留（非运行资源，不属清理对象）。

## 七、结论与边界

- DR-1（SUB_PART 字段名）、DR-2（ers_snapshot_at 幂等补列）、DR-3（asr_id 主键重构与追加式）在真实 MySQL 8.0.46 隔离环境全部验证通过。
- H1–H4 证明：复合主键物理阻断追加（方案A不可行），重构后多版本共存、精确更新隔离、同时间戳排序稳定。
- 05 完整归档回滚后结构与原始 DDL 一致，归档数据零丢失。

边界（隔离通过 ≠ 生产通过）：
1. 本结论仅对一次性容器内的夹具数据与标注 DDL 有效，不代表生产环境行为。
2. 源表真实 DDL 仍缺失，真实字段类型/日期精度待生产 information_schema 确认。
3. 所有正式 SQL（含 DR3 主键结构变更）须经人工审核并由本人手动执行，本轮不自动进入生产迁移。

## 八、待人工确认事项

- 执行正式迁移前，先跑《字段类型只读核对.sql》第7段：若 ers_snapshot_at/ers_created_at 为 datetime(6) 或 timestamp，按 verdict 提示人工评估截断/时区风险。
- 无法核实来源的记录保持待核实，不伪造 PDF/Hash；不批量改写历史来源。
