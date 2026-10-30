-- 面试前邮件提醒：预约表加「提醒状态」标记（幂等，可重复执行）
-- 目标表：t_sch_appointment
-- apt_notified 提醒状态机（单列，不新增表）：
--   0 未处理（默认，可被提醒任务认领）
--   1 已处理（邮件已发送，或按策略跳过——如候选人缺邮箱；1 表示本次提醒已处理，不代表发送成功）
--   2 发送中（已被某实例认领；SMTP 失败保留 2，由定时任务的回收逻辑按退避时间重置为 0 后受控重试）
-- 改期后由 updateAppointmentTime 重置为 0；已取消/已完成预约由提醒任务按 apt_status 过滤。

SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 't_sch_appointment'
    AND COLUMN_NAME = 'apt_notified'
);
SET @ddl := IF(
  @col = 0,
  'ALTER TABLE t_sch_appointment ADD COLUMN apt_notified tinyint NOT NULL DEFAULT 0 COMMENT ''提醒状态 0未处理 1已处理 2发送中'' AFTER apt_status',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
