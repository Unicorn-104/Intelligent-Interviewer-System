# 企业端未完成功能开发计划

> 适用范围：`enterprise_pc/RuoYi-Vue3`（企业端）与 `backend/`（RuoYi 后端）
> 编写依据：2026-10-22 企业端全量盘点结果，以及已完成联调的面试评估链路
> 目标：把当前「已完成/半成品/未开始」的功能补齐为可验收的完整闭环

## 1. 现状盘点

| 编号 | 功能 | 现状 | 缺口 |
| --- | --- | --- | --- |
| A | 面试评估与入口 | 基本完成 | 终面/非终面判定无 UI；评估→Offer 未打通 |
| B | 候选人流程页 | 未开始 | 整页 `reserveApi` 假数据 |
| C1 | JD 文件解析 | 已完成 | — |
| C2 | 已发布岗位编辑 | 后端就绪 | 列表/详情无编辑入口 |
| C3 | AI 解析 JD（文本） | 后端就绪 | 按钮 `disabled` 未接线 |
| C4 | 复制岗位 | 未开始 | 后端无 duplicate 接口 |
| D1 | Offer 审批 | 未开始 | 后端无审批接口，前端无操作 |
| D2 | Offer 撤回 | 未开始 | 后端无 withdraw 接口 |
| D3 | 简历批量导入 | 未开始 | 前后端均无实现 |
| D4 | 空闲时间写库 | 未开始 | 仅本地标记，后端无接口 |
| D5 | 硬编码/假数据清理 | 部分完成 | 流程页、批量标签、导入简历 |

### 已确认可复用的接口与数据表

- 评估：`/enterprise/review/list|{sessionId}|confirm|adjust|reject|cascade`
- 候选人：`GET /enterprise/talent/{talId}`、`GET /enterprise/talent/{talId}/resume`
- 面试：`GET /enterprise/interview/list`（**当前不支持 candidateId 过滤**）、
  `GET /enterprise/interview/candidate-plan?candidateId&positionId`、
  `POST /enterprise/interview/invite/stages`、`PUT /enterprise/interview/{appointmentId}/status`
- 岗位：`POST/PUT/GET/DELETE /system/enterprise/jobs`、`POST /enterprise/jd/parse`（文本）、
  `POST /enterprise/jd/parse-document`（文件）
- Offer：`POST /enterprise/offer/{sessionId}/trigger`、`/list`、`/{offerId}`、`/create`、`/{offerId}/send`
- 面试官时段表：`t_sch_slot`（`slt_interviewer_id/start_time/end_time/status`）
- Offer 审批表：`t_offer_approval`（节点、审批人、状态 0-3）
- Offer 主表：`t_off_offer`（`ofr_status` 0-6、`ofr_approval_status` 0-3、`ofr_withdraw_reason/at`）
- 简历：`t_res_base`（`rbs_user_id/rbs_file_path/rbs_file_name/rbs_file_size`）+ `t_res_*` 子表
- 候选人侧简历解析：`POST /app/resumes/parse-pdf`、`POST /app/resumes/import-pdf`（可抽取公共服务复用）

**结论：本计划不需要新增数据库表**，只做字段读写与接口补齐；如确需调整，同步更新 `sql/` 对应模块脚本。

## 2. 通用约定

- 分支：从最新 `origin/dev` 创建 `feature/enterprise-completion-MZR`；一个子功能一个 commit，完成后统一 PR 到 `dev`。
- 企业隔离：所有新增查询/写操作必须先经 `DashboardMapper.selectCompanyIdByUser(userId)` 解析企业 ID，并在 SQL 中作为过滤条件。
- 页面必须使用真实接口数据，接口无数据时展示空态，禁止再新增 `reserveApi` 假成功。
- 后端只改本模块代码；跨模块能力只调用已有 Service 方法。
- 每个子功能完成后的固定验收：
  - 后端：`mvn -pl ruoyi-system,ruoyi-admin -am compile`
  - 依赖刷新：`mvn -q -DskipTests install`
  - 前端：`npm run build:prod`
  - 联调：真实登录后操作，检查网络请求与数据库写入结果

---

## 3. 阶段一：补齐「面试 → 评估 → 流转」闭环

### 3.1 终面/非终面判定与级联流转

**现状**：`evaluation.vue` 的确认逻辑不传 `isFinal`，后端恒按终面返回；后端 `confirm` 已支持 `isFinal=false` 触发级联，`/{sessionId}/cascade` 也可单独调用。

