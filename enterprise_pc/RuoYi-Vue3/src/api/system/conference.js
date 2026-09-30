import request from '@/utils/request'

// ============================ 会议场次 ============================

// 当前用户进行中 / 待开始的面试场次上下文
export function getCurrentSession() {
  return request({
    url: '/system/conference/session/current',
    method: 'get'
  })
}

// 指定场次的会议上下文
export function getSessionContext(sessionId) {
  return request({
    url: '/system/conference/session/' + sessionId,
    method: 'get'
  })
}

// 会前环境检测结果上报（摄像头/麦克风/网络/扬声器 + 弱网风险标记）
export function reportEnvironmentCheck(sessionId, data) {
  return request({
    url: '/system/conference/session/' + sessionId + '/environment-check',
    method: 'post',
    data: data
  })
}

// 提交录制知情同意（1-同意，2-拒绝）
export function submitConsent(sessionId, consent) {
  return request({
    url: '/system/conference/session/' + sessionId + '/consent',
    method: 'post',
    data: { consent: consent }
  })
}

// 候选人准备就绪，进入面试
export function startSession(sessionId) {
  return request({
    url: '/system/conference/session/' + sessionId + '/start',
    method: 'post'
  })
}

// ============================ 进行中 ============================

// 面试进度与当前题目
export function getProgress(sessionId) {
  return request({
    url: '/system/conference/session/' + sessionId + '/progress',
    method: 'get'
  })
}

// 提交作答
export function submitAnswer(sessionId, data) {
  return request({
    url: '/system/conference/session/' + sessionId + '/answers',
    method: 'post',
    data: data
  })
}

// 更新音视频设备状态
export function updateMedia(sessionId, data) {
  return request({
    url: '/system/conference/session/' + sessionId + '/media',
    method: 'put',
    data: data
  })
}

// 心跳（弱网 / 断网判定）
export function heartbeat(sessionId) {
  return request({
    url: '/system/conference/session/' + sessionId + '/heartbeat',
    method: 'post'
  })
}

// 增量拉取实时字幕
export function listCaptions(sessionId, params) {
  return request({
    url: '/system/conference/session/' + sessionId + '/captions',
    method: 'get',
    params: params
  })
}

// 增量拉取提词器建议
export function listCopilot(sessionId, params) {
  return request({
    url: '/system/conference/session/' + sessionId + '/copilot',
    method: 'get',
    params: params
  })
}

// 处理提词器建议（adopt-采纳，edit-编辑后采纳，ignore-忽略）
export function handleCopilot(sessionId, id, data) {
  return request({
    url: '/system/conference/session/' + sessionId + '/copilot/' + id + '/handle',
    method: 'post',
    data: data
  })
}

// HR 接管 / 交还（start-接管，end-交还）
export function takeover(sessionId, data) {
  return request({
    url: '/system/conference/session/' + sessionId + '/takeover',
    method: 'post',
    data: data
  })
}

// ============================ 结束 / 异常 ============================

// 正常结束面试
export function finishSession(sessionId, endReason) {
  return request({
    url: '/system/conference/session/' + sessionId + '/finish',
    method: 'post',
    data: { endReason: endReason }
  })
}

// 异常终止面试（silence-长时间无有效语音，offline-断网超时）
export function abortSession(sessionId, reason) {
  return request({
    url: '/system/conference/session/' + sessionId + '/abort',
    method: 'post',
    data: { reason: reason }
  })
}

// 面试结果（时长、完成题目数、报告状态）
export function getSessionResult(sessionId) {
  return request({
    url: '/system/conference/session/' + sessionId + '/result',
    method: 'get'
  })
}

// ============================ 录制回放与存储 ============================

// 录制文件列表
export function listRecordings(params) {
  return request({
    url: '/system/conference/recordings',
    method: 'get',
    params: params
  })
}

// 存储空间占用
export function getStorageUsage() {
  return request({
    url: '/system/conference/recordings/storage',
    method: 'get'
  })
}

// 回放详情（含时间轴 / 章节打点）
export function getPlayback(sessionId) {
  return request({
    url: '/system/conference/recordings/' + sessionId,
    method: 'get'
  })
}

// 更新录制访问授权
export function updateRecordingAccess(sessionId, data) {
  return request({
    url: '/system/conference/recordings/' + sessionId + '/access',
    method: 'post',
    data: data
  })
}

// 发送下载验证码
export function sendDownloadCode(sessionId) {
  return request({
    url: '/system/conference/recordings/' + sessionId + '/download-code',
    method: 'post'
  })
}

// 校验下载验证码并返回录制地址
export function verifyDownloadCode(sessionId, code) {
  return request({
    url: '/system/conference/recordings/' + sessionId + '/download',
    method: 'post',
    data: { code: code }
  })
}

// 查询录制存储策略
export function getStoragePolicy() {
  return request({
    url: '/system/conference/storage-policy',
    method: 'get'
  })
}

// 保存录制存储策略
export function saveStoragePolicy(data) {
  return request({
    url: '/system/conference/storage-policy',
    method: 'put',
    data: data
  })
}