-- 2026-10-20 部署对齐：补本地有而服务器缺的列（幂等：先判断再 ADD）
-- 目标库 recruit_agent

-- sys_user.company_id 关联企业ID
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema='recruit_agent' AND table_name='sys_user' AND column_name='company_id');
SET @sql := IF(@col=0,
  'ALTER TABLE `sys_user` ADD COLUMN `company_id` bigint NULL COMMENT ''关联企业ID''',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- t_cmp.api_quota API配额(次/月)
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema='recruit_agent' AND table_name='t_cmp' AND column_name='api_quota');
SET @sql := IF(@col=0,
  'ALTER TABLE `t_cmp` ADD COLUMN `api_quota` int DEFAULT 10000 COMMENT ''API配额(次/月)''',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- t_cmp.api_used API已使用量
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema='recruit_agent' AND table_name='t_cmp' AND column_name='api_used');
SET @sql := IF(@col=0,
  'ALTER TABLE `t_cmp` ADD COLUMN `api_used` int DEFAULT 0 COMMENT ''API已使用量''',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
