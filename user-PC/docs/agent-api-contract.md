# 智聘 AI 求职者端接口契约（v1）

**状态：** 已确认，供前端、后端与数据库设计共同执行。  
**适用范围：** `src/views/agent/pages/` 下的 20 个求职者页面；RuoYi 原有管理端接口不在本契约范围内。  
**接入地址：** 开发环境前缀为 `/dev-api/agent/v1`，由 Vite 代理到 `http://localhost:8080/agent/v1`。

> 当前页面使用静态数据和 `localStorage` 演示。本文件定义替换这些演示数据时的唯一接口口径；在后端和数据库尚未完成前，不要求修改页面行为。

## 1. 通用约定

### 1.1 鉴权与请求

除“登录与验证码”外，接口均要求：`Authorization: Bearer <candidateAccessToken>`。

- 请求、响应编码：UTF-8 JSON；文件上传使用 `multipart/form-data`。
- 资源 ID 一律为字符串（推荐 UUID / 雪花 ID 的字符串形式），前端不得以数值处理。
- 时间一律为 ISO 8601 且含时区，例如 `2026-06-18T14:30:00+08:00`。
- 金额以 `salaryMin`、`salaryMax`（人民币元/月，整数）传递；展示文案由前端格式化，不能把 `25-40K · 15薪` 作为接口主字段。
- 所有写操作支持 `X-Request-Id`；投递、预约、发送消息必须支持幂等键 `Idempotency-Key`。

### 1.2 统一响应

沿用本项目现有 `src/utils/request.js` 的 RuoYi 约定：业务成功时 `code` 为 `200`。

```json
{
  "code": 200,
  "msg": "操作成功",
  "data": {},
  "traceId": "01J..."
}
```

分页 `data` 固定为：

```json
{ "items": [], "page": 1, "size": 20, "total": 0, "hasNext": false }
```

### 1.3 统一错误码

HTTP 状态表达协议错误；响应体 `code` 表达可展示的业务错误。前端应优先展示 `msg`，必要时按下表处理。

| HTTP / code | 含义 | 前端处理 |
| --- | --- | --- |
| `400 / 40001` | 参数校验失败 | 定位字段并展示 `fieldErrors` |
| `401 / 40100` | 登录失效 | 清除会话并跳转 `/agent/login` |
| `403 / 40300` | 无资源权限 | 提示无权访问 |
| `404 / 40400` | 岗位、简历、会话等不存在 | 展示空状态并允许返回 |
| `409 / 40901` | 已投递该岗位 | 返回既有 `applicationId`，跳转投递详情 |
| `409 / 40902` | 面试时段已被占用 | 刷新可选时段 |
| `422 / 42201` | 简历不完整，无法投递 | 跳转简历编辑页 |
| `429 / 42901` | 短信或 AI 请求频繁 | 展示 `retryAfterSeconds` |
| `500 / 50000` | 未分类服务端错误 | 通用失败提示，保留 `traceId` |

参数错误示例：

```json
{
  "code": 40001,
  "msg": "请求参数不合法",
  "data": { "fieldErrors": [{ "field": "phone", "message": "请输入 11 位手机号" }] },
  "traceId": "01J..."
}
```

## 2. 核心对象

除非接口另有说明，以下为字段全集；列表接口可只返回标记为“摘要”的字段。

### 2.1 候选人 `Candidate`

```json
{
  "id": "cand_01J...",
  "phoneMasked": "138****6688",
  "name": "林晓雨",
  "avatarUrl": "https://.../avatar.png",
  "email": "lin@example.com",
  "headline": "AI 产品经理",
  "city": "上海",
  "bio": "专注 AI 产品与企业服务",
  "profileCompletion": 88,
  "createdAt": "2026-06-01T10:00:00+08:00",
  "updatedAt": "2026-06-16T10:24:00+08:00"
}
```

### 2.2 岗位 `Job`

