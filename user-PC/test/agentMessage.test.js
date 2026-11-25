import test from 'node:test'
import assert from 'node:assert/strict'
import { insertMessageEmoji, isImageMessage, messageAttachmentError, messageAttachmentPath, messageAttachmentUploadName, messageContentCard, messageLinkParts, messagePreview, resolveMessageAttachment, uploadedMessageAttachmentPath } from '../src/utils/agentMessage.js'

const sharedJob = {
  kind: 'job_card', version: 1, positionId: 26, title: '前端开发工程师',
  company: '示例企业', city: '杭州', experience: '1-3年', education: 3,
  salaryMin: 10000, salaryMax: 18000
}

test('企业与 App 分享的岗位 JSON 渲染为真实字段卡片和本端详情入口', () => {
  const card = messageContentCard({ type: '6', content: JSON.stringify(sharedJob) })
  assert.equal(card.kind, 'job')
  assert.equal(card.title, sharedJob.title)
  assert.equal(card.subtitle, sharedJob.company)
  assert.equal(card.highlight, '10,000–18,000 元/月')
  assert.deepEqual(card.tags, ['杭州', '1-3年', '本科'])
  assert.equal(card.action.to, '/job-detail?id=26')
  assert.equal(messagePreview(JSON.stringify(sharedJob)), '[HR 分享的岗位] 前端开发工程师')
})

test('岗位卡片兼容字符串数值、双重编码和缺失字段，不伪造薪资', () => {
  const partial = { ...sharedJob, salaryMin: null, salaryMax: null, education: null, city: '', experience: '' }
  const card = messageContentCard({ type: 6, content: JSON.stringify(JSON.stringify(partial)) })
  assert.equal(card.highlight, '薪资面议')
  assert.deepEqual(card.tags, ['城市不限', '经验不限', '学历不限'])
  assert.equal(messageContentCard({ content: JSON.stringify({ ...sharedJob, salaryMax: null }) }).highlight, '10,000 元/月起')
  assert.equal(messageContentCard({ content: JSON.stringify({ ...sharedJob, salaryMin: null }) }).highlight, '最高 18,000 元/月')
})

test('非法岗位编号及未来版本不生成可点击操作', () => {
  for (const positionId of [0, -1, 1.5, 'javascript:alert(1)', '26&admin=true', '9007199254740993']) {
    const card = messageContentCard({ type: 6, content: JSON.stringify({ ...sharedJob, positionId }) })
    assert.equal(card.kind, 'notice')
    assert.equal(card.action, undefined)
  }
  assert.equal(messageContentCard({ type: 6, content: JSON.stringify({ ...sharedJob, version: 2 }) }).action, undefined)
})

test('异常对象字段不会让整页消息加载失败，也不把布尔值当成薪资', () => {
  for (const field of ['positionId', 'salaryMin', 'salaryMax', 'education', 'version']) {
    assert.doesNotThrow(() => messageContentCard({ type: 6, content: JSON.stringify({ ...sharedJob, [field]: { toString: null } }) }))
  }
  const card = messageContentCard({ type: 6, content: JSON.stringify({ ...sharedJob, salaryMin: true, salaryMax: false }) })
  assert.equal(card.highlight, '薪资面议')
  assert.doesNotThrow(() => messageContentCard({ content: '{"kind":"interview_reschedule","version":1,"status":{"toString":null}}' }))
})

