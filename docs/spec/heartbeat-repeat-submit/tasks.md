# 任务：会议心跳绕过前端防重（对应 spec.md）

## - [x] T1 候选人端心跳关闭防重

- 文件：`user-PC/src/api/system/conference.js`
- 函数：`heartbeat(sessionId)`（L141-146）
- 变更：请求配置增加 `headers: { repeatSubmit: false }`
- 验证：修改后返回值与调用方不变，`call()` 包装仍生效

## - [x] T2 企业端心跳关闭防重

- 文件：`enterprise_pc/RuoYi-Vue3/src/api/system/conference.js`
- 函数：`heartbeat(sessionId)`（L83-89）
- 变更：请求配置增加 `headers: { repeatSubmit: false }`
- 验证：同上，`request()` 直连不受影响

## - [x] T3 双端构建校验

- 命令（分别在 `user-PC`、`enterprise_pc/RuoYi-Vue3`）：`npm run build:prod`
- 验证：两端构建成功、无语法错误
- 结果：user-PC `✓ built in 27.42s`；企业端 `✓ built in 25.39s`；产物中 `heartbeat` 请求已带上 `repeatSubmit` 配置

## T4 运行时验证（需用户已登录会议页）

- 候选人端：打开 `conference-ai?sessionId=<id>`，观察控制台与提示框
- 企业端：打开 `ongoing` 会议页，观察控制台
- 验证：心跳警告与错误 toast 消失，心跳每 15s 正常 200

## T5 防重保护回归

- 操作：1 秒内连续触发同一写接口（如「结束面试」「打断并接管」）
- 验证：仍提示「数据正在处理，请勿重复提交」，说明全局 1s 防重未被削弱

## T6 遗留调查（仅在 T4 仍复现时执行）

- 排查 `conference-ai.vue` / `ongoing.vue` 是否被挂载两次（重复标签页、`reconnect → waiting → conference-ai` 过渡期新旧实例共存）
- 排查 `heartbeatId` 是否被重复 `setInterval`（当前仅 `onBeforeUnmount` 清理，无 `if (!heartbeatId)` 守卫）
- 范围：只收敛重复调用源，不改心跳周期与后端

## 完成标准

- T1–T5 全部通过后向用户汇报，等待用户确认后再考虑 git 提交
- 全程不触碰录制下载二次验证相关代码
