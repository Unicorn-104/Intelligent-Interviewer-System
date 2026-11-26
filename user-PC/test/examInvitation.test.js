import test from 'node:test'
import assert from 'node:assert/strict'
import { parseExamInvitation } from '../src/utils/examInvitation.js'

const absolute = '【笔试邀请·Java后端笔试试卷】Java工程师，作答时间 2026-11-26 10:00 ~ 2026-11-26 11:00，试卷时长 60 分钟。请点击链接进入：https://app.local/user/exam?scheduleId=12'

test('解析笔试邀请卡片并提取试卷、说明和场次', () => {
  assert.deepEqual(parseExamInvitation(absolute), {
    scheduleId: 12,
    paperName: 'Java后端笔试试卷',
    detail: 'Java工程师，作答时间 2026-11-26 10:00 ~ 2026-11-26 11:00，试卷时长 60 分钟'
  })
  assert.deepEqual(parseExamInvitation(absolute.replace('https://app.local/user/exam', '/exam')), {
    scheduleId: 12,
    paperName: 'Java后端笔试试卷',
    detail: 'Java工程师，作答时间 2026-11-26 10:00 ~ 2026-11-26 11:00，试卷时长 60 分钟'
  })
})

test('拒绝非笔试邀请、非 /exam 链接和非法场次', () => {
  assert.equal(parseExamInvitation('普通聊天消息'), null)
  assert.equal(parseExamInvitation(absolute.replace('/exam?', '/jobs?')), null)
  assert.equal(parseExamInvitation(absolute.replace('scheduleId=12', 'scheduleId=abc')), null)
  assert.equal(parseExamInvitation(absolute.replace('scheduleId=12', 'scheduleId=0')), null)
  assert.equal(parseExamInvitation('【笔试邀请】没有链接'), null)
  assert.equal(parseExamInvitation(undefined), null)
})