test('面试改期按真实状态展示新旧时间、原因和审批说明，统一北京时间', () => {
  const payload = {
    kind: 'interview_reschedule', version: 1, positionName: 'Java 开发工程师',
    originalStartTime: '2026-11-17T01:00:00Z', originalEndTime: '2026-11-17T02:00:00Z',
    newStartTime: '2026-11-18 14:00:00', newEndTime: '2026-11-18 15:00:00',
    reason: '与课程时间冲突', reviewNote: '已确认时间'
  }
  for (const [status, title, badge] of [
    ['pending', '改期申请已提交', '等待处理'], ['approved', '改期申请已同意', '已同意'],
    ['rejected', '改期申请未通过', '未通过'], ['changed', '面试时间已更新', '时间已变更']
  ]) {
    const card = messageContentCard({ type: 5, content: JSON.stringify({ ...payload, status }) })
    assert.equal(card.title, title)
    assert.equal(card.status, badge)
    assert.equal(card.fields[0].value, '2026-11-17 09:00 ～ 10:00')
    assert.equal(card.fields[1].value, '2026-11-18 14:00 ～ 15:00')
    assert.equal(card.fields[1].label, ['approved', 'changed'].includes(status) ? '新面试时间' : '申请调整至')
    assert.equal(card.fields[3].value, payload.reviewNote)
    assert.equal(card.footnote, '以上时间均为北京时间')
  }
})

test('未知改期状态与空值不崩溃、不输出 null 或 Invalid Date', () => {
  for (const status of ['unknown', '__proto__', 'constructor', null]) {
    const card = messageContentCard({ type: 5, content: JSON.stringify({ kind: 'interview_reschedule', version: 1, status, originalStartTime: 'not-a-date' }) })
    assert.equal(card.status, '待确认')
    assert.deepEqual(card.fields, [])
  }
})

test('跨日面试保留起止日期，避免把次日结束时间当成同一天', () => {
  const card = messageContentCard({ type: 5, content: JSON.stringify({ kind: 'interview_reschedule', version: 1, status: 'changed', newStartTime: '2026-11-17 23:30:00', newEndTime: '2026-11-18 00:30:00' }) })
  assert.equal(card.fields[0].value, '2026-11-17 23:30 ～ 2026-11-18 00:30')
})

test('历史文本面试邀请转为卡片，仅提取会议令牌进入本端，不导航到消息主机', () => {
  const token = 'synthetic-room-token-1234'
  const card = messageContentCard({ type: 1, content: `【面试邀请·技术一面】明天上午10点，视频面试请点击链接进入：https://other.example.com/conference-join?token=${token}` })
  assert.equal(card.kind, 'interview')
  assert.equal(card.title, '技术一面')
  assert.equal(card.action.to, `/conference-join?token=${token}`)
  assert.equal(card.description.includes(token), false)
  assert.deepEqual(card.links, [])
})

test('面试入口拒绝伪造路径、重复或非法令牌，其他安全链接保持可查看', () => {
  for (const link of [
    'https://example.com/evil?token=synthetic-room-token-1234',
    'https://example.com/conference-join?token=synthetic-room-token-1234&token=other',
    'https://example.com/conference-join?token=short'
  ]) {
    assert.equal(messageContentCard({ content: `【面试邀请】请参加 ${link}` }).action, undefined)
  }
  const card = messageContentCard({ content: '【面试邀请】详情 https://example.com/meeting/26' })
  assert.equal(card.links[0].href, 'https://example.com/meeting/26')
})

test('未知 JSON 使用中文摘要与可读字段，不展示内部标识或密钥', () => {
  const content = JSON.stringify({ title: '笔试安排', content: '请查看 https://example.com/exam', requestId: 'internal-id', token: 'private-token', metadata: { raw: true } })
  const card = messageContentCard({ type: 4, content })
  assert.equal(card.title, '笔试安排')
  assert.deepEqual(card.fields, [{ label: '内容', value: '请查看 https://example.com/exam' }])
  assert.equal(JSON.stringify(card).includes('private-token'), false)
  assert.equal(messagePreview(content), '[消息通知] 笔试安排')
  assert.match(messageContentCard({ content: '{"kind":"future_card"}' }).description, /暂不支持/)
})

