import request from '@/utils/request'

// 我的考试列表（投递岗位对应的笔试安排）
export function listMyExams() {
  return request({ url: '/candidate/exam/list', method: 'get' })
}

// 考试入口详情（不含题目）
export function getExamEntry(scheduleId) {
  return request({ url: '/candidate/exam/schedule/' + scheduleId, method: 'get' })
}

// 开始/续考：返回题目快照与剩余秒数（幂等，断网重进同样调用）
export function startExam(scheduleId) {
  return request({ url: '/candidate/exam/schedule/' + scheduleId + '/start', method: 'post' })
}

// 自动保存作答
export function saveExamAnswers(recordId, answers) {
  return request({ url: '/candidate/exam/record/' + recordId + '/save', method: 'post', data: { answers } })
}

// 交卷
export function submitExam(recordId, answers) {
  return request({ url: '/candidate/exam/record/' + recordId + '/submit', method: 'post', data: { answers } })
}

// 双机位监考信息：主机位入会令牌 + 副机位接入码/二维码地址 + 副机位状态
export function getExamMonitor(recordId) {
  return request({ url: '/candidate/exam/record/' + recordId + '/monitor', method: 'get' })
}

// 副机位H5（匿名）：凭接入码换取入会令牌
export function subJoin(data) {
  return request({ url: '/candidate/exam/sub/join', method: 'post', data })
}

// 副机位H5（匿名）：心跳保活
export function subPing(data) {
  return request({ url: '/candidate/exam/sub/ping', method: 'post', data })
}

// 副机位H5（匿名）：离开标记
export function subLeave(data) {
  return request({ url: '/candidate/exam/sub/leave', method: 'post', data })
}
