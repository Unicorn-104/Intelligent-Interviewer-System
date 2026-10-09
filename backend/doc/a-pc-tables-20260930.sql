-- A-PC 后台管理系统新增表建表脚本
-- 执行环境：recruit_agent 数据库
-- 作者：TQY
-- 日期：2026-09-30

-- 1. AI模型Provider表
CREATE TABLE IF NOT EXISTS t_model_provider (
  mpp_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
  mpp_name VARCHAR(100) NOT NULL COMMENT 'Provider名称',
  mpp_api_url VARCHAR(500) COMMENT 'API地址',
  mpp_api_key VARCHAR(200) COMMENT 'API密钥',
  mpp_model_name VARCHAR(100) COMMENT '模型名称',
  mpp_params_json TEXT COMMENT '参数配置JSON',
  mpp_status TINYINT DEFAULT 1 COMMENT '状态：1启用 0禁用',
  mpp_created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  mpp_updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT='AI模型Provider配置';

-- 2. Prompt版本表
CREATE TABLE IF NOT EXISTS t_prompt_version (
  pmv_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
  pmv_name VARCHAR(100) NOT NULL COMMENT 'Prompt名称',
  pmv_version VARCHAR(20) COMMENT '版本号',
  pmv_content TEXT COMMENT 'Prompt内容',
  pmv_status TINYINT DEFAULT 1 COMMENT '状态：1启用 0禁用',
  pmv_created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  pmv_updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT='Prompt版本配置';

-- 3. 系统健康监控表
CREATE TABLE IF NOT EXISTS t_sys_health (
  sh_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
  sh_metric VARCHAR(50) NOT NULL COMMENT '监控指标',
  sh_value VARCHAR(100) COMMENT '指标值',
  sh_level VARCHAR(20) COMMENT '告警级别：info/warning/critical',
  sh_created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT='系统健康监控';

-- 4. 系统告警表
CREATE TABLE IF NOT EXISTS t_sys_alert (
  sal_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
  sal_title VARCHAR(200) NOT NULL COMMENT '告警标题',
  sal_content TEXT COMMENT '告警内容',
  sal_level VARCHAR(20) COMMENT '告警级别：info/warning/critical',
  sal_status TINYINT DEFAULT 0 COMMENT '处理状态：0待处理 1已确认 2已忽略 3已解决',
  sal_created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  sal_handled_at DATETIME COMMENT '处理时间',
  sal_handler VARCHAR(50) COMMENT '处理人'
) COMMENT='系统告警';

-- 5. AI评分卡表
CREATE TABLE IF NOT EXISTS t_scorecard (
  sc_id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '评分卡ID',
  sc_name VARCHAR(100) NOT NULL COMMENT '评分卡名称',
  sc_direction VARCHAR(50) COMMENT '岗位方向',
  sc_dimensions TEXT COMMENT '评分维度JSON',
  sc_status TINYINT DEFAULT 1 COMMENT '状态：1启用 0禁用',
  sc_created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  sc_updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT='AI评分卡';
