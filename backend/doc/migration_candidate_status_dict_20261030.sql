-- 候选人流程状态字典（P2-20）
-- 口径：0新入库 1初筛通过 2面试中 3已淘汰 4已录用 5待笔试 6笔试中 7笔试通过 8笔试未通过 9笔试缺考
-- 说明：企业端候选人列表通过 sys_dict_data.dict_type='candidate_status' 读取展示标签，这里统一补齐 10 个状态。

insert into sys_dict_type (dict_name, dict_type, status, create_by, create_time, remark)
select '候选人状态', 'candidate_status', '0', 'admin', now(), '候选人流程状态（10 态）'
where not exists (select 1 from sys_dict_type where dict_type = 'candidate_status');

-- 已存在的状态先对齐标签与样式，避免历史数据标签不一致
update sys_dict_data set dict_label = '新入库', list_class = 'default' where dict_type = 'candidate_status' and dict_value = '0';
update sys_dict_data set dict_label = '初筛通过', list_class = 'success' where dict_type = 'candidate_status' and dict_value = '1';
update sys_dict_data set dict_label = '面试中', list_class = 'primary' where dict_type = 'candidate_status' and dict_value = '2';
update sys_dict_data set dict_label = '已淘汰', list_class = 'danger' where dict_type = 'candidate_status' and dict_value = '3';
update sys_dict_data set dict_label = '已录用', list_class = 'success' where dict_type = 'candidate_status' and dict_value = '4';
update sys_dict_data set dict_label = '待笔试', list_class = 'warning' where dict_type = 'candidate_status' and dict_value = '5';
update sys_dict_data set dict_label = '笔试中', list_class = 'warning' where dict_type = 'candidate_status' and dict_value = '6';
update sys_dict_data set dict_label = '笔试通过', list_class = 'success' where dict_type = 'candidate_status' and dict_value = '7';
update sys_dict_data set dict_label = '笔试未通过', list_class = 'danger' where dict_type = 'candidate_status' and dict_value = '8';
update sys_dict_data set dict_label = '笔试缺考', list_class = 'info' where dict_type = 'candidate_status' and dict_value = '9';

-- 缺失的状态补齐
insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 0, '新入库', '0', 'candidate_status', '', 'default', 'N', '0', 'admin', now(), '候选人新入库'
where not exists (select 1 from sys_dict_data where dict_type = 'candidate_status' and dict_value = '0');

insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 1, '初筛通过', '1', 'candidate_status', '', 'success', 'N', '0', 'admin', now(), '初筛通过'
where not exists (select 1 from sys_dict_data where dict_type = 'candidate_status' and dict_value = '1');

insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 2, '面试中', '2', 'candidate_status', '', 'primary', 'N', '0', 'admin', now(), '面试进行中'
where not exists (select 1 from sys_dict_data where dict_type = 'candidate_status' and dict_value = '2');

insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 3, '已淘汰', '3', 'candidate_status', '', 'danger', 'N', '0', 'admin', now(), '流程终态，不可回退'
where not exists (select 1 from sys_dict_data where dict_type = 'candidate_status' and dict_value = '3');

insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 4, '已录用', '4', 'candidate_status', '', 'success', 'N', '0', 'admin', now(), '流程终态，不可回退'
where not exists (select 1 from sys_dict_data where dict_type = 'candidate_status' and dict_value = '4');

insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 5, '待笔试', '5', 'candidate_status', '', 'warning', 'N', '0', 'admin', now(), '笔试通知已发送'
where not exists (select 1 from sys_dict_data where dict_type = 'candidate_status' and dict_value = '5');

insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 6, '笔试中', '6', 'candidate_status', '', 'warning', 'N', '0', 'admin', now(), '笔试进行中'
where not exists (select 1 from sys_dict_data where dict_type = 'candidate_status' and dict_value = '6');

insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 7, '笔试通过', '7', 'candidate_status', '', 'success', 'N', '0', 'admin', now(), '笔试通过，待面试'
where not exists (select 1 from sys_dict_data where dict_type = 'candidate_status' and dict_value = '7');

insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 8, '笔试未通过', '8', 'candidate_status', '', 'danger', 'N', '0', 'admin', now(), '笔试未通过'
where not exists (select 1 from sys_dict_data where dict_type = 'candidate_status' and dict_value = '8');

insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 9, '笔试缺考', '9', 'candidate_status', '', 'info', 'N', '0', 'admin', now(), '笔试超时未交卷或缺考'
where not exists (select 1 from sys_dict_data where dict_type = 'candidate_status' and dict_value = '9');