```json
{
  "id": "job_ai_product",
  "title": "高级产品经理（AI 招聘方向）",
  "company": { "id": "company_zkr", "name": "极氪智能科技有限公司", "logoUrl": "https://...", "verified": true },
  "location": { "city": "上海", "district": "静安区", "remote": false },
  "employmentType": "FULL_TIME",
  "experience": { "minYears": 3, "maxYears": 5 },
  "education": "BACHELOR",
  "salaryMin": 25000,
  "salaryMax": 40000,
  "salaryMonths": 15,
  "tags": ["AI 产品", "急招"],
  "summary": "主导企业级 AI 招聘面试 Agent 产品方向",
  "description": ["负责需求规划与版本迭代"],
  "requirements": ["3 年以上 B 端或 AI 产品经验"],
  "status": "OPEN",
  "publishedAt": "2026-06-12T09:00:00+08:00",
  "activeAt": "2026-06-15T18:00:00+08:00",
  "isFavorited": false,
  "match": { "overall": 92, "skills": 94, "experience": 90, "education": 100, "level": "HIGH", "summary": "技能和项目方向高度匹配" }
}
```

岗位状态：`DRAFT`、`OPEN`、`CLOSED`、`EXPIRED`；仅 `OPEN` 可投递。`match` 只在登录候选人访问时返回。

### 2.3 简历 `Resume`

```json
{
  "id": "resume_ai_product",
  "name": "AI 产品方向-重点项目版",
  "isDefault": true,
  "summary": "突出 Agent、大模型应用与企业服务项目经历",
  "headline": "AI 产品经理",
  "city": "上海",
  "completion": 96,
  "skills": ["Agent", "大模型应用"],
  "educations": [{ "school": "示例大学", "major": "计算机科学", "degree": "BACHELOR", "startDate": "2015-09", "endDate": "2019-06" }],
  "experiences": [{ "company": "示例公司", "title": "产品经理", "startDate": "2021-01", "endDate": null, "description": "职责与量化成果" }],
  "attachments": [{ "id": "file_01J", "name": "resume.pdf", "url": "https://...", "mimeType": "application/pdf", "size": 123456 }],
  "usedApplicationCount": 5,
  "updatedAt": "2026-06-16T10:24:00+08:00"
}
```

### 2.4 投递 `Application`

```json
{
  "id": "app_01J...",
  "job": { "id": "job_ai_product", "title": "高级产品经理（AI 招聘方向）", "companyName": "极氪智能科技有限公司", "locationText": "上海 · 静安区", "salaryText": "25-40K · 15薪" },
  "resume": { "id": "resume_ai_product", "name": "AI 产品方向-重点项目版" },
  "status": "INTERVIEW_PENDING",
  "statusText": "待面试",
  "appliedAt": "2026-06-12T10:20:00+08:00",
  "updatedAt": "2026-06-13T09:00:00+08:00",
  "timeline": [{ "stage": "APPLIED", "state": "DONE", "title": "已投递", "description": "简历已送达企业", "occurredAt": "2026-06-12T10:20:00+08:00" }],
  "nextInterview": { "id": "interview_01J", "stage": "AI_INTERVIEW", "scheduledAt": "2026-06-18T14:30:00+08:00", "mode": "VIDEO", "status": "SCHEDULED" }
}
```

投递状态：`SUBMITTED`、`SCREENING`、`INTERVIEW_PENDING`、`INTERVIEWING`、`OFFER`、`REJECTED`、`WITHDRAWN`、`CLOSED`。状态历史只追加，不允许前端覆盖。

### 2.5 会话与消息

`Conversation` 摘要：`id`、`type`（`HR` / `AI_ASSISTANT` / `SYSTEM`）、`peer`、`job`、`lastMessage`、`unreadCount`、`pinned`、`muted`、`updatedAt`。

`Message`：`id`、`conversationId`、`senderType`（`CANDIDATE` / `HR` / `SYSTEM` / `AI`）、`contentType`（`TEXT` / `SYSTEM_CARD` / `INTERVIEW_CARD`）、`content`、`attachments`、`sentAt`、`readAt`。

## 3. 接口清单

### 3.1 登录、个人资料与文件