**改动**
- 前端 `views/enterprise/interviews/evaluation.vue`
  - 增加「结果类型」单选：终面 / 非终面（默认按场次轮次推导：`round` 与流程模板总轮次比较，取不到时默认终面）。
  - `publish()` 请求体增加 `isFinal`。
  - 「非终面」确认成功后展示级联结果：下一轮轮次、建议时间，或「未达阈值已按淘汰处理」。
- 后端无需新增接口，仅校验 `confirm` 的 `isFinal` 透传正确（现实现已具备）。

**验收**
- 非终面确认后：`t_sch_appointment` 新增一条下一轮预约；`t_msg`（消息表）新增邀请消息；评估页展示级联结果。
- 终面确认后：返回「请前往 Offer 管理」提示，无级联记录。

### 3.2 评估通过 → 生成 Offer

**现状**：后端 `POST /enterprise/offer/{sessionId}/trigger` 已存在；前端 `api/offer.js` 无对应方法。

**改动**
- `api/offer.js` 新增 `triggerOffer(sessionId, data)`。
- `evaluation.vue`：终面确认成功后，提供「生成录用意向书」按钮（或确认后自动触发一次，失败可重试），成功跳转 `/enterprise/offer`。
- `offer/index.vue`：无需改动列表结构，确认 trigger 生成的草稿可被现有 `getOffer` 正常展示。

**验收**
- 终面确认 → 触发 → `t_off_offer` 新增草稿（`ofr_status=4`）。
- Offer 列表可见该条记录，详情可打开。

### 3.3 入口补全

**现状**：面试安排抽屉（`status==='completed'`）与回放页入口已可用。

**改动**
- 回放页在无 `sessionId` 时保持提示即可，无需新增。
- 面试安排抽屉增加「已终审」标识（`hrStatus`），避免 HR 重复进入。

**验收**：已完成场次可从两个入口进入评估页；已终审记录显示状态徽标。

---

## 4. 阶段二：候选人流程页真实化（B）

**现状**：`views/enterprise/candidates/process.vue` 引用 `views/enterprise/api/contract` 的 `reserveApi`，排期/推进均为假动作，页面数据为静态。

**数据拼装（按用户指定方案）**
1. `getTalentDetail(talId)` → 候选人基本信息
2. `getTalentResume(talId)` → 简历（教育/工作/项目/技能）
3. 面试记录 → `listInterviews`（**需补 candidateId 过滤**）

**改动**
- 后端
  - `InterviewScheduleController.list` 增加可选参数 `candidateId`；`InterviewScheduleMapper.xml` 列表 SQL 增加 `a.apt_candidate_id = #{candidateId}` 条件；`scheduleService.listAppointments` 透传。
  - 阶段流转接口：优先复用 `POST /enterprise/interview/invite/stages`（下一阶段排期）。
    若产品要求「仅推进阶段、不排期」，新增 `PUT /enterprise/talent/{talId}/stage`（写 `t_tal_status_log` + 更新候选人阶段字段），不新增表。
- 前端 `process.vue`
  - 删除 `contract`/`reserveApi` 引用，改为真实接口并行加载，三块区域分别有空态。
  - 「下一阶段排期」→ 调 `invite/stages`（弹窗选面试阶段与时间）。
  - 「阶段流转」→ 调阶段接口，成功后刷新。
  - 失败时按接口 `msg` 提示，不做本地假更新。

**验收**
- 打开 `/enterprise/candidates/{talId}/process` 显示真实姓名、岗位、简历明细、历史面试列表。
- 触发排期后 `t_sch_appointment` 新增记录；触发流转后 `t_tal_status_log` 新增记录。
- 全局搜索确认该页无 `reserveApi`。

---

## 5. 阶段三：岗位编辑/复制 + JD 文本解析（C2/C3/C4）

### 5.1 已发布岗位编辑

**改动**
- `components/PublishJobModal.vue` 增加 `edit` 模式：接收 `positionId` 与初始表单，标题/按钮文案切换为「保存修改」，提交走 `updateJob`。
- `jobs/index.vue`、`jobs/detail.vue` 增加「编辑」按钮，打开该弹窗并传入 `jobDetail` 数据。
- 不改动岗位状态与流程模板（与后端 update 语义保持一致）。

**验收**：编辑标题/薪资后保存，列表与详情立即刷新为新值；状态不变。

### 5.2 复制岗位

**改动**
- 后端 `EnterpriseJobController` 新增 `POST /system/enterprise/jobs/{posId}/duplicate`
  - 复制 `t_pos` 主体（标题加「（副本）」，状态强制草稿）
  - 复制 `t_pos_skill` 技能关联
  - 返回新 `posId`
