import test from 'node:test'
import assert from 'node:assert/strict'
import { insertMessageEmoji, isImageMessage, messageAttachmentError, messageAttachmentPath, messageAttachmentUploadName, messageLinkParts, resolveMessageAttachment, uploadedMessageAttachmentPath } from '../src/utils/agentMessage.js'

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
