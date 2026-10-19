export const FILE_LIMITS = Object.freeze({
  avatarBytes: 3 * 1024 * 1024,
  resumeBytes: 10 * 1024 * 1024
})

const AVATAR_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp'])

export function isValidPhoneNumber(value) {
  return /^1[3-9]\d{9}$/.test(String(value || '').trim())
}

export function isValidAccount(value) {
  return /^[A-Za-z0-9_-]{2,20}$/.test(String(value || '').trim())
}

export function isValidAccountOrPhone(value) {
  const normalizedValue = String(value || '').trim()
  return isValidPhoneNumber(normalizedValue) || isValidAccount(normalizedValue)
}

export function isValidSmsCode(value) {
  return /^\d{6}$/.test(String(value || '').trim())
}

export function validateAvatarFile(file) {
  if (!file) return { valid: false, message: '请选择头像文件' }
  if (!AVATAR_TYPES.has(file.type)) return { valid: false, message: '头像仅支持 JPG、PNG 或 WebP 格式' }
  if (file.size > FILE_LIMITS.avatarBytes) return { valid: false, message: '头像文件不能超过 3MB' }
  return { valid: true }
}

export function validateResumeFile(file) {
  if (!file) return { valid: false, message: '请选择 PDF 简历文件' }
  const isPdf = file.type === 'application/pdf' || /\.pdf$/i.test(file.name || '')
  if (!isPdf) return { valid: false, message: '仅支持 PDF 格式的简历文件' }
  if (file.size > FILE_LIMITS.resumeBytes) return { valid: false, message: '简历文件不能超过 10MB' }
  return { valid: true }
}

export function validateResumeDraft({ title, name, email, targetRole, skillCount }) {
  const normalizedTitle = String(title || '').trim()
  if (!normalizedTitle || normalizedTitle.length > 60) return { valid: false, message: '简历名称应为 1-60 个字符' }
  if (!String(name || '').trim() || String(name).trim().length > 40) return { valid: false, message: '姓名应为 1-40 个字符' }
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email).trim())) return { valid: false, message: '联系邮箱格式不正确' }
  if (!String(targetRole || '').trim() || String(targetRole).trim().length > 50) return { valid: false, message: '期望职位应为 1-50 个字符' }
  if (Number(skillCount) > 30) return { valid: false, message: '技能标签不能超过 30 个' }
  return { valid: true }
}
