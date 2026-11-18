-- =====================================================
-- 回滚 SQL（安全修复版，仅生成，不执行）
-- 作用：撤销本次 PDF 迁移对 appId 70/71/78 的数据库回写
-- 迁移前事实：三条 ers_file_path 与 ers_file_size 均为 NULL（须与迁移前留档一致）
-- 双前置守卫：仅当当前 path 等于本次新路径且 size 仍为本次写入大小，才还原 NULL
-- 若 path 或 size 已被其他业务改动，停止回滚，不覆盖合法更新
-- 提交：本文件不含 COMMIT；人工验收后单独执行 COMMIT
-- =====================================================

START TRANSACTION;

-- ---------- 步骤 1：回滚前 SELECT 留档 ----------
SELECT ers_id, ers_app_id, ers_company_id, ers_file_path, ers_file_size
FROM t_ent_resume_snapshot
WHERE ers_app_id IN (70, 71, 78)
ORDER BY ers_app_id;
-- 停止条件：path 不是本次新路径或 size 不是本次写入值的记录，跳过该条并人工核对

-- ---------- 步骤 2：逐条回滚（新路径 + 大小双前置）+ 立即 ROW_COUNT ----------

-- appId=70
UPDATE t_ent_resume_snapshot
SET ers_file_path = NULL,
    ers_file_size = NULL
WHERE ers_app_id = 70
  AND ers_company_id = 1
  AND ers_file_path = 's3:recruit-files/enterprise-application-resume/1/70/f7265a2484e44f1bb8f28eb898e517d3.pdf'
  AND ers_file_size = 309407;
SELECT ROW_COUNT() AS rollback_rows_70;
-- 预期 ROW_COUNT=1；若为 0，说明 path/size 已变化，停止并人工核对，不强制回滚

-- appId=71
UPDATE t_ent_resume_snapshot
SET ers_file_path = NULL,
    ers_file_size = NULL
WHERE ers_app_id = 71
  AND ers_company_id = 1
  AND ers_file_path = 's3:recruit-files/enterprise-application-resume/1/71/41b70c7ec33e42be9bfbe584645935a0.pdf'
  AND ers_file_size = 163683;
SELECT ROW_COUNT() AS rollback_rows_71;
-- 预期 ROW_COUNT=1；否则停止

-- appId=78
UPDATE t_ent_resume_snapshot
SET ers_file_path = NULL,
    ers_file_size = NULL
WHERE ers_app_id = 78
  AND ers_company_id = 1
  AND ers_file_path = 's3:recruit-files/enterprise-application-resume/1/78/18a5a19616884d64a492decd1f86a4e8.pdf'
  AND ers_file_size = 163683;
SELECT ROW_COUNT() AS rollback_rows_78;
-- 预期 ROW_COUNT=1；否则停止

-- ---------- 步骤 3：回滚后 SELECT 验收 ----------
SELECT ers_id, ers_app_id, ers_company_id, ers_file_path, ers_file_size
FROM t_ent_resume_snapshot
WHERE ers_app_id IN (70, 71, 78)
ORDER BY ers_app_id;
-- 预期：对应记录 ers_file_path、ers_file_size 还原为 NULL，其余字段未变

-- ---------- 步骤 4：人工验收后单独提交（本文件不自动执行）----------
-- 确认 ROW_COUNT 与验收 SELECT 正确后，由人工单独执行：
-- COMMIT;
-- 异常则由人工执行：
-- ROLLBACK;

-- 注意：本回滚仅撤销数据库路径，不删除已复制的企业目标对象，也不删除 C-App 源对象；
--      对象清理须另行评估并经授权。