- `api/system/job.js` 新增 `duplicateJob(posId)`；`jobs/index.vue` 操作列增加「复制」。
- 复制完成后提示并跳转新岗位编辑弹窗。

**验收**：复制后出现新的草稿岗位，技能与原岗位一致；原岗位不受影响。

### 5.3 AI 解析 JD（文本）

**改动**
- `api` 增加文本解析方法（`POST /enterprise/jd/parse`，body `{ positionId?, jdText }`）。
- `PublishJobModal.vue` 将底部 `disabled` 的「AI 智能解析 JD」按钮启用：
  - 点击后取表单中的 JD 文本框内容发起解析
  - 解析结果回填标题、技能、职责、要求等字段
  - 空文本时提示「请先粘贴 JD 内容」
- 解析失败按接口 `msg` 提示，保留用户已填内容。

**验收**：粘贴一段 JD → 点击解析 → 表单字段被填充；接口异常时表单内容不丢失。

---

## 6. 阶段四：Offer 审批/撤回、简历批量导入、空闲时间、假数据清理

### 6.1 Offer 审批

**现状**：后端只有 trigger/list/detail/create/send；`t_offer_approval` 与 `ofr_approval_status` 字段已存在，页面仅展示状态无操作。

**改动**
- 后端 `OfferController` 新增
  - `POST /{offerId}/approval/start`：按企业审批配置生成 `t_offer_approval` 节点（无配置时生成单节点），`ofr_approval_status=1`、`ofr_status=5`
  - `POST /{offerId}/approval/approve`：校验当前用户为待审批节点审批人，写节点状态 1 + 意见 + 时间；全部节点通过则 `ofr_approval_status=2`、`ofr_status=4`（可发送）
  - `POST /{offerId}/approval/reject`：节点状态 2，`ofr_approval_status=3`、`ofr_status=4`，记录意见
  - `GET /{offerId}/approvals`：节点列表（详情接口已包含时可不加）
- 新增 `OfferApprovalMapper` + XML（查询节点、更新节点、按 Offer 汇总）
- 前端 `offer/index.vue`
  - 操作列按状态显示「提交审批 / 通过 / 拒绝」
  - 通过/拒绝弹窗填写意见
  - 详情弹窗复用已有审批节点区块，刷新后显示最新节点状态

**验收**
- 草稿 → 提交审批 → `ofr_status=5`、节点生成 → 通过 → `ofr_approval_status=2`、可发送。
- 拒绝 → `ofr_approval_status=3`，节点状态 2，意见落库。
- 非审批人调用通过/拒绝返回 403 或业务错误。

### 6.2 Offer 撤回

**改动**
- 后端 `POST /{offerId}/withdraw`：仅 `ofr_status=0`（已发送）可撤回；写 `ofr_withdraw_reason`、`ofr_withdraw_at`，`ofr_status=6`，并向候选人发送站内消息。
- 前端操作列增加「撤回」，弹窗必填原因；撤回后状态徽标变「已撤回」并展示原因。

**验收**：撤回后数据库三字段正确；候选人收到消息；已接受/已过期状态不可撤回（返回业务错误）。

### 6.3 简历批量导入

**现状**：`candidates/index.vue` 的 `importResume()` 调用 `reserveApi` 并提示「已预留接口」；后端无企业侧导入接口。

**改动**
- 后端
  - 抽取候选人侧 `AppResumeService` 的 PDF 解析入库逻辑为公共方法（不改变原接口行为）。
  - 新增 `POST /enterprise/resumes/batch-import`（multipart：`files[]`、`positionId`、`deduplicate`）
    - 校验文件类型与大小，逐文件解析
    - 去重键：手机号 → 邮箱 → 姓名+简历文件名
    - 返回每条结果：`fileName / status(success|duplicate|failed) / message / talId`
    - 企业归属：导入的候选人绑定当前企业
- 前端 `candidates/index.vue`
  - 「导入简历」打开弹窗：多选文件、选择目标岗位、去重开关
  - 展示逐文件结果列表，成功数量与失败原因
  - 导入完成后刷新候选人列表
- 删除 `reserveApi` 调用与「已预留接口」文案。

**验收**
- 上传 2 份新 PDF + 1 份重复 PDF：分别返回 success/duplicate，`t_res_base`、`t_tal` 数据正确，重复文件不落库。
- 非 PDF/DOCX 被拒绝并给出原因。

