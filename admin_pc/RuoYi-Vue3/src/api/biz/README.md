# A-PC 核心业务 API

`src/api/biz` 承载招聘与业务流程相关接口。每个资源一个文件，文件名与
资源保持稳定对应，页面不得跨资源文件调用未登记的接口。

| 资源 | 文件 | URL 根路径 | 权限码前缀 |
|---|---|---|---|
| 候选人 | `candidate.js` | `/biz/candidate` | `biz:candidate:*` |
| 企业业务 | `business.js` | `/biz/business` | `biz:business:*` |
| 职位 | `job.js` | `/biz/job` | `biz:job:*` |
| 简历 | `resume.js` | `/biz/resume` | `biz:resume:*` |
| 简历解析 | `resumeParse.js` | `/biz/resumeParse` | `biz:resumeParse:*` |
| 面试 | `interview.js` | `/biz/interview` | `biz:interview:*` |
| 面试评估 | `interviewEval.js` | `/biz/interviewEval` | `biz:interviewEval:*` |
| 排期 | `schedule.js` | `/biz/schedule` | `biz:schedule:*` |
| 考试 | `exam.js` | `/biz/exam` | `biz:exam:*` |
| AI 筛选 | `aiScreen.js` | `/biz/aiScreen` | `biz:aiScreen:*` |

## 标准函数

```js
listResource(query)
getResource(id)
addResource(data)
updateResource(data)
delResource(ids)
updateResourceStatus(data)
```

业务特有动作使用明确动词，例如：

```js
auditJob(data)
runAiScreen(data)
finalizeInterviewEval(data)
```

## 兼容说明

当前仓库已有 `aiScreen.js`、`resumeParse.js`、`interviewEval.js` 等历史
camelCase 文件和权限码。它们属于现行兼容名称；新模块优先采用项目后端
已确认的资源名，不在没有接口迁移方案时批量重命名。
