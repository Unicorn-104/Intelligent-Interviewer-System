-- 回滚：migration_candidate_status_offer_20261104.sql
-- 移除「待发 Offer」字典项并恢复字典类型说明；已写入 10 的历史候选人数据需人工确认后再处理。

delete from sys_dict_data where dict_type = 'candidate_status' and dict_value = '10';

update sys_dict_type set remark = '候选人流程状态（10 态）' where dict_type = 'candidate_status';
