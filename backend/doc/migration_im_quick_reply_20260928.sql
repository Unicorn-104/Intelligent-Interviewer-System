USE recruit_agent;
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS t_im_quick_reply (
  id          bigint       NOT NULL AUTO_INCREMENT COMMENT '主键',
  category    varchar(30)  NOT NULL COMMENT '分类：面试安排/进度反馈/通用话术等',
  content     varchar(500) NOT NULL COMMENT '回复内容',
  created_at  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT 'IM快捷回复模板表';

INSERT INTO t_im_quick_reply (category, content) VALUES
('面试安排', '您好，您的 AI 结构化预面已安排于明天 14:00，请提前 15 分钟进入会议。'),
('面试安排', '您好，面试时间如需调整，您看本周五 10:30 是否方便？'),
('进度反馈', '您已通过初筛，HR 将在 1 个工作日内联系您确认下一步安排。'),
('进度反馈', '您的当前阶段评估已完成，后续安排请留意系统通知。'),
('通用话术', '您好，请问现在方便进行简短电话沟通吗？');
