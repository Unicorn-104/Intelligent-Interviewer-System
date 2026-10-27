-- 仅新增回执游标表。无历史已读数据回填，无现有业务表变更。
-- 由维护者确认目标数据库后执行；可重复执行。
CREATE TABLE IF NOT EXISTS t_im_read_cursor (
  irc_session_id BIGINT NOT NULL COMMENT '真实聊天会话ID',
  irc_user_id BIGINT NOT NULL COMMENT '查看消息的登录账号',
  irc_last_message_id BIGINT NOT NULL COMMENT '已显示消息的最大ID，单调递增',
  irc_read_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '最新推进时间',
  PRIMARY KEY (irc_session_id, irc_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='单聊消息已读游标';