### 6.4 空闲时间写入数据库

**现状**：`interviews/index.vue` 的 `saveFree()` 仅 `calendar.toggleBlocked()` + 提示「已更新本地空闲标记」；后端无接口。

**改动**
- 后端新增 `InterviewerSlotController`（`/enterprise/interviewer-slots`）
  - `GET ?weekStart=`：返回当前登录用户当周时段（跨企业不可见）
  - `POST`：批量保存一周时段（body：`[{startTime,endTime}]`），同一用户同一周先删后插，状态默认 1-可用
  - `DELETE /{sltId}`：删除自己的时段（他人时段拒绝）
  - Mapper 直接读写 `t_sch_slot`，`slt_interviewer_id` 使用当前登录用户 ID
- 前端 `interviews/index.vue`
  - 进入页面加载本周时段，用于渲染 `blocked` 格子
  - `saveFree()` 改为调用保存接口，成功提示「空闲时间已保存」，失败提示后端 `msg`
  - 弹窗中展示真实已保存时段，取消勾选即从数据库删除

**验收**
- 保存后刷新页面时段仍存在；`t_sch_slot` 有对应记录。
- 删除后记录消失；跨用户不可删除（返回业务错误）。

### 6.5 假数据与占位清理

**范围**
- `candidates/process.vue`（阶段二已解决）
- `candidates/index.vue`：`importResume`（6.3 解决）、`batchTag`（见下）
- `views/enterprise/api/contract.js`：已实现的占位条目移除或标注「已接入」，只保留确无后端能力的契约

**批量加标签处理**
- 现状：`batchTag()` 走 `reserveApi` 假成功，后端无标签批量接口。
- 方案（二选一，开发前确认）：
  1. 若本迭代需要：新增 `POST /enterprise/talent/tags/batch`（写 `t_tal_tag`），前端接真实接口；
  2. 若不需要：隐藏该按钮，避免假成功误导。
- 默认按方案 1 实现，工作量小且表已存在。

**验收**：全局搜索 `reserveApi`，仅剩未启用契约占位；页面不再出现「已预留接口」类提示。

---

## 7. 建议提交拆分（Conventional Commits）

1. `feat(review): 终面判定与级联流转前端接线`
2. `feat(offer): 评估通过后触发 Offer 生成`
3. `feat(talent): 候选人流程页接入真实简历与面试数据`
4. `feat(job): 已发布岗位编辑入口`
5. `feat(job): 岗位复制接口与前端操作`
6. `feat(job): JD 文本智能解析按钮接线`
7. `feat(offer): Offer 审批提交/通过/拒绝`
8. `feat(offer): Offer 撤回`
9. `feat(resume): 企业端简历批量导入`
10. `feat(schedule): 面试官空闲时间持久化`
11. `chore(enterprise): 清理假数据与占位接口`

提交顺序按阶段一 → 四执行；每个 commit 只包含对应子功能，禁止夹带无关文件。

## 8. 联调与验收清单

- [ ] 按阶段逐项完成，每完成一项立即联调，不等到最终统一验证
- [ ] 后端 `mvn -pl ruoyi-system,ruoyi-admin -am compile` 通过
- [ ] `mvn -q -DskipTests install` 通过（避免依赖模块旧 jar）
- [ ] 前端 `npm run build:prod` 通过
- [ ] 数据库核对：`t_sch_appointment`、`t_off_offer`、`t_offer_approval`、`t_sch_slot`、`t_res_base`、`t_tal_status_log`
- [ ] 企业隔离抽查：A 企业账号访问 B 企业数据一律返回业务错误
- [ ] 无明文凭据、无构建产物、无 `application*.yml` 入库

## 9. 风险与回滚

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| 级联规则未配置（`t_int_cascade_rule`） | 非终面确认后无下一轮 | 返回明确提示，不写脏数据；由 HR 手工排期 |
| 审批流配置缺失 | 审批节点生成失败 | 无配置时生成单节点兜底，仍可流转 |
| PDF 解析耗时/失败 | 批量导入部分失败 | 逐文件返回结果，允许重试失败项 |
| 空闲时段与已占用冲突 | 保存后仍被预约 | 保存时跳过或标记已占用（`slt_status=0`） |
| 远程数据库为共享环境 | 联调测试污染数据 | 测试前记录原值，测试后还原；禁止批量删改 |

回滚方式：功能均按子 commit 拆分，可按 commit 逐个 revert；无数据库结构变更，回滚不涉及迁移脚本。
