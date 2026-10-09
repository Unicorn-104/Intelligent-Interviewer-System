-- 创建内容分类表
CREATE TABLE IF NOT EXISTS t_content_category (
  cca_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  cca_name VARCHAR(100) NOT NULL COMMENT '分类名称',
  cca_parent_id BIGINT DEFAULT 0 COMMENT '父分类ID',
  cca_sort INT DEFAULT 0 COMMENT '排序',
  cca_status CHAR(1) DEFAULT '0' COMMENT '状态（0正常 1停用）',
  cca_create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  cca_update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT='内容分类';

-- 创建问题表
CREATE TABLE IF NOT EXISTS t_content_question (
  cq_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  cq_title VARCHAR(200) NOT NULL COMMENT '问题标题',
  cq_category_id BIGINT COMMENT '分类ID',
  cq_content TEXT COMMENT '问题内容',
  cq_answer TEXT COMMENT '答案',
  cq_view_count INT DEFAULT 0 COMMENT '浏览次数',
  cq_status CHAR(1) DEFAULT '0' COMMENT '状态（0发布 1草稿）',
  cq_create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  cq_update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT='问题管理';

-- 创建反馈表
CREATE TABLE IF NOT EXISTS t_content_feedback (
  cf_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  cf_user_id BIGINT COMMENT '用户ID',
  cf_user_name VARCHAR(100) COMMENT '用户名称',
  cf_type VARCHAR(50) COMMENT '反馈类型',
  cf_content TEXT NOT NULL COMMENT '反馈内容',
  cf_contact VARCHAR(100) COMMENT '联系方式',
  cf_status CHAR(1) DEFAULT '0' COMMENT '状态（0待处理 1已处理）',
  cf_reply TEXT COMMENT '回复',
  cf_create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  cf_update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT='反馈处理';

-- 创建帮助表
CREATE TABLE IF NOT EXISTS t_content_help (
  ch_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  ch_title VARCHAR(200) NOT NULL COMMENT '标题',
  ch_category VARCHAR(50) COMMENT '分类',
  ch_content TEXT COMMENT '内容',
  ch_sort INT DEFAULT 0 COMMENT '排序',
  ch_status CHAR(1) DEFAULT '0' COMMENT '状态（0正常 1停用）',
  ch_create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  ch_update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT='帮助中心';

-- 创建消息发送记录表
CREATE TABLE IF NOT EXISTS t_msg_record (
  mr_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  mr_user_id BIGINT COMMENT '接收用户ID',
  mr_user_name VARCHAR(100) COMMENT '接收用户名称',
  mr_template_id BIGINT COMMENT '模板ID',
  mr_channel VARCHAR(50) COMMENT '渠道（sms/email/system）',
  mr_content TEXT COMMENT '发送内容',
  mr_status CHAR(1) DEFAULT '0' COMMENT '状态（0成功 1失败）',
  mr_create_time DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT='消息发送记录';

-- 创建渠道配置表
CREATE TABLE IF NOT EXISTS t_msg_channel (
  mc_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  mc_name VARCHAR(100) NOT NULL COMMENT '渠道名称',
  mc_type VARCHAR(50) NOT NULL COMMENT '渠道类型（sms/email/webhook）',
  mc_config TEXT COMMENT '配置JSON',
  mc_status CHAR(1) DEFAULT '0' COMMENT '状态（0启用 1停用）',
  mc_create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  mc_update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT='渠道配置';

-- 插入测试数据
INSERT INTO t_content_category (cca_name, cca_parent_id, cca_sort) VALUES 
('常见问题', 0, 1),
('使用指南', 0, 2),
('账号问题', 1, 1);

INSERT INTO t_content_help (ch_title, ch_category, ch_content, ch_sort) VALUES 
('如何注册账号', '常见问题', '点击注册按钮，填写手机号和验证码即可完成注册。', 1),
('如何修改密码', '账号问题', '进入个人设置-安全设置，点击修改密码。', 2),
('如何联系客服', '常见问题', '发送邮件至support@example.com或拨打400-123-4567。', 3);

INSERT INTO t_content_feedback (cf_user_name, cf_type, cf_content, cf_contact, cf_status) VALUES 
('张三', '功能建议', '希望增加导出功能', 'zhangsan@example.com', '0'),
('李四', '问题反馈', '登录页面有时无法加载', 'lisi@example.com', '1'),
('王五', '投诉', '客服响应太慢', 'wangwu@example.com', '0');

-- t_msg_template已存在，跳过

INSERT INTO t_msg_channel (mc_name, mc_type, mc_config, mc_status) VALUES 
('阿里云短信', 'sms', '{"accessKey":"xxx","secret":"xxx"}', '0'),
('企业邮箱', 'email', '{"smtp":"smtp.example.com"}', '0'),
('Webhook通知', 'webhook', '{"url":"https://example.com/webhook"}', '1');

INSERT INTO t_msg_record (mr_user_name, mr_template_id, mr_channel, mr_content, mr_status) VALUES 
('张三', 1, 'sms', '您的验证码是123456', '0'),
('李四', 2, 'email', '密码重置验证码：654321', '0'),
('王五', 3, 'system', '您有新的面试邀请', '0');

SELECT '建表完成' AS result;
