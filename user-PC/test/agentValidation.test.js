import test from 'node:test'
import assert from 'node:assert/strict'
import {
  FILE_LIMITS,
  isValidAccount,
  isValidAccountOrPhone,
  isValidPhoneNumber,
  isValidSmsCode,
  validateAvatarFile,
  validateResumeFile,
  validateResumeDraft
} from '../src/utils/agentValidation.js'

test('手机号与验证码校验拒绝错误格式', () => {
  assert.equal(isValidPhoneNumber('13800138000'), true)
  assert.equal(isValidPhoneNumber('12800138000'), false)
  assert.equal(isValidPhoneNumber('1380013800'), false)
  assert.equal(isValidSmsCode('123456'), true)
  assert.equal(isValidSmsCode('12345a'), false)
})

test('账号校验限制长度与字符范围', () => {
  assert.equal(isValidAccount('lin_xiaoyu'), true)
  assert.equal(isValidAccount('a'), false)
  assert.equal(isValidAccount('账号一'), false)
  assert.equal(isValidAccount('account name'), false)
})

test('密码登录标识支持手机号或账号', () => {
  assert.equal(isValidAccountOrPhone('13800138000'), true)
  assert.equal(isValidAccountOrPhone('lin_xiaoyu'), true)
  assert.equal(isValidAccountOrPhone('账号一'), false)
  assert.equal(isValidAccountOrPhone(''), false)
})

test('头像上传校验格式与大小', () => {
  assert.deepEqual(validateAvatarFile({ type: 'image/png', size: FILE_LIMITS.avatarBytes }), { valid: true })
  assert.equal(validateAvatarFile({ type: 'image/gif', size: 1 }).valid, false)
  assert.equal(validateAvatarFile({ type: 'image/jpeg', size: FILE_LIMITS.avatarBytes + 1 }).valid, false)
})

test('简历上传只接收限额以内的 PDF', () => {
  assert.deepEqual(validateResumeFile({ name: 'resume.pdf', type: 'application/pdf', size: FILE_LIMITS.resumeBytes }), { valid: true })
  assert.equal(validateResumeFile({ name: 'resume.docx', type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', size: 1 }).valid, false)
  assert.equal(validateResumeFile({ name: 'resume.pdf', type: 'application/pdf', size: FILE_LIMITS.resumeBytes + 1 }).valid, false)
})

test('简历草稿校验关键字段和数量上限', () => {
  const validDraft = { title: 'AI 产品经理', name: '林晓雨', email: 'lin@example.com', targetRole: 'AI 产品经理', skillCount: 8 }
  assert.deepEqual(validateResumeDraft(validDraft), { valid: true })
  assert.equal(validateResumeDraft({ ...validDraft, email: 'not-an-email' }).valid, false)
  assert.equal(validateResumeDraft({ ...validDraft, skillCount: 31 }).valid, false)
})