| 方法 | 路径 | 用途 | 请求体 / 关键参数 | `data` |
| --- | --- | --- | --- | --- |
| `POST` | `/auth/sms-codes` | 发送登录短信 | `{phone, purpose:"LOGIN"}` | `{requestId, expiresInSeconds, retryAfterSeconds}` |
| `POST` | `/auth/sessions` | 短信登录 | `{phone, code, requestId}` | `{accessToken, refreshToken, expiresInSeconds, candidate}` |
| `POST` | `/auth/tokens/refresh` | 刷新令牌 | `{refreshToken}` | 同登录令牌字段 |
| `DELETE` | `/auth/sessions/current` | 退出当前设备 | 无 | `null` |
| `GET` | `/me` | 获取个人资料 | 无 | `Candidate` |
| `PATCH` | `/me` | 保存基础资料 | `name`、`email`、`headline`、`city`、`bio` 中的任意项 | `Candidate` |
| `POST` | `/files` | 上传头像或 PDF 简历 | `file`、`purpose`（`AVATAR` / `RESUME_ATTACHMENT`） | `{id,name,url,mimeType,size}` |
| `POST` | `/me/avatar` | 绑定已上传头像 | `{fileId}` | `{avatarUrl}` |
| `GET` | `/me/security/devices` | 登录设备列表 | 无 | `[{id,name,ipMasked,lastActiveAt,current}]` |
| `DELETE` | `/me/security/devices/{deviceId}` | 下线设备 | 无 | `null` |
| `POST` | `/me/verification-codes` | 敏感操作验证码 | `{purpose:"CHANGE_PHONE"|"CHANGE_EMAIL"|"DELETE_ACCOUNT"}` | `{requestId,retryAfterSeconds}` |
| `DELETE` | `/me` | 注销账号 | `{verificationCode,requestId}` | `null` |

文件限制：头像 `image/jpeg,image/png,image/webp`，不超过 3 MB；简历附件仅 PDF，不超过 10 MB。服务端必须重新校验 MIME、大小和所属候选人。

### 3.2 岗位、企业、收藏与 AI 求职助手

| 方法 | 路径 | 用途 | 请求参数 | `data` |
| --- | --- | --- | --- | --- |
| `GET` | `/jobs` | 岗位浏览、首页推荐 | `keyword,category,city,district,employmentType,experienceMin,education,sort,page,size,recommended` | 分页 `Job` 摘要 |
| `GET` | `/system/enterprise/jobs/categories` | 岗位分类选项 | 无 | 当前在招岗位的分类名称数组 |
| `GET` | `/jobs/{jobId}` | 岗位详情 | 无 | `Job` 全量 |
| `GET` | `/jobs/{jobId}/match` | 刷新岗位匹配分 | `resumeId` 可选 | `Job.match` |
| `PUT` | `/jobs/{jobId}/favorite` | 收藏岗位 | 无 | `{favorited:true}` |
| `DELETE` | `/jobs/{jobId}/favorite` | 取消收藏 | 无 | `{favorited:false}` |
| `GET` | `/companies/{companyId}` | 企业主页 | 无 | `Company`（含简介、规模、融资、地址、标签） |
| `GET` | `/companies/{companyId}/jobs` | 企业在招岗位 | `page,size` | 分页 `Job` 摘要 |
| `PUT` | `/companies/{companyId}/follow` | 关注企业 | 无 | `{followed:true}` |
| `DELETE` | `/companies/{companyId}/follow` | 取消关注企业 | 无 | `{followed:false}` |
| `GET` | `/contacts/{contactId}` | HR 联系人主页 | 无 | `{id,name,avatarUrl,role,intro,company,openJobCount}` |
| `GET` | `/jobs/{jobId}/assistant/context` | 求职助手首屏资料 | 无 | `{job,match,focusPoints,suggestedQuestions}` |
| `POST` | `/jobs/{jobId}/assistant/messages` | 提问 AI 助手 | `{content,conversationId?}` | `{conversationId,message}` |
| `GET` | `/jobs/{jobId}/assistant/messages` | 读取 AI 助手历史 | `conversationId,cursor,size` | `{items,nextCursor}` |

### 3.3 简历与投递

| 方法 | 路径 | 用途 | 请求体 / 参数 | `data` |
| --- | --- | --- | --- | --- |
| `GET` | `/resumes` | 我的简历列表 | `page,size` | 分页 `Resume` 摘要 |
| `POST` | `/resumes` | 新建空白简历 | `{name}` | `Resume` |
| `GET` | `/resumes/{resumeId}` | 编辑页读取 | 无 | `Resume` |
| `PUT` | `/resumes/{resumeId}` | 保存整份简历 | `Resume` 中可编辑字段；须带 `version` | `Resume` |
| `POST` | `/resumes/{resumeId}/duplicate` | 复制简历 | `{name?}` | `Resume` 摘要 |
| `POST` | `/resumes/imports` | 导入已上传 PDF | `{fileId,name?}` | `{resume, parseStatus:"PENDING"}` |
| `GET` | `/jobs/{jobId}/resume-options` | 投递前简历选择 | 无 | `[{resumeId,name,summary,completion,updatedAt,matchScore,recommended}]` |
| `POST` | `/applications` | 提交投递 | `{jobId,resumeId,consentVersion}` | `Application` |
| `GET` | `/applications` | 投递跟踪列表 | `status,page,size` | 分页 `Application` 摘要 |
| `GET` | `/applications/{applicationId}` | 投递详情与进度 | 无 | `Application` |
| `POST` | `/applications/{applicationId}/withdrawal` | 撤回投递 | `{reason?}` | `Application` |