test('普通文本、图片附件以及损坏的 JSON 不影响原有消息处理', () => {
  for (const content of ['你好 HR 😊', '面试 https://example.com/meeting', '请看 {"name":"示例"}', '{broken', '123', 'null']) {
    assert.equal(messageContentCard({ type: 1, content }), null)
    assert.equal(messagePreview(content), content)
  }
  for (const type of [2, '2', 3, '3']) {
    assert.equal(messageContentCard({ type, content: JSON.stringify(sharedJob) }), null)
  }
  assert.equal(messageContentCard({ type: 6, content: '{broken' }).kind, 'notice')
})

test('跨端附件统一使用当前环境代理，兼容旧域名及 API 前缀', () => {
  for (const value of [
    '/profile/upload/hr.png',
    '/dev-api/profile/upload/hr.png',
    'http://localhost:8080/profile/upload/hr.png',
    'https://enterprise.example.com:8444/prod-api/profile/upload/hr.png'
  ]) {
    assert.equal(resolveMessageAttachment(value, '/dev-api', 'http://127.0.0.1:5180'), 'http://127.0.0.1:5180/dev-api/profile/upload/hr.png')
    assert.equal(resolveMessageAttachment(value, '/prod-api', 'https://candidate.example.com'), 'https://candidate.example.com/prod-api/profile/upload/hr.png')
  }
})

test('附件 URL 保留查询参数、中文文件名且不重复添加代理前缀', () => {
  assert.equal(resolveMessageAttachment('/prod-api/profile/作品.png?v=2', '/prod-api', 'https://candidate.example.com'), 'https://candidate.example.com/prod-api/profile/%E4%BD%9C%E5%93%81.png?v=2')
  assert.equal(resolveMessageAttachment('https://cdn.example.com/photo.png?signature=abc', '/prod-api', 'https://candidate.example.com'), 'https://cdn.example.com/photo.png?signature=abc')
})

test('附件拒绝非 HTTP 协议、内嵌凭据和控制字符', () => {
  for (const value of ['javascript:alert(1)', 'data:image/png;base64,abc', '//user:pass@host/profile/a.png', '/profile/\nfile.png', '']) {
    assert.equal(resolveMessageAttachment(value, '/dev-api', 'https://candidate.example.com'), '')
    assert.equal(messageAttachmentPath(value), '')
  }
})

test('发送附件只存储后端认可的 profile 路径，不存储前端代理地址', () => {
  assert.equal(messageAttachmentPath('http://127.0.0.1:5180/dev-api/profile/upload/test.png'), '/profile/upload/test.png')
  assert.equal(messageAttachmentPath('/prod-api/profile/upload/test.pdf'), '/profile/upload/test.pdf')
  assert.equal(messageAttachmentPath('/profile/upload/test.png'), '/profile/upload/test.png')
  for (const value of ['https://other.example.com/image.png', '/profile/../secret', '/profile/a.png#fragment']) {
    assert.equal(messageAttachmentPath(value), '')
  }
})

test('企业端用文件类型发送的图片也能预览，并兼容字符串消息类型', () => {
  assert.equal(isImageMessage({ type: '2', attachmentUrl: '/profile/a' }), true)
  assert.equal(isImageMessage({ type: 3, attachmentUrl: '/profile/photo.PNG?v=1' }), true)
  assert.equal(isImageMessage({ type: '3', attachmentUrl: '/profile/photo.webp' }), true)
  assert.equal(isImageMessage({ type: 3, attachmentUrl: '/profile/resume.pdf' }), false)
  assert.equal(isImageMessage({ type: 1, attachmentUrl: '/profile/photo.png' }), false)
})

test('上传返回值允许空格和中文文件名，并编码后存储', () => {
  assert.equal(messageAttachmentPath('/profile/upload/test resume.pdf'), '/profile/upload/test%20resume.pdf')
  assert.equal(uploadedMessageAttachmentPath({ fileName: '/profile/upload/附件 1.pdf' }), '/profile/upload/%E9%99%84%E4%BB%B6%201.pdf')
})

