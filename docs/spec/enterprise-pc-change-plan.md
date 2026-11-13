# 企业端 PC 改造计划

> 适用范围：`enterprise_pc/RuoYi-Vue3`（企业端 PC）+ `backend/`（RuoYi 后端）
> 编写依据：2026-11-13 企业端 PC 与 e-app 全量功能对比（路由、页面、API 模块、Controller/Service 交叉核对）
> 目标：补齐 PC 端仅剩的功能缺口，并对齐 App 端已有能力，形成可验收的闭环

## 1. 现状结论

- PC 端路由页面 24 个（不含隐藏会议流程页），全部调用真实后端接口，无 `reserveApi` 假数据残留，完成度约 93%。
- 与 e-app 的功能差异：
  - **PC 独有**：在线笔试与监考、会议录制回放与存储管理、企业系统设置（公司/部门/成员/模板/数据管理）、岗位编辑/复制/AI 解析 JD/导入草稿/流程配置、候选人批量改状态与批量打标签、调研模板配置、人才独立搜索页。
  - **App 独有**：候选人改期申请的审批、面试环境预加载、功能地图/快捷入口。
- PC 已有「HR 主动改期」（`rescheduleInterview`），缺的是「候选人提交改期申请后的审批入口」。后端 `RescheduleReviewController` 与 `RescheduleRequestService` 已完整实现，前端无页面、无路由、无菜单。

## 2. 改动总览

| 优先级 | 功能点 | 涉及端 | 缺口 | 验收要点 |
| --- | --- | --- | --- | --- |
| P0 | 改期审批页面 | PC（后端已有） | 前端无入口 | 通过/驳回真实落库，候选人收到通知 |
| P1 | 面试安排中心展示改期待办 | PC | 无待办角标 | 待审批数与列表一致，可一键进入 |
| P1 | 后端 AI 评分异步用例修复 | 后端 | 6 个用例失败 | `ScreeningServiceImplTest` 全绿 |
| P2 | 剩余功能计划文档状态刷新 | 文档 | 状态过期 | 现状表与实际一致 |

## 3. 详细方案

### 3.1 P0 改期审批页面

**现状**：e-app 已有 `schedule/reschedule_review_page`；PC 端无对应页面。后端接口全部就绪（`RescheduleReviewController`）：

| 方法 | 路径 | 参数 | 返回 |
| --- | --- | --- | --- |
| GET | `/enterprise/interview/reschedule-requests` | `status`（pending/approved/rejected，可选）、`pageNum`、`pageSize`（≤100） | `TableDataInfo`，行字段见下表 |
| GET | `/enterprise/interview/reschedule-requests/{requestId}` | `requestId` | `AjaxResult.data` 单行 |
| PUT | `/enterprise/interview/reschedule-requests/{requestId}/review` | `{ decision: approved \| rejected, note }` | `AjaxResult.data` 审批后的单行 |

行字段（Mapper 已直出，前端无需二次拼装）：`requestId`、`appointmentId`、`candidateId`、`requesterId`、`originalStartTime`、`originalEndTime`、`newStartTime`、`newEndTime`、`reason`、`status`（pending/approved/rejected）、`reviewNote`、`requestedAt`、`reviewedAt`、`candidateName`、`positionName`、`interviewerName`、`reviewerName`。

**后端业务规则（前端需如实呈现，不得本地兜底）**

- 只有「未开始且未取消」的预约可以通过改期申请，否则返回「仅未开始且未取消的面试可以申请或通过改期」；
- 原时间/面试官已发生变化时返回「原面试安排已变化，请驳回后重新申请」；
- 审批人不能审批本人提交的申请，返回「不能审批本人提交的改期申请」；
- 驳回必须填写审批说明（1–500 字）；通过时说明可选；
- 重复提交同一结果幂等返回当前记录，不同结果返回「该申请已处理，请刷新列表」；
- 所有错误均为 `ServiceException`，前端直接展示 `msg`，禁止改写为通用提示。

**前端改动清单**

| 类型 | 文件 | 改动 |
| --- | --- | --- |
| 新增 | `views/enterprise/interviews/reschedule-review.vue` | 审批页面本体 |
| 修改 | `router/index.js` | 在 `/enterprise` 下新增 `interviews/reschedule-review`，`name: 'EnterpriseRescheduleReview'`，`meta.title: '改期审批'` |
| 修改 | `views/enterprise/components/AppSidebar.vue` | 「面试与笔试」分组内、`面试安排` 之后新增子项，`badge` 绑定待审批数 |
| 修改 | `api/interview.js` | 新增 `listRescheduleRequests` / `getRescheduleRequest` / `reviewRescheduleRequest` |
| 修改 | `views/enterprise/interviews/index.vue` | 新增「改期审批」入口按钮与角标（见 3.2） |

**页面结构**

- 顶部：状态 tabs（待审批 / 已通过 / 已驳回 / 全部），待审批 tab 显示数量；
- 表格列：候选人、岗位、原面试时间、申请新时间、申请理由（超长省略 + tooltip）、申请时间、状态、操作；
- 操作：`待审批` 行展示「查看 / 通过 / 驳回」；已处理行仅「查看」；
- 详情抽屉：原/新时间对比、申请理由、面试官、申请人、审批人、审批说明、审批时间；
- 审批弹窗：通过时说明可选、驳回时必填，提交期间按钮禁用防重复点击；
- 空态：无数据展示空态占位，不使用演示数据；加载失败展示错误提示并支持重试。

