# 人才库期望薪资：历史迁移草案

> 2026-10-23：用户已授权实现和建表。当前生效DDL为e-app/new.sql的TALENT_EXPECTATION_20261023段，使用独立t_usr_job_preference、本人资料填写、企业全站目录展示；未回填薪资，尚未新增薪资筛选。以下为授权前的历史方案，不是当前执行说明。

## 当前范围

本次学历、工作经验、城市和最近登录筛选复用已有字段，**无需 DDL**。没有连接业务数据库、没有执行本草案中的 SQL。

已核对的源码中，`sys_user` 有 `current_city` / `target_city`，教育表有 `edu_degree`，工作表有经历日期，账号表有 `login_date`。未发现求职者端结构化“期望薪资”读写契约。`wrk_salary_range` 为历史工作薪资，不能代替期望薪资；岗位薪资也不能代替候选人期望。

## 执行前门禁

1. DBA 仅核查目标库元数据（不要导出个人数据），确认是否已有同类表/字段。若存在，优先复用，不重复建表。
2. 产品确认期望薪资是否属于账号全局求职意向，还是每份简历独立；本草案按账号全局设计。
3. 确认金额统一为人民币税前月薪、整数元，以及“面议/未填写”的区别。其他币种和年薪换算不隐式推断。
4. 审核求职者写入授权、企业可见范围、迁移及回滚方案；获得**单独 DDL 执行授权**后再由管理员实施。

## 候选结构（只作设计示例，不纳入当前运行代码）

建议独立 `t_usr_job_preference` 表，避免把求职意向与后台系统账号字段混杂。字段：

| 字段 | 类型 | 语义 |
| --- | --- | --- |
| user_id | BIGINT，主键 | 当前用户，与认证账号精确关联 |
| salary_min | INT，可空 | 期望月薪下限，单位：人民币元 |
| salary_max | INT，可空 | 期望月薪上限，单位：人民币元 |
| salary_negotiable | TINYINT，可空 | NULL 未填写；1 面议；0 明确区间 |
| updated_at | DATETIME | 最近一次修改时间 |

```sql
-- 草案：必须先核查同类结构及 MySQL 版本；请勿直接在生产环境执行。
CREATE TABLE t_usr_job_preference (
    user_id BIGINT NOT NULL,
    salary_min INT NULL,
    salary_max INT NULL,
    salary_negotiable TINYINT NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id)
);
```

只有用户主动填写后才写数据；不要回填 0 元，不从真实简历原文或历史薪资自动推断期望。数据库约束需按目标 MySQL 实际版本补齐，不能只依赖旧版会忽略的 CHECK；服务端始终校验两端同有同无、0 ≤ 下限 ≤ 上限，以及面议状态与区间互斥。

暂不盲目增加薪资查询索引；上线前用目标库规模的脱敏数据与 EXPLAIN 评估联合索引。当前企业候选人范围的 `tal_company_id` 约束必须保留。

## 未来接口与 UI（需独立实现验收）

- 求职者端：补个人求职意向填写入口、认证用户自己的读写 API、校验和审计；禁止客户端指定他人的 `user_id`。
- 企业端：只在已有企业人才库权限范围内查询，经授权展示期望；提供不限、面议、人民币月薪区间筛选。
- 区间匹配建议采用重叠语义 `salary_max >= filter_min AND salary_min <= filter_max`；未知值只在“不限”结果中展示，不能视作 0。
- 明确实际录用薪资不由此数据决定，不按性别、年龄等敏感属性推断薪资。

## 回滚

优先回滚应用、停止写入并保留新增表数据；不要在普通代码回滚时直接删表。确需结构回滚时，由 DBA 确认无其他消费者、按批准的数据保留策略备份并再次授权后处理。SQL 示例没有加入自动迁移、启动脚本或当前部署步骤。
