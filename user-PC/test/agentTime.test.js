import test from 'node:test'
import assert from 'node:assert/strict'
import { formatMessageTime, formatShortTime, parseMessageDate } from '../src/utils/agentTime.js'

test('无时区后端时间按北京时间解释，不重复加八小时', () => {
  for (const value of ['2026-11-02 09:39:00', '2026-11-02T09:39:00', '2026-11-02 09:39']) {
    assert.equal(formatMessageTime(value), '11/02 09:39')
    assert.equal(parseMessageDate(value).toISOString(), '2026-11-02T01:39:00.000Z')
  }
  assert.equal(parseMessageDate('2026-11-02 09:39:00.123').toISOString(), '2026-11-02T01:39:00.123Z')
})

test('UTC、显式偏移与时间戳均显示同一北京时间', () => {
  const instant = Date.parse('2026-11-02T01:39:00Z')
  for (const value of ['2026-11-02T01:39:00Z', '2026-11-02T09:39:00+08:00', '2026-11-02T10:39:00+09:00', instant, instant / 1000, String(instant), new Date(instant)]) {
    assert.equal(formatMessageTime(value), '11/02 09:39')
  }
})

test('今天和跨日以北京日期判断，午夜显示 00 而非 24', () => {
  assert.equal(formatMessageTime('2026-11-01T16:00:00Z'), '11/02 00:00')
  assert.equal(formatShortTime('2026-11-02 00:10:00', '2026-11-01T16:30:00Z'), '00:10')
  assert.equal(formatShortTime('2026-11-01 23:59:00', '2026-11-01T16:30:00Z'), '11-01')
  assert.equal(formatShortTime('2025-11-02 00:10:00', '2026-11-01T16:30:00Z'), '11-02')
})

test('空值和无效时间显示占位，不影响消息渲染', () => {
  for (const value of [null, undefined, '', ' ', 'invalid', '2026-13-02 09:39:00', {}, new Date(NaN)]) {
    assert.equal(formatMessageTime(value), '--')
    assert.equal(formatShortTime(value), '--')
  }
})
