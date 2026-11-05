-- 只读盘点脚本：候选人/投递状态一致性盘点（P2-18）
-- 用途：先盘点、后修复。本脚本全部为 SELECT，不修改任何数据。
-- 状态口径：t_tal.tal_status 0新入库 1初筛通过 2面试中 3已淘汰 4已录用
--                          5待笔试 6笔试中 7笔试通过 8笔试未通过 9笔试缺考
--          t_app_record.app_status 0待筛选 1初筛通过 2初筛淘汰 3已约面
--                                 4待笔试 5笔试中 6笔试通过 7笔试未通过 8笔试缺考 9已撤回
--          t_tal.tal_archive_source 0未归档 1笔试淘汰 2面试淘汰 3主动归档 4初筛淘汰

-- 1. 候选人状态分布
select tal_status, count(*) as total
from t_tal
group by tal_status
order by tal_status;

-- 2. 归档来源分布（含缺失）
select ifnull(tal_archive_source, 0) as archive_source, count(*) as total
from t_tal
group by ifnull(tal_archive_source, 0)
order by archive_source;

-- 3. 终态候选人仍存在未关闭投递（应为 0 行；若存在说明历史数据未按状态机收尾）
select t.tal_id, t.tal_status, a.app_id, a.app_position_id, a.app_status, a.app_updated_at
from t_tal t
join t_app_record a on a.app_candidate_id = t.tal_id
where t.tal_status in (3, 4)
  and a.app_status not in (2, 7, 8, 9)
order by t.tal_id, a.app_id;

-- 4. 已撤回投递但候选人仍在流程中（撤回时应同步终止流程实例）
select a.app_id, a.app_position_id, a.app_candidate_id, a.app_status, t.tal_status,
       i.pin_id, i.pin_status
from t_app_record a
join t_tal t on t.tal_id = a.app_candidate_id
left join t_process_instance i on i.pin_candidate_id = t.tal_id and i.pin_position_id = a.app_position_id
where a.app_status = 9
  and t.tal_status not in (3, 4)
  and ifnull(i.pin_status, 2) = 0
order by a.app_updated_at desc;

-- 5. 淘汰/录用终态但流程实例未收尾（淘汰应为 pin_status=3，录用应为 pin_status=1）
select t.tal_id, t.tal_status, i.pin_id, i.pin_position_id, i.pin_status
from t_tal t
join t_process_instance i on i.pin_candidate_id = t.tal_id
where (t.tal_status = 3 and i.pin_status <> 3)
   or (t.tal_status = 4 and i.pin_status <> 1)
order by t.tal_id;

-- 6. 已淘汰但缺少淘汰日志（状态日志由状态机写入，历史数据可能缺失）
select t.tal_id, t.tal_status, t.tal_archive_source
from t_tal t
where t.tal_status = 3
  and not exists (select 1 from t_tal_status_log l
                  where l.tsl_candidate_id = t.tal_id and l.tsl_to_status = 3)
order by t.tal_id;

-- 7. 笔试状态与笔试记录不一致：候选人待笔试/笔试中，但该岗位无进行中的笔试记录
select t.tal_id, t.tal_status, a.app_position_id, a.app_status,
       (select count(*) from t_exam_record r
         join t_exam_schedule s on s.esd_id = r.erc_schedule_id
         where r.erc_candidate_id = t.tal_id and s.esd_position_id = a.app_position_id
           and r.erc_status in (0, 1)) as active_record_count
from t_tal t
join t_app_record a on a.app_candidate_id = t.tal_id
where t.tal_status in (5, 6)
  and not exists (select 1 from t_exam_record r
                  join t_exam_schedule s on s.esd_id = r.erc_schedule_id
                  where r.erc_candidate_id = t.tal_id and s.esd_position_id = a.app_position_id
                    and r.erc_status in (0, 1))
order by t.tal_id;

-- 8. 投递状态分布（按岗位）
select app_position_id, app_status, count(*) as total
from t_app_record
group by app_position_id, app_status
order by app_position_id, app_status;

-- 9. 初筛淘汰但候选人未进入淘汰终态（AI 自动回写只改投递，属正常；此处用于确认人工驳回是否漏写终态）
select a.app_id, a.app_position_id, a.app_candidate_id, a.app_status, t.tal_status
from t_app_record a
join t_tal t on t.tal_id = a.app_candidate_id
where a.app_status = 2
  and t.tal_status not in (3, 4)
order by a.app_updated_at desc;
