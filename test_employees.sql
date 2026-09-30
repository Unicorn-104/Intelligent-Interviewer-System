UPDATE sys_user SET company_id = 1 WHERE user_name = 'admin';

INSERT INTO sys_user (user_name, nick_name, email, phonenumber, sex, password, status, dept_id, company_id, create_time) 
VALUES ('yunzhi_hr', '云智HR', 'hr@yunzhi.com', '13800138001', '0', '$2a$10$7JMdE8eQ8eK3mUq3V4YjXOXO5xQZ7eK3mUq3V4YjXOXO5xQZ7eK3mUq', '0', 100, 1, NOW());

INSERT INTO sys_user (user_name, nick_name, email, phonenumber, sex, password, status, dept_id, company_id, create_time) 
VALUES ('yunzhi_recruiter', '云智招聘', 'recruit@yunzhi.com', '13800138002', '0', '$2a$10$7JMdE8eQ8eK3mUq3V4YjXOXO5xQZ7eK3mUq3V4YjXOXO5xQZ7eK3mUq', '0', 100, 1, NOW());

INSERT INTO sys_user (user_name, nick_name, email, phonenumber, sex, password, status, dept_id, company_id, create_time) 
VALUES ('shulian_hr', '数联HR', 'hr@shulian.com', '13800138003', '1', '$2a$10$7JMdE8eQ8eK3mUq3V4YjXOXO5xQZ7eK3mUq3V4YjXOXO5xQZ7eK3mUq', '0', 101, 2, NOW());