test('上传结果兼容根对象和 data 包装，并在 fileName 不可用时回退有效 url', () => {
  assert.equal(uploadedMessageAttachmentPath({ data: { fileName: '/profile/upload/a.pdf' } }), '/profile/upload/a.pdf')
  assert.equal(uploadedMessageAttachmentPath({ fileName: 'a.pdf', url: 'https://server.example.com/profile/upload/a.pdf' }), '/profile/upload/a.pdf')
  assert.equal(uploadedMessageAttachmentPath({ fileName: 'a.pdf', data: { url: '/profile/upload/b.pdf' } }), '/profile/upload/b.pdf')
  assert.equal(uploadedMessageAttachmentPath({ data: { url: 'javascript:alert(1)' } }), '')
})

test('上传使用随机存储名，避免原始文件名中的空格、中文和 URL 特殊字符影响存取', () => {
  for (const name of ['附件 1.pdf', 'test #1?.png', '100%完成.PNG']) {
    const extension = name.split('.').pop().toLowerCase()
    assert.equal(messageAttachmentUploadName(name, 'synthetic-id'), `synthetic-id.${extension}`)
  }
  assert.match(messageAttachmentUploadName('attachment.pdf'), /^[a-f\d-]+\.pdf$/)
})

test('附件缺失、登录失效和权限错误给出明确提示，不泄露服务器原始路径', () => {
  assert.match(messageAttachmentError(200, { code: 500, msg: 'No static resource upload/private-file.pdf for request /profile/upload/private-file.pdf' }), /当前后端未找到/)
  assert.equal(messageAttachmentError(200, { code: 500, msg: 'No static resource upload/private-file.pdf' }).includes('private-file.pdf'), false)
  assert.match(messageAttachmentError(404), /当前后端未找到/)
  assert.match(messageAttachmentError(200, { code: 401 }), /重新登录/)
  assert.match(messageAttachmentError(403), /无权访问/)
  assert.match(messageAttachmentError(200), /暂时无法读取/)
})

test('面试和笔试链接可点击，保留换行、中文标点和全部原始文本', () => {
  const text = '面试：https://candidate.example.com/user/agent/interview?id=26&token=abc。\n笔试（https://candidate.example.com/agent/exam?scheduleId=5），请准时参加'
  const parts = messageLinkParts(text)
  assert.equal(parts.map(part => part.text).join(''), text)
  assert.deepEqual(parts.filter(part => part.href).map(part => part.href), [
    'https://candidate.example.com/user/agent/interview?id=26&token=abc',
    'https://candidate.example.com/agent/exam?scheduleId=5'
  ])
})

test('链接解析保留 URL 内的配对括号，排除句末括号和句号', () => {
  const text = '(https://example.com/a_(b)). https://example.com/next!'
  const parts = messageLinkParts(text)
  assert.equal(parts.map(part => part.text).join(''), text)
  assert.deepEqual(parts.filter(part => part.href).map(part => part.href), ['https://example.com/a_(b)', 'https://example.com/next'])
})

test('不执行消息 HTML，危险协议、伪造带账号链接仅作为文本', () => {
  const text = '<img src=x onerror=alert(1)> javascript:alert(1) data:text/html,abc https://user:pass@example.com/'
  const parts = messageLinkParts(text)
  assert.deepEqual(parts, [{ text }])
})

test('表情在光标位置插入或替换选中内容，遵守消息长度限制', () => {
  assert.deepEqual(insertMessageEmoji('你好HR', '😊', 2, 2), { text: '你好😊HR', cursor: 4 })
  assert.deepEqual(insertMessageEmoji('你好HR', '👍', 2, 4), { text: '你好👍', cursor: 4 })
  assert.deepEqual(insertMessageEmoji('', '🤝'), { text: '🤝', cursor: 2 })
  assert.equal(insertMessageEmoji('a'.repeat(999), '😊'), null)
  assert.equal(insertMessageEmoji('a'.repeat(998), '😊').text.length, 1000)
})
