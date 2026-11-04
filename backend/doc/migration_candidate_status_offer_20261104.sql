-- 候选人流程状态字典补充（待发 Offer）
-- 口径：0新入库 1初筛通过 2面试中 3已淘汰 4已录用 5待笔试 6笔试中 7笔试通过 8笔试未通过 9笔试缺考 10待发Offer
-- 归档来源 t_tal.tal_archive_source：0未归档 1笔试淘汰 2面试淘汰 3主动归档 4初筛淘汰 5Offer拒绝（候选人拒绝或回复超时）

update sys_dict_type set remark = '候选人流程状态（11 态）' where dict_type = 'candidate_status';

-- 缺失的「待发 Offer」状态补齐
insert into sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, remark)
select 10, '待发Offer', '10', 'candidate_status', '', 'warning', 'N', '0', 'admin', now(), '终面通过，等待发送或接受 Offer'
where not exists (select 1 from sys_dict_data where dict_type = 'candidate_status' and dict_value = '10');

-- 已存在的状态对齐标签与样式
update sys_dict_data set dict_label = '待发Offer', list_class = 'warning'
where dict_type = 'candidate_status' and dict_value = '10';
