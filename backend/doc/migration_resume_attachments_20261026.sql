-- 支持一份简历保存多个附加文件，原始主 PDF 仍保留在 t_res_base 中。
CREATE TABLE IF NOT EXISTS t_res_attachment (
    rsa_id bigint NOT NULL AUTO_INCREMENT COMMENT '附件编号',
    rsa_resume_id bigint NOT NULL COMMENT '简历编号',
    rsa_user_id bigint NOT NULL COMMENT '用户编号',
    rsa_file_path varchar(500) NOT NULL COMMENT '私有存储引用',
    rsa_file_name varchar(255) NOT NULL COMMENT '原始文件名',
    rsa_file_size bigint NOT NULL COMMENT '文件大小（字节）',
    rsa_content_type varchar(100) DEFAULT NULL COMMENT '媒体类型',
    rsa_status tinyint NOT NULL DEFAULT 1 COMMENT '状态：1有效，0删除',
    rsa_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (rsa_id),
    KEY idx_rsa_resume_status (rsa_resume_id, rsa_status),
    KEY idx_rsa_user_resume (rsa_user_id, rsa_resume_id),
    CONSTRAINT fk_rsa_resume_id FOREIGN KEY (rsa_resume_id) REFERENCES t_res_base (rbs_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='求职者简历附加文件';