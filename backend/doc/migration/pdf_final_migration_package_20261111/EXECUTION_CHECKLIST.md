# 历史 PDF 迁移人工执行清单（最终门禁修复版）

> 每个阶段必须满足前置条件才可进入；任一停止条件命中即暂停并人工排查，不得跳过。所有脚本默认 Dry Run；证据须由真实探测产生；SQL 文件均不含自动 COMMIT。

## A. 执行前检查

- 执行主体：人工
- 前置：已审核本执行包全部文件
- 操作：确认 SSH 隧道 127.0.0.1:19000 可用；确认 AWS CLI 已安装；凭据以环境变量注入，不写入任何文件
- 预期：隧道连通、aws 可用、无密钥落盘
- 停止条件：隧道不通或凭据需写入文件

## B. 源对象核验

- 执行主体：人工（依据已生成 Dry Run 结果复核）
- 操作：核对 source_pdf_dry_run_result.csv 中 70/71/78 的大小与 SHA；manual_review 为 0 条
- 预期：309407 与 163683 大小匹配、哈希存在
- 停止条件：源哈希缺失或大小不符

## C. 条件写能力探测（正式复制前置）

- 执行主体：人工
- 前置：A、B 通过
- 操作：先运行 `test_conditional_write.ps1`（默认 Dry Run）核对；再运行 `test_conditional_write.ps1 -Execute -RustfsVersion "<人工核实版本>"`，对 `conditional-write-probe/` 前缀非生产对象实测
- 预期：firstPutStatus=HTTP_200_OK，secondPutStatus=HTTP_412_PRECONDITION_FAILED，双 SHA 一致，生成 result=VERIFIED 证据；版本保持 MANUAL_VERIFICATION
- 停止条件：返回 409（不算成功）、403/5xx/网络错误、双 SHA 不一致、版本未经人工核实；保持阻断，禁止进入 D

## D. 目标对象复制

> **companyId 修正（最高优先级）**：真实数据库核实三条 `ers_company_id` 与 `pos_company_id` 均为 1，目标 key 已修正为 `enterprise-application-resume/1/{appId}/{UUID}.pdf`。旧 151/152 路径下三个已复制对象保留不删不覆盖；新 /1/ 目标与原批准目标不同，**须重新明确批准后才可执行复制**，未批准前本阶段保持阻断。

- 执行主体：人工
- 前置：C 已通过，且已对新 /1/ 目标重新明确批准
- 操作：先运行 `copy_objects.ps1 -ReportPath "<新报告名>"`（默认 Dry Run）核对；再运行 `copy_objects.ps1 -Execute -ConditionalWriteVerified -ReportPath "<新报告名>"`
- 预期：仅 70/71/78 被原子条件创建到 /1/ 路径；HEAD 遇 403/5xx/网络错误即停止；目标已存在校验一致则幂等跳过
- 停止条件：出现其他 appId、报错、目标已存在但校验不一致、未确认能力即执行、未对新目标重新批准

## E. 目标对象完整性验证

- 执行主体：人工
- 前置：D 完成
- 操作：运行 `verify_target_objects.ps1`
- 预期：三条结果均为 PASS（真实 SHA-256 与大小和源一致，不用 ETag），生成报告
- 停止条件：任一 GET_OBJECT_FAILED/SIZE_MISMATCH/SHA_MISMATCH；脚本阻断回写

## F. SQL 审核

- 执行主体：人工
- 前置：E 全 PASS
- 操作：审核 database_update.sql，确认仅更新 ers_file_path、ers_file_size，含双字段 NULL 守卫与 ROW_COUNT，且不含自动 COMMIT
- 预期：范围、守卫、人工提交流程符合预期
- 停止条件：涉及其他字段、缺少守卫、存在自动 COMMIT

## G. 人工批准

- 执行主体：人工（授权人）
- 操作：基于 B、C、E、F 证据正式批准数据库回写并留档
- 预期：明确批准记录
- 停止条件：未获显式批准不得进入 H

## H. 数据库回写

- 执行主体：人工
- 前置：G 已批准
- 操作：事务内执行 database_update.sql：预览确认 path/size 均 NULL、唯一性检查、逐条 UPDATE、每条 ROW_COUNT 应为 1、验收 SELECT；最后由人工单独执行 COMMIT
- 预期：3 行更新，其余 7 条不变，身份字段未改
- 停止条件：ROW_COUNT 不为 1 或前置不符，立即 ROLLBACK

## I. 业务接口验证与最终验收

- 执行主体：人工
- 操作：验证 70/71/78 PDF 可下载；空路径/缺失有明确提示且结构化简历仍可读；越权被拒；确认六态、AI、评分、人才库不受影响并归档
- 预期：下载成功、隔离鉴权有效、不回退 C-App、关联功能正常
- 停止条件：接口报错、回退 C-App、越权可访问、关联功能异常

## 回滚确认（如需要）

- 执行主体：人工
- 操作：执行 rollback.sql，仅当新路径与本次大小双前置满足才还原 NULL，逐条核对 ROW_COUNT，人工 COMMIT
- 停止条件：路径或大小已变化则停止，不覆盖其他合法更新