`PUT /resumes/{resumeId}` 的并发控制：请求必须传 `version`；版本过期返回 `409 / 40903` 与最新 `Resume`，禁止静默覆盖。

### 3.4 面试与模拟面试

| 方法 | 路径 | 用途 | 请求体 / 参数 | `data` |
| --- | --- | --- | --- | --- |
| `GET` | `/interviews/{interviewId}` | 邀请、确认和结果页资料 | 无 | `Interview` |
| `POST` | `/interviews/{interviewId}/response` | 接受或婉拒邀请 | `{action:"ACCEPT"|"DECLINE",reason?}` | `Interview` |
| `GET` | `/interviews/{interviewId}/slots` | 可预约时段 | `from,to` 可选 | `[{id,startAt,endAt,capacity,available,recommended}]` |
| `POST` | `/interviews/{interviewId}/booking` | 确认预约 | `{slotId}` | `Interview` |
| `POST` | `/interviews/{interviewId}/check-in` | 设备检测通过后签到 | `{cameraReady,microphoneReady,consent:true}` | `{roomId,joinUrl,expiresAt}` |
| `GET` | `/interview-rooms/{roomId}` | 获取真实面试房间元数据 | 无 | `{roomId,interview,provider,joinToken,expiresAt}` |
| `POST` | `/mock-interviews` | 创建模拟面试 | `{jobId,resumeId?,mode:"TEXT"|"VOICE"}` | `{id,questions:[{id,competency,title,tips}],expiresAt}` |
| `PUT` | `/mock-interviews/{id}/answers/{questionId}` | 自动保存一道答案 | `{content,skipped}` | `{savedAt}` |
| `POST` | `/mock-interviews/{id}/complete` | 完成模拟面试 | 无 | `{score,answeredCount,skippedCount,feedback,reportId}` |
| `GET` | `/mock-interviews/{id}` | 恢复未完成模拟 | 无 | `{status,questions,answers,remainingSeconds}` |

`Interview` 最少含：`id`、`applicationId`、`stage`（`AI_INTERVIEW` / `HR_INTERVIEW`）、`mode`（`VIDEO` / `ONSITE`）、`status`（`INVITED` / `SCHEDULED` / `CHECKED_IN` / `COMPLETED` / `DECLINED` / `CANCELLED`）、`scheduledAt`、`durationMinutes`、`contact`、`meetingUrl?`。

浏览器的摄像头、麦克风、屏幕共享权限由浏览器 API 管理，不上报设备原始流或权限信息；`check-in` 仅提交候选人已准备状态。真实音视频通话使用独立的音视频服务及短期 `joinToken`，不通过业务接口传输媒体数据。

### 3.5 消息、通知和视频面试聊天

| 方法 | 路径 | 用途 | 请求体 / 参数 | `data` |
| --- | --- | --- | --- | --- |
| `GET` | `/conversations` | 会话列表 | `type,page,size` | 分页 `Conversation` |
| `GET` | `/conversations/{conversationId}/messages` | 历史消息 | `cursor,size` | `{items:Message[],nextCursor}` |
| `POST` | `/conversations/{conversationId}/messages` | 发送文本消息 | `{content,clientMessageId}` | `Message` |
| `POST` | `/conversations/{conversationId}/read` | 已读到指定消息 | `{lastReadMessageId}` | `{unreadCount:0}` |
| `PATCH` | `/conversations/{conversationId}/settings` | 置顶、免打扰 | `{pinned?,muted?}` | `Conversation` |
| `GET` | `/notifications` | 系统通知列表 | `read?,page,size` | 分页 `Notification` |
| `GET` | `/notifications/unread-count` | 顶栏未读数 | 无 | `{count}` |
| `POST` | `/notifications/read` | 全部或指定已读 | `{ids?:[]}` | `{count}` |
| `GET` | `/video-meetings/{meetingId}` | 视频面试会议信息 | 无 | `{meetingId,title,host,participants,joinToken,expiresAt}` |
| `POST` | `/video-meetings/{meetingId}/chat-messages` | 会议聊天消息 | `{content,clientMessageId}` | `Message` |