**验收**

- 候选人提交申请 → PC 审批通过 → `t_sch_appointment` 时间已更新，候选人收到站内消息与聊天卡片；
- 驳回后原排期不变，`rsr_review_note` 与 `rsr_reviewed_at` 正确落库；
- 审批本人提交的申请、审批已处理申请、跨企业访问均返回后端原始错误文案；
- 后端既有单测 `RescheduleRequestServiceTest`、`RescheduleReviewControllerTest` 保持通过。

### 3.2 P1 面试安排中心展示改期待办

- 不新增后端接口：调用 `listRescheduleRequests({ status: 'pending', pageNum: 1, pageSize: 1 })`，取 `TableDataInfo.total` 作为待审批数；
- 面试安排页顶部「改期审批」按钮展示角标，数量为 0 时不展示角标；
- 点击跳转 `/enterprise/interviews/reschedule-review?status=pending`；
- 从审批页返回面试安排页时重新拉取数量（`onActivated` 或路由返回钩子），避免角标滞留；
- 侧边栏 `AppSidebar.vue` 的 `badge` 复用同一数量，页面加载失败时静默不展示，不阻塞主页面渲染。

**验收**：角标数与待审批列表总数一致；审批一条后返回面试安排页，角标实时递减；接口失败不出现控制台报错刷屏。

### 3.3 P1 后端 AI 评分异步用例修复

**现状**：`ScreeningServiceImplTest` 中 6 个用例失败（`taskReturnsBeforeModelCompletesAndPersistsValidatedReportAtomically`、`legacyTriggerWaitsForCompletionRatherThanReportingPrematureSuccess`、`saveFailureRollsBackOnlyCurrentCandidate`、`secondFailureDoesNotUndoFirstCandidateResult` 等），均为异步编排改动后语义过期的断言。

**改动**

- 按当前 `triggerScreeningAsync` / `triggerScreening` 的实际返回语义重写断言；
- `legacyTrigger` 用例改为不依赖真实等待（使用可控 latch 或直接校验返回状态），将单类执行时间从 12 分钟降到秒级；
- 保持原有覆盖意图：失败回滚、部分成功不回退、幂等不重复触发。

**验收**：`mvn -pl ruoyi-system -am test -Dtest=ScreeningServiceImplTest` 全绿且耗时 < 1 分钟。

### 3.4 P2 剩余功能计划文档状态刷新

- 更新 `docs/spec/enterprise-remaining-work-plan.md`：A/B/C2/C3/C4/D1/D2/D4/D5 标记为已完成并注明实现位置；D3（简历批量导入）本期不做，保持未开始并注明原因。

## 4. 范围边界（本计划不做）

- 不做 App 端的功能地图/快捷入口、面试环境预加载，这些属于移动端形态差异，PC 无对应场景；
- 不改动后端审批业务逻辑与通知实现，仅复用现有接口；
- 不做改期历史快照表（见第 7 节待确认）；
- 不重构现有面试安排页布局，仅在顶部增加入口与角标。

## 5. 实施顺序与提交拆分

分支：从最新 `origin/dev` 创建 `feature/enterprise-pc-completion-YLX`。

1. `feat(schedule): PC 新增候选人改期申请审批页面`
2. `feat(schedule): 面试安排中心展示改期待办与角标`
3. `test(screening): 修正异步评分用例断言与执行耗时`
4. `docs(spec): 刷新企业端剩余功能状态`

每项完成即联调，不合并提交。

## 6. 联调与验收清单

- [ ] 后端：`mvn -pl ruoyi-system,ruoyi-admin -am compile`
- [ ] 后端：`mvn -pl ruoyi-system -am test -Dtest=ScreeningServiceImplTest`
- [ ] 后端：`mvn -pl ruoyi-system -am test -Dtest=RescheduleRequestServiceTest,RescheduleReviewControllerTest`
- [ ] 前端：`npm run build:prod`
- [ ] 前端：页面、路由、侧边栏子项三者均可到达且刷新不 404
- [ ] 数据库核对：`t_sch_appointment`、`t_sch_reschedule_request`
- [ ] 企业隔离抽查：A 企业账号访问 B 企业申请一律返回业务错误
- [ ] 无明文凭据、无构建产物、无 `application*.yml` 入库

## 7. 风险与回滚

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| 审批页与候选人端并发审批 | 同一申请被重复处理 | 后端已做行锁与状态前置校验，前端按错误文案提示并刷新 |
| 角标接口频繁调用 | 面试安排页加载变慢 | 仅查询 `pageSize=1` 取 total，失败静默降级 |
| 异步用例改写削弱覆盖 | 回归保障下降 | 保留原有断言意图，仅调整等待方式 |

回滚方式：按子 commit 逐个 revert；不新增数据库表，回滚不涉及迁移脚本。

## 8. 待确认事项

- 改期审批是否要求保留原排期的历史快照（是否需要新增日志表）。
