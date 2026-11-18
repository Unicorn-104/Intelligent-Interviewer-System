-- =====================================================
-- 数据库回写 SQL（最终安全收尾版，仅生成，不执行）
-- 范围：仅 appId 70、71、78 三条
-- 仅更新：ers_file_path、ers_file_size
-- 不更新：ers_file_name、ers_content_hash、ers_snapshot_status、ers_version_verified、
--        ers_time_source、ers_snapshot_at，以及 AI 分析、评分、人才库、六态状态机任何字段
-- 定位：ers_app_id 有唯一约束 uk_ers_app（天然唯一），并以 ers_company_id 辅助校验
-- 连接要求：使用独立的专用数据库连接/会话执行本脚本，避免 START TRANSACTION 影响其他未提交事务
-- 执行方式：必须逐条手动执行，每条 UPDATE 后立即查看 ROW_COUNT；禁止一次性执行整个文件后忽略中间结果
-- 提交：本文件不含可执行 COMMIT；全部人工确认后，由人工单独执行 COMMIT
-- 迁移前原始值：三条 ers_file_path 与 ers_file_size 均为 NULL，与 rollback.sql 还原值完全一致
-- =====================================================

START TRANSACTION;

-- ---------- 步骤 1：更新前 SELECT 预览 ----------
-- 确认返回 3 行，且每条 ers_file_path 与 ers_file_size 均严格为 NULL（迁移前状态）
SELECT ers_id, ers_app_id, ers_company_id, ers_file_path, ers_file_size,
       ers_snapshot_status, ers_version_verified
FROM t_ent_resume_snapshot
WHERE ers_app_id IN (70, 71, 78)
ORDER BY ers_app_id;
-- 停止条件：不是 3 行，或任一条 ers_file_path/ers_file_size 非 NULL（含空字符串），立即 ROLLBACK 并人工核对

-- ---------- 步骤 2：唯一性检查（每个 app_id 必须恰好 1 行）----------
SELECT ers_app_id, COUNT(*) AS row_count
FROM t_ent_resume_snapshot
WHERE ers_app_id IN (70, 71, 78)
GROUP BY ers_app_id;
-- 停止条件：任一 app_id 的 row_count 不等于 1，立即 ROLLBACK

-- ---------- 步骤 3：逐条 UPDATE（严格双字段 NULL 守卫）+ 立即 ROW_COUNT ----------
-- 注意：空字符串路径不被当作 NULL，必须 ers_file_path IS NULL 才放行

-- appId=70, companyId=1（真实数据库核实）
UPDATE t_ent_resume_snapshot
SET ers_file_path = 's3:recruit-files/enterprise-application-resume/1/70/f7265a2484e44f1bb8f28eb898e517d3.pdf',
    ers_file_size = 309407
WHERE ers_app_id = 70
  AND ers_company_id = 1
  AND ers_file_path IS NULL
  AND ers_file_size IS NULL;
SELECT ROW_COUNT() AS affected_rows_70;
-- 预期 ROW_COUNT=1；若为 0，说明严格双字段 NULL 守卫不满足（存在非 NULL 或空字符串），立即 ROLLBACK，不继续

-- appId=71, companyId=1（真实数据库核实）
UPDATE t_ent_resume_snapshot
SET ers_file_path = 's3:recruit-files/enterprise-application-resume/1/71/41b70c7ec33e42be9bfbe584645935a0.pdf',
    ers_file_size = 163683
WHERE ers_app_id = 71
  AND ers_company_id = 1
  AND ers_file_path IS NULL
  AND ers_file_size IS NULL;
SELECT ROW_COUNT() AS affected_rows_71;
-- 预期 ROW_COUNT=1；否则 ROLLBACK

-- appId=78, companyId=1（真实数据库核实）
UPDATE t_ent_resume_snapshot
SET ers_file_path = 's3:recruit-files/enterprise-application-resume/1/78/18a5a19616884d64a492decd1f86a4e8.pdf',
    ers_file_size = 163683
WHERE ers_app_id = 78
  AND ers_company_id = 1
  AND ers_file_path IS NULL
  AND ers_file_size IS NULL;
SELECT ROW_COUNT() AS affected_rows_78;
-- 预期 ROW_COUNT=1；否则 ROLLBACK

-- ---------- 步骤 4：更新后 SELECT 验收 ----------
SELECT ers_id, ers_app_id, ers_company_id, ers_file_path, ers_file_size,
       ers_snapshot_status, ers_version_verified
FROM t_ent_resume_snapshot
WHERE ers_app_id IN (70, 71, 78)
ORDER BY ers_app_id;
-- 预期：3 行，path 为对应 s3 引用，size 分别 309407/163683/163683；
--      ers_snapshot_status、ers_version_verified 等其余字段保持原值

-- ---------- 步骤 5：人工确认后单独提交（本文件不自动执行）----------
-- 逐条 ROW_COUNT 均为 1 且验收 SELECT 正确、人工复核无误后，由人工单独执行：
-- COMMIT;
-- 任何一步异常或不符，由人工执行：
-- ROLLBACK;

-- 说明：本 SQL 不更新另外 7 条（47/48/49/79/45/46/52），不设置任何身份核验字段。
