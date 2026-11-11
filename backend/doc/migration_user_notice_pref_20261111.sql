-- ============================================================================
-- 企业端「通知设置」用户级偏好落库迁移脚本
-- 数据库: recruit_agent
-- 说明:
--   1. 新建 t_user_notice_pref，按企业账号保存 4 个通知开关
--   2. 无记录时按全部开启处理（与前端默认值一致），首次保存时插入
--   3. 面试提醒与简历入库已接入 EnterpriseSystemNoticeService，
--      候选人消息与系统更新当前仅保存开关，尚无对应发送逻辑
-- ============================================================================

USE recruit_agent;

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS t_user_notice_pref (
  pref_user_id     bigint   NOT NULL COMMENT '企业端用户ID（sys_user.user_id）',
  pref_interview   tinyint  NOT NULL DEFAULT 1 COMMENT '面试提醒：1接收 0不接收',
  pref_resume      tinyint  NOT NULL DEFAULT 1 COMMENT '简历入库：1接收 0不接收',
  pref_message     tinyint  NOT NULL DEFAULT 1 COMMENT '候选人消息：1接收 0不接收',
  pref_system      tinyint  NOT NULL DEFAULT 0 COMMENT '系统更新：1接收 0不接收',
  pref_update_time datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '最后修改时间',
  PRIMARY KEY (pref_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='企业端用户站内通知偏好';