消息列表按 `sentAt` 升序返回；游标使用不透明字符串，前端不解析。发送接口应以 `clientMessageId` 去重，以避免断网重试重复发言。

## 4. 页面到接口映射

| 页面路由 | 首屏读取 | 用户写操作 |
| --- | --- | --- |
| `/agent/login` | 无 | 短信验证码、创建会话 |
| `/agent/index` | `/me`、`/jobs?recommended=true`、`/applications`、未读数 | 收藏、跳转投递 |
| `/agent/jobs` | `/jobs` | 收藏岗位 |
| `/agent/job-detail` | `/jobs/{jobId}` | 收藏、进入投递、AI 助手 |
| `/agent/job-assistant` | assistant context、历史消息 | 发送 AI 消息 |
| `/agent/resume-select` | `/jobs/{jobId}/resume-options` | `POST /applications` |
| `/agent/applications` | `/applications` | 筛选（仅客户端参数变化） |
| `/agent/application-detail` | `/applications/{id}` | 面试邀请流程入口 |
| `/agent/messages` | `/conversations`、消息、通知未读数 | 发消息、已读、置顶/免打扰 |
| `/agent/company-profile` | 公司、公司在招岗位 | 关注企业 |
| `/agent/contact-profile` | 联系人资料 | 无 |
| `/agent/profile` | `/me`、`/resumes`、设备列表 | 更新资料、上传头像/PDF、复制/新建简历、设备管理、注销 |
| `/agent/resume-editor` | `/resumes/{id}` | 保存简历 |
| `/agent/interview-invitation` | `/interviews/{id}` | 接受/婉拒 |
| `/agent/interview-schedule` | 面试时段 | 创建预约 |
| `/agent/interview-check` | 面试资料 | 签到 |
| `/agent/interview-room` | 面试房间元数据 | 由音视频服务处理 |
| `/agent/interview-result` | `/interviews/{id}` | 评价接口可在后续版本补充 |
| `/agent/mock-interview` | 新建或恢复模拟 | 自动保存回答、完成模拟 |
| `/agent/video-meeting` | 会议信息、会话消息 | 会议聊天；媒体流由音视频服务处理 |

## 5. 前后端接入顺序

1. 后端先实现 `/auth`、`/me`、`/jobs`、`/resumes`、`/applications`，即可替换登录、岗位和投递主流程的 Mock。
2. 再实现 `/conversations` 与 `/notifications`，接入消息中心。
3. 最后接入面试、AI 助手与音视频供应商；这些接口必须保持本文件的资源模型和状态枚举。
4. 前端新增 `src/api/agent/` 模块逐页替换页面内静态对象和 `localStorage`。在 `.env.development` 中将 `VITE_FRONTEND_ONLY` 改为 `'false'` 前，必须完成上述主流程的接口联调。

## 6. 数据库设计交接要点

后端建表至少需覆盖：`candidate`、`candidate_device`、`file_asset`、`company`、`job`、`job_favorite`、`company_follow`、`resume`、`resume_education`、`resume_experience`、`resume_skill`、`application`、`application_timeline`、`interview`、`interview_slot`、`interview_booking`、`mock_interview`、`mock_interview_answer`、`conversation`、`conversation_member`、`message`、`notification`。

必须保证的约束：

- `application` 对 `(candidate_id, job_id)` 在未撤回状态下唯一，重复投递返回 `40901` 与已有投递 ID。
- `interview_booking.slot_id` 在有效预约中唯一；并发预约必须由数据库事务保证，冲突返回 `40902`。
- 所有候选人私有资源都按 `candidate_id` 鉴权，不能仅凭资源 ID 访问。
- 简历、投递进度、面试状态保留历史或版本号，不直接覆盖审计字段。
- 文件表须记录上传者、用途、校验后的 MIME、大小和存储键；禁止直接信任客户端 URL。
