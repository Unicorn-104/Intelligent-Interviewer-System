# 规格：候选人/企业端会议心跳被前端防重拦截

## 1. 问题现象

候选人会议页（`localhost:5180/agent/conference-ai?sessionId=57`）控制台出现：

```
request.js:75  [/system/conference/session/57/heartbeat]: 数据正在处理，请勿重复提交
request.js:125 errError: 数据正在处理，请勿重复提交
```

并伴随红色错误提示框。

## 2. 根因（已定位，非后端问题）

1. 文案来源是**前端防重复提交拦截器**，不是后端返回：
   - [request.js](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/user-PC/src/utils/request.js#L54-L81) 请求拦截器：对所有 `POST/PUT`（非 `FormData`）把 `{url, data, time}` 写入 `sessionStorage` 的 `sessionObj`；
   - 若与上一次 POST/PUT 的 `url` 与 `data` 完全相同、且间隔 `< interval`（默认 `1000ms`），直接 `Promise.reject(new Error('数据正在处理，请勿重复提交'))`（L74-76）；
   - 被拒的 Promise 落到响应拦截器的错误分支 [request.js](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/user-PC/src/utils/request.js#L124-L135)，`ElMessage` 弹出同文案错误框，并打印 `errError`。
2. 后端没有该文案，`ConferenceController` 的心跳接口也未加 `@RepeatSubmit`，因此与后端限流/防重无关。
3. 心跳是**幂等**的空 body `POST`：
   - [conference.js（候选人端）](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/user-PC/src/api/system/conference.js#L141-L146)
   - [conference.js（企业端）](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/enterprise_pc/RuoYi-Vue3/src/api/system/conference.js#L83-L89)
   两处都没有设置 `headers.repeatSubmit = false`，而项目内已有此约定（`login.js` 的登录接口就是这么关闭防重的）。

结论：只要两次内容相同的心跳请求在 1 秒内先后发出，就会被前端拦截并弹框；心跳重复发送本身无副作用，不应该受该保护。

## 3. 目标与非目标

**目标**

- 心跳请求不再触发前端防重复拦截：控制台无该 `console.warn`，无错误 toast。
- 其他有副作用的写接口（提交作答、接管、结束面试、保存策略等）的防重保护**保持不变**。

**非目标**

- 不修改后端任何代码。
- 不修改 `request.js` 的全局防重逻辑与默认 `1000ms` 间隔。
- 不调整心跳周期（当前 15s）。
- 不改动「录制下载二次验证」（用户已明确暂不改）。
- 不提交 git（等用户验证通过后再提交）。

## 4. 变更方案（最小改动）

在两个 API 定义处给心跳单独关闭防重，与 `login.js` 的写法一致：

| 文件 | 函数 | 变更 |
|---|---|---|
| [conference.js（候选人端）](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/user-PC/src/api/system/conference.js#L141-L146) | `heartbeat(sessionId)` | 增加 `headers: { repeatSubmit: false }` |
| [conference.js（企业端）](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/enterprise_pc/RuoYi-Vue3/src/api/system/conference.js#L83-L89) | `heartbeat(sessionId)` | 增加 `headers: { repeatSubmit: false }` |

不新增文件、不改动调用点（`conference-ai.vue:760`、`ongoing.vue:842`、`conference-reconnect.vue:89` 均无需改）。

## 5. 触发源说明与遗留观察项

当前代码中心跳只有三处触发：

- `conference-ai.vue:760`：每 15s 一次；
- `ongoing.vue:842`：每 15s 一次；
- `conference-reconnect.vue:89`：重连成功后补发一次。

按代码路径，单实例页面不应出现 1 秒内两次心跳。实际复现说明存在**重复调用源**，最可能是同类页面被挂载两次（重复标签页，或 `reconnect → waiting → conference-ai` 过渡期间新旧实例短暂共存）。本次修复先消除用户可见的错误提示；若修复后仍能复现，再按 `tasks.md` 的调查项定位重复挂载，不在此规格内扩大改动范围。

## 6. 验证标准

1. 候选人端会议页：控制台不再出现 `[/system/conference/session/{id}/heartbeat]: 数据正在处理，请勿重复提交`，无红色错误提示；Network 中心跳每 15s 返回 200。
2. 企业端会议页（`ongoing.vue`）：同样无该提示。
3. 回归：1 秒内重复点击「结束会议」「打断并接管」等写操作，仍会被防重拦截（说明全局保护未被削弱）。
4. 构建：`user-PC` 与 `enterprise_pc/RuoYi-Vue3` 均 `npm run build:prod` 成功。

## 7. 影响面与回滚

- 影响面：仅心跳接口绕过前端 1s 防重，幂等接口，无数据风险。
- 回滚：删除两处 `headers: { repeatSubmit: false }` 即可恢复原状。
