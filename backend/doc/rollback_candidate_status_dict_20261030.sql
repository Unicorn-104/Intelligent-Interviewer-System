-- 回滚：migration_candidate_status_dict_20261030.sql
-- 将 candidate_status 字典恢复到迁移前口径（0-4 流程状态 + 5-9 旧口径）。
-- 执行前请确认目标环境的旧标签与下方一致；如不一致，请按实际备份调整后再执行。

update sys_dict_data set dict_label = '新入库', list_class = '' where dict_type = 'candidate_status' and dict_value = '0';
update sys_dict_data set dict_label = '初筛通过', list_class = '' where dict_type = 'candidate_status' and dict_value = '1';
update sys_dict_data set dict_label = '面试中', list_class = '' where dict_type = 'candidate_status' and dict_value = '2';
update sys_dict_data set dict_label = '已淘汰', list_class = '' where dict_type = 'candidate_status' and dict_value = '3';
update sys_dict_data set dict_label = '已录用', list_class = '' where dict_type = 'candidate_status' and dict_value = '4';
update sys_dict_data set dict_label = '已入职', list_class = '' where dict_type = 'candidate_status' and dict_value = '5';
update sys_dict_data set dict_label = '已放弃', list_class = '' where dict_type = 'candidate_status' and dict_value = '6';
update sys_dict_data set dict_label = '人才库', list_class = '' where dict_type = 'candidate_status' and dict_value = '7';
update sys_dict_data set dict_label = '黑名单', list_class = '' where dict_type = 'candidate_status' and dict_value = '8';
update sys_dict_data set dict_label = '流程挂起', list_class = '' where dict_type = 'candidate_status' and dict_value = '9';
