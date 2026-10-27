<template>
<AgentTopbar active="" />
  <main class="main">
    <div class="breadcrumbs">首页 / 账号功能</div>
    <section class="profile-hero" aria-labelledby="profileTitle"><div class="identity"><div class="avatar-wrap"><div class="profile-avatar" id="profileAvatar">林</div><label class="avatar-edit" for="avatarInput" title="更换头像"><svg viewBox="0 0 24 24"><path d="M4 7h4l2-3h4l2 3h4v12H4Z"/><circle cx="12" cy="13" r="3"/></svg></label><input id="avatarInput" type="file" accept="image/*" hidden /></div><div><h1 id="profileTitle">林晓雨</h1><div class="identity-meta"><span>产品经理</span><span>上海</span><span>求职状态：在看机会</span></div><p class="identity-bio">5 年互联网产品经验，关注 AI 应用、企业服务与智能招聘方向。</p></div></div><div class="completion"><div class="completion-head"><span>个人资料完整度</span><strong>88%</strong></div><div class="completion-track"><div class="completion-value"></div></div><p>补充作品集与项目成果，可提升岗位推荐准确度。</p></div></section>
    <div class="workspace">
      <section class="content-panel">
        <div class="view active" id="view-basic"><form class="section-card" id="profileForm"><div class="section-head"><div><h2>基础资料</h2><p>用于企业联系、职位推荐和面试安排</p></div></div><div class="form-body"><div class="form-grid"><div class="field"><label for="nickname">个人昵称</label><input id="nickname" value="晓雨" /></div><div class="field"><label for="realname">真实姓名</label><input id="realname" value="林晓雨" /></div><div class="field"><label for="gender">性别</label><select id="gender"><option>女</option><option>男</option><option>不公开</option></select></div><div class="field"><label for="status">当前状态</label><select id="status"><option>在职-考虑机会</option><option>离职-随时到岗</option><option>在校-寻找实习</option><option>暂不考虑</option></select></div><div class="field"><label for="city">所在城市</label><input id="city" value="上海" /></div><div class="field"><label for="phone">手机号码</label><input id="phone" value="138****6688" /></div><div class="field"><label for="email">联系邮箱</label><input id="email" type="email" value="lin***@qq.com" /></div><div class="field"><label for="role">期望岗位</label><input id="role" value="AI 产品经理" /></div><div class="field full"><label for="bio">个人简介</label><textarea id="bio">5 年互联网产品经验，关注 AI 应用、企业服务与智能招聘方向。</textarea><div class="field-note">建议突出行业经验、核心能力和期望方向。</div></div></div></div><div class="form-footer"><span>以上信息仅在获得你的授权后向企业展示</span><div class="button-row"><button class="secondary-button" type="reset">取消</button><button class="primary-button" type="submit">保存修改</button></div></div></form></div>
        <div class="view" id="view-resumes"><section class="section-card"><div class="section-head"><div><h2>我的简历库</h2><p>管理不同求职方向的简历，投递时可自由选择</p></div><div style="display:flex;align-items:center;gap:8px"><button class="secondary-button" id="uploadResume" type="button">上传 PDF 简历</button><button class="primary-button" id="createResume" type="button">新建简历</button><input id="resumeFileInput" type="file" accept="application/pdf,.pdf" hidden></div></div><div class="resume-list">
          <article class="resume-card"><span class="file-icon"><svg viewBox="0 0 24 24"><path d="M6 3h9l4 4v14H6Z"/><path d="M14 3v5h5M9 12h7M9 16h7"/></svg></span><div><div class="resume-title"><span id="primaryResumeTitle">产品经理-林晓雨</span><span class="resume-badge">默认简历</span></div><div class="resume-summary">AI 产品经理 · 5 年经验 · 上海</div></div><div class="resume-meta"><span>完整度 <strong>90%</strong></span><span>更新于 今天 10:24</span><span>近 30 天投递 8 次</span><span>企业查看 5 次</span></div><div class="resume-actions"><button class="icon-action" type="button" aria-label="复制产品经理简历" title="复制简历"><svg viewBox="0 0 24 24"><rect x="8" y="8" width="11" height="11" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/></svg></button><a class="edit-link" href="/agent/resume-editor?id=product-manager">编辑简历</a></div></article>
          <article class="resume-card"><span class="file-icon"><svg viewBox="0 0 24 24"><path d="M6 3h9l4 4v14H6Z"/><path d="M14 3v5h5M9 12h7M9 16h7"/></svg></span><div><div class="resume-title">AI 产品方向-重点项目版</div><div class="resume-summary">AI 产品经理 · Agent / 大模型应用 · 上海</div></div><div class="resume-meta"><span>完整度 <strong>96%</strong></span><span>更新于 06-16</span><span>近 30 天投递 3 次</span><span>企业查看 3 次</span></div><div class="resume-actions"><button class="icon-action" type="button" aria-label="复制 AI 产品简历" title="复制简历"><svg viewBox="0 0 24 24"><rect x="8" y="8" width="11" height="11" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/></svg></button><a class="edit-link" href="/agent/resume-editor?id=ai-product">编辑简历</a></div></article>
          <article class="resume-card"><span class="file-icon"><svg viewBox="0 0 24 24"><path d="M6 3h9l4 4v14H6Z"/><path d="M14 3v5h5M9 12h7M9 16h7"/></svg></span><div><div class="resume-title">产品运营-增长方向</div><div class="resume-summary">用户增长 · 数据分析 · 内容运营</div></div><div class="resume-meta"><span>完整度 <strong>82%</strong></span><span>更新于 06-08</span><span>近 30 天投递 1 次</span><span>企业查看 1 次</span></div><div class="resume-actions"><button class="icon-action" type="button" aria-label="复制产品运营简历" title="复制简历"><svg viewBox="0 0 24 24"><rect x="8" y="8" width="11" height="11" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/></svg></button><a class="edit-link" href="/agent/resume-editor?id=growth">编辑简历</a></div></article>
        </div><div class="resume-foot"><span>最多可创建 10 份简历，当前已使用 3 份</span><a href="/agent/resume-select?job=ai-product">体验投递选简历流程</a></div></section></div>
        <div class="view" id="view-security"><section class="section-card"><div class="section-head"><div><h2>账号安全</h2><p>建议定期更换密码并关注登录设备</p></div></div><div class="security-list"><div class="security-row"><span class="security-icon"><svg viewBox="0 0 24 24"><rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg></span><div class="security-copy"><strong>登录密码</strong><span>定期更换密码可提升账号安全</span></div><button class="text-action" data-security="修改登录密码">修改</button></div><div class="security-row"><span class="security-icon"><svg viewBox="0 0 24 24"><rect x="7" y="3" width="10" height="18" rx="2"/><path d="M10 17h4"/></svg></span><div class="security-copy"><strong>绑定手机</strong><span>138****6688 · 用于登录验证与安全提醒</span></div><button class="text-action" data-security="更换绑定手机">修改</button></div><div class="security-row"><span class="security-icon orange"><svg viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m4 7 8 6 8-6"/></svg></span><div class="security-copy"><strong>绑定邮箱</strong><span>lin***@qq.com · 用于接收面试通知</span></div><button class="text-action" data-security="更换绑定邮箱">修改</button></div><div class="security-row"><span class="security-icon"><svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8M12 17v4"/></svg></span><div class="security-copy"><strong>登录设备管理</strong><span>当前 1 台设备在线 · Chrome / Windows</span></div><button class="text-action" data-security="管理登录设备">管理</button></div><div class="security-row"><span class="security-icon red"><svg viewBox="0 0 24 24"><path d="M4 7h16M9 7V4h6v3M7 7l1 14h8l1-14M10 11v6M14 11v6"/></svg></span><div class="security-copy"><strong>注销账号</strong><span>注销后账号与数据将被删除且无法恢复</span></div><button class="text-action danger" data-security="注销账号">注销账号</button></div></div></section></div>
      </section>
    </div>
  </main>
  <dialog id="securityDialog"><form method="dialog"><div class="dialog-head"><h3 id="dialogTitle">账号设置</h3><button class="dialog-close" value="cancel" aria-label="关闭">×</button></div><div class="dialog-body"><p class="dialog-copy" id="dialogCopy">完成身份验证后即可修改。</p><div class="field"><label for="verifyCode">身份验证码</label><input id="verifyCode" inputmode="numeric" placeholder="请输入 6 位验证码" /></div></div><div class="dialog-footer"><button class="secondary-button" value="cancel">取消</button><button class="primary-button" id="dialogConfirm" value="default">确认</button></div></form></dialog>
  <div class="toast" id="toast" role="status" aria-live="polite">已保存</div>
</template>

<script setup>
import { onMounted } from 'vue'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { getAppProfile, updateAppProfile, uploadAvatar } from '@/api/system/user'
import useUserStore from '@/store/modules/user'
import { isValidPhoneNumber, validateAvatarFile, validateResumeFile } from '@/utils/agentValidation'

const props = defineProps({
  defaultView: {
    type: String,
    default: 'basic'
  }
})

const userStore = useUserStore()
let currentProfile = {}
let toastTimer

const statusMap = {
  '在职-考虑机会': 1,
  '离职-随时到岗': 2,
  '在校-寻找实习': 3
}
const statusLabels = {
  1: '在职-考虑机会',
  2: '离职-随时到岗',
  3: '在校-寻找实习'
}
const sexMap = { 男: '0', 女: '1', 不公开: '2' }
const sexLabels = { 0: '男', 1: '女', 2: '不公开' }

function byId(id) {
  return document.getElementById(id)
}

function showToast(text) {
  const toast = byId('toast')
  if (!toast) return
  toast.textContent = text
  toast.classList.add('show')
  clearTimeout(toastTimer)
  toastTimer = window.setTimeout(() => toast.classList.remove('show'), 2400)
}

function resolveAvatarUrl(avatar) {
  if (!avatar) return ''
  if (/^(https?:|data:|blob:)/i.test(avatar)) return avatar
  return `${import.meta.env.VITE_APP_BASE_API}${avatar}`
}

function getDisplayName(profile) {
  return profile.realName || profile.nickName || '求职者'
}

function calculateCompletion(profile) {
  const fields = [
    profile.nickName,
    profile.realName,
    profile.email,
    profile.phonenumber,
    profile.currentCity,
    profile.currentStatus,
    profile.targetDirection,
    profile.remark
  ]
  return Math.round(fields.filter(value => String(value ?? '').trim()).length / fields.length * 100)
}

function renderAvatar(avatar) {
  const holder = byId('profileAvatar')
  if (!holder) return
  holder.replaceChildren()
  const url = resolveAvatarUrl(avatar)
  if (url) {
    const image = document.createElement('img')
    image.src = url
    image.alt = '个人头像'
    holder.appendChild(image)
    return
  }
  holder.textContent = getDisplayName(currentProfile).slice(0, 1)
}

function renderProfileSummary(profile) {
  const name = getDisplayName(profile)
  const meta = document.querySelectorAll('.identity-meta span')
  byId('profileTitle').textContent = name
  if (meta[0]) meta[0].textContent = profile.targetDirection || '未设置期望岗位'
  if (meta[1]) meta[1].textContent = profile.currentCity || '未设置城市'
  if (meta[2]) meta[2].textContent = `求职状态：${statusLabels[Number(profile.currentStatus)] || '未设置'}`
  const bio = document.querySelector('.identity-bio')
  if (bio) bio.textContent = profile.remark || '填写个人简介，让企业更好地了解你。'
  const completion = calculateCompletion(profile)
  const completionValue = document.querySelector('.completion-value')
  const completionText = document.querySelector('.completion-head strong')
  if (completionValue) completionValue.style.width = `${completion}%`
  if (completionText) completionText.textContent = `${completion}%`
  renderAvatar(profile.avatar)
}

function setProfileForm(profile) {
  byId('nickname').value = profile.nickName || ''
  byId('realname').value = profile.realName || ''
  byId('gender').value = sexLabels[profile.sex] ? sexLabels[profile.sex] : '不公开'
  byId('status').value = statusLabels[Number(profile.currentStatus)] || '在职-考虑机会'
  byId('city').value = profile.currentCity || ''
  byId('phone').value = profile.phonenumber || ''
  byId('email').value = profile.email || ''
  byId('role').value = profile.targetDirection || ''
  byId('bio').value = profile.remark || ''
  renderProfileSummary(profile)
}

function readProfileForm() {
  return {
    ...currentProfile,
    nickName: byId('nickname').value.trim(),
    realName: byId('realname').value.trim(),
    sex: sexMap[byId('gender').value] || '2',
    currentStatus: statusMap[byId('status').value] || null,
    currentCity: byId('city').value.trim(),
    phonenumber: byId('phone').value.trim(),
    email: byId('email').value.trim(),
    targetDirection: byId('role').value.trim(),
    remark: byId('bio').value.trim()
  }
}

function validateProfile(profile) {
  if (!profile.nickName) return '个人昵称不能为空'
  if (profile.nickName.length > 30) return '个人昵称不能超过 30 个字符'
  if (profile.phonenumber && !isValidPhoneNumber(profile.phonenumber)) return '请输入正确的手机号码'
  if (profile.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(profile.email)) return '请输入正确的邮箱地址'
  return ''
}

async function loadProfile() {
  const form = byId('profileForm')
  if (form) form.setAttribute('aria-busy', 'true')
  try {
    const response = await getAppProfile()
    currentProfile = response.data || {}
    setProfileForm(currentProfile)
  } catch (error) {
    showToast(error?.message || '基础资料加载失败，请稍后重试')
  } finally {
    if (form) form.removeAttribute('aria-busy')
  }
}

async function saveProfile(event) {
  event.preventDefault()
  const profile = readProfileForm()
  const validationMessage = validateProfile(profile)
  if (validationMessage) {
    showToast(validationMessage)
    return
  }
  const submitButton = event.currentTarget.querySelector('button[type="submit"]')
  submitButton.disabled = true
  try {
    const response = await updateAppProfile({
      nickName: profile.nickName,
      realName: profile.realName,
      sex: profile.sex,
      phonenumber: profile.phonenumber,
      email: profile.email,
      remark: profile.remark,
      currentCity: profile.currentCity,
      currentStatus: profile.currentStatus,
      targetDirection: profile.targetDirection,
      targetCity: currentProfile.targetCity || null
    })
    currentProfile = { ...currentProfile, ...(response.data || profile) }
    setProfileForm(currentProfile)
    userStore.nickName = currentProfile.nickName || userStore.nickName
    showToast('个人资料已保存')
  } catch (error) {
    showToast(error?.message || '个人资料保存失败，请稍后重试')
  } finally {
    submitButton.disabled = false
  }
}

async function handleAvatarChange(event) {
  const file = event.target.files?.[0]
  event.target.value = ''
  if (!file) return
  const validation = validateAvatarFile(file)
  if (!validation.valid) {
    showToast(validation.message)
    return
  }
  const formData = new FormData()
  formData.append('avatarfile', file, file.name)
  try {
    const response = await uploadAvatar(formData)
    currentProfile.avatar = response.imgUrl || currentProfile.avatar
    userStore.avatar = resolveAvatarUrl(currentProfile.avatar)
    renderAvatar(currentProfile.avatar)
    showToast('头像已更新')
  } catch (error) {
    showToast(error?.message || '头像上传失败，请稍后重试')
  }
}

onMounted(() => {
  const views = [...document.querySelectorAll('.view')]
  const setView = name => {
    const target = ['basic', 'resumes', 'security'].includes(name) ? name : 'basic'
    views.forEach(view => view.classList.toggle('active', view.id === `view-${target}`))
  }
  const requested = location.hash.slice(1)
  setView(['basic', 'resumes', 'security'].includes(requested) ? requested : props.defaultView)

  const gender = byId('gender')
  gender.innerHTML = '<option>女</option><option>男</option><option>不公开</option>'
  const status = byId('status')
  status.innerHTML = '<option>在职-考虑机会</option><option>离职-随时到岗</option><option>在校-寻找实习</option>'
  byId('nickname').required = true
  byId('profileForm').addEventListener('submit', saveProfile)
  byId('profileForm').addEventListener('reset', event => {
    event.preventDefault()
    setProfileForm(currentProfile)
    showToast('已恢复未保存修改')
  })
  byId('avatarInput').addEventListener('change', handleAvatarChange)
  loadProfile()

  byId('createResume').addEventListener('click', () => window.__agentNavigate('/agent/resume-editor?id=new'))
  const uploadResume = byId('uploadResume')
  const resumeFileInput = byId('resumeFileInput')
  uploadResume.addEventListener('click', () => resumeFileInput.click())
  resumeFileInput.addEventListener('change', event => {
    const file = event.target.files?.[0]
    if (!file) return
    const validation = validateResumeFile(file)
    if (!validation.valid) {
      showToast(validation.message)
      event.target.value = ''
      return
    }
    localStorage.setItem('uploadedResume', JSON.stringify({ name: file.name, size: file.size, updated: new Date().toISOString() }))
    showToast(`已上传：${file.name}`)
    event.target.value = ''
  })
  document.querySelectorAll('.resume-card').forEach(card => {
    const link = card.querySelector('.edit-link')
    card.tabIndex = 0
    card.setAttribute('role', 'link')
    card.addEventListener('click', event => {
      if (!event.target.closest('a,button')) window.__agentNavigate(link.href)
    })
    card.addEventListener('keydown', event => {
      if (event.key === 'Enter') window.__agentNavigate(link.href)
    })
  })
  document.querySelectorAll('.icon-action').forEach(button => button.addEventListener('click', () => showToast('已复制一份简历草稿')))
  try {
    const saved = JSON.parse(localStorage.getItem('resumeDraft') || 'null')
    if (saved?.title) byId('primaryResumeTitle').textContent = saved.title
  } catch {
    // 忽略损坏的本地简历草稿，避免影响基础资料页面。
  }

  const dialog = byId('securityDialog')
  const dialogTitle = byId('dialogTitle')
  const dialogCopy = byId('dialogCopy')
  document.querySelectorAll('[data-security]').forEach(button => button.addEventListener('click', () => {
    const action = button.dataset.security
    dialogTitle.textContent = action
    dialogCopy.textContent = action === '注销账号'
      ? '这是高风险操作。演示页面不会真正删除账号，请输入验证码进行确认。'
      : '为保护账号安全，请先完成身份验证。'
    dialog.showModal()
  }))
  byId('dialogConfirm').addEventListener('click', event => {
    event.preventDefault()
    dialog.close()
    showToast('演示操作已完成')
  })
})
</script>

<style>
:root{--primary:#1A3C6E;--blue:#2B7FFF;--blue-dark:#1D67D8;--blue-soft:#EAF2FF;--bg:#F5F7FA;--card:#FFF;--text:#172B4D;--muted:#667891;--light:#96A3B5;--line:#E5EAF1;--green:#16845B;--green-soft:#EAF7F1;--orange:#C7791D;--orange-soft:#FFF3E3;--red:#CF3F4B;--red-soft:#FCECEF;--shadow:0 6px 22px rgba(26,60,110,.055)}
    *{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;color:var(--text);background:var(--bg);font-family:"PingFang SC","Microsoft YaHei",system-ui,-apple-system,"Segoe UI",sans-serif;font-size:14px;line-height:1.55}button,input,select,textarea{font:inherit}button,a{cursor:pointer}a{color:inherit}svg{display:block}button:focus-visible,a:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible{outline:3px solid rgba(43,127,255,.2);outline-offset:2px}
    /* 顶部导航保持与求职者端其他页面一致 */
    .topbar{position:sticky;top:0;z-index:20;height:72px;border-bottom:1px solid var(--line);background:rgba(255,255,255,.98);backdrop-filter:blur(10px)}.topbar-inner,.main{width:min(1240px,calc(100% - 48px));margin:0 auto}.topbar-inner{height:72px;display:flex;align-items:center;gap:30px}.brand{display:flex;align-items:center;gap:10px;color:var(--primary);text-decoration:none;white-space:nowrap}.brand-mark{width:34px;height:34px;display:grid;place-items:center;border-radius:8px;color:#fff;background:linear-gradient(145deg,var(--blue),var(--primary));font-weight:800}.brand-name{font-size:18px;font-weight:800}.brand-tag{color:var(--muted);font-size:11px}.main-nav{height:72px;display:flex;align-items:center;gap:4px}.nav-link{position:relative;height:72px;display:flex;align-items:center;padding:0 13px;color:var(--muted);text-decoration:none}.nav-link:hover,.nav-link.active{color:var(--primary)}.nav-link.active{font-weight:700}.nav-link.active::after{content:"";position:absolute;right:13px;bottom:0;left:13px;height:3px;border-radius:3px 3px 0 0;background:var(--blue)}.nav-badge{min-width:17px;height:17px;margin-left:5px;padding:0 5px;display:grid;place-items:center;border-radius:99px;color:#fff;background:var(--red);font-size:10px}.top-actions{margin-left:auto;display:flex;align-items:center;gap:12px}.notice-link{position:relative;width:38px;height:38px;display:grid;place-items:center;border-radius:8px;color:var(--muted);text-decoration:none}.notice-link:hover{color:var(--blue);background:var(--blue-soft)}.notice-link svg{width:19px;height:19px;stroke:currentColor;fill:none;stroke-width:1.8}.notice-dot{position:absolute;top:6px;right:6px;width:7px;height:7px;border:2px solid #fff;border-radius:50%;background:var(--red)}.profile-mini{display:flex;align-items:center;gap:9px}.mini-avatar{width:34px;height:34px;display:grid;place-items:center;overflow:hidden;border-radius:50%;color:#fff;background:#7894BE;font-weight:800}.mini-avatar img{width:100%;height:100%;object-fit:cover}.profile-mini strong{font-size:12px}
    .main{padding:24px 0 48px}.breadcrumbs{margin-bottom:14px;color:var(--light);font-size:11px}.profile-hero{display:grid;grid-template-columns:minmax(0,1fr) 310px;gap:24px;padding:24px;border:1px solid var(--line);border-radius:8px;background:#fff;box-shadow:var(--shadow)}.identity{display:flex;align-items:center;gap:18px}.avatar-wrap{position:relative;flex:0 0 auto}.profile-avatar{width:84px;height:84px;display:grid;place-items:center;overflow:hidden;border:4px solid #F0F5FC;border-radius:50%;color:#fff;background:linear-gradient(145deg,#5F8CCB,#1A3C6E);font-size:26px;font-weight:800}.profile-avatar img{width:100%;height:100%;object-fit:cover}.avatar-edit{position:absolute;right:-2px;bottom:1px;width:28px;height:28px;display:grid;place-items:center;border:3px solid #fff;border-radius:50%;color:#fff;background:var(--blue)}.avatar-edit svg{width:13px;height:13px;stroke:currentColor;fill:none;stroke-width:2}.identity h1{margin:0;color:var(--primary);font-size:24px}.identity-meta{display:flex;flex-wrap:wrap;gap:8px 16px;margin-top:7px;color:var(--muted);font-size:12px}.identity-bio{max-width:620px;margin:10px 0 0;color:#52647D;font-size:12px}.completion{align-self:center;padding-left:24px;border-left:1px solid var(--line)}.completion-head{display:flex;align-items:flex-end;justify-content:space-between}.completion-head span{color:var(--muted);font-size:11px}.completion-head strong{color:var(--blue);font-size:24px}.completion-track{height:7px;margin-top:10px;overflow:hidden;border-radius:99px;background:#E6EDF6}.completion-value{width:88%;height:100%;border-radius:inherit;background:var(--blue)}.completion p{margin:9px 0 0;color:var(--light);font-size:10px}
    .workspace{display:grid;grid-template-columns:minmax(0,1fr);gap:16px;margin-top:16px}.content-panel{min-width:0}.view{display:none}.view.active{display:block}.section-card{border:1px solid var(--line);border-radius:8px;background:#fff;box-shadow:var(--shadow);overflow:hidden}.section-card+.section-card{margin-top:14px}.section-head{min-height:62px;display:flex;align-items:center;justify-content:space-between;gap:18px;padding:14px 18px;border-bottom:1px solid var(--line)}.section-head h2{margin:0;color:var(--primary);font-size:16px}.section-head p{margin:3px 0 0;color:var(--light);font-size:10px}.head-action,.primary-button,.secondary-button{height:36px;padding:0 14px;border-radius:6px;font-size:12px;font-weight:700}.head-action,.secondary-button{border:1px solid #C9D8EB;color:var(--primary);background:#fff}.head-action:hover,.secondary-button:hover{border-color:var(--blue);color:var(--blue)}.primary-button{border:1px solid var(--blue);color:#fff;background:var(--blue)}.primary-button:hover{background:var(--blue-dark)}
    .form-body{padding:18px}.form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}.field.full{grid-column:1/-1}.field label{display:block;margin-bottom:6px;color:#53657D;font-size:11px;font-weight:600}.field input,.field select,.field textarea{width:100%;min-height:40px;padding:9px 11px;border:1px solid #D7E0EC;border-radius:6px;color:var(--text);background:#fff}.field textarea{min-height:88px;resize:vertical}.field input:focus,.field select:focus,.field textarea:focus{border-color:var(--blue);outline:3px solid rgba(43,127,255,.11)}.field-note{margin-top:5px;color:var(--light);font-size:10px}.form-footer{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:14px 18px;border-top:1px solid var(--line);background:#FBFCFE}.form-footer span{color:var(--light);font-size:10px}.button-row{display:flex;gap:9px}
    .resume-list{display:grid;gap:12px;padding:16px}.resume-card{position:relative;display:grid;grid-template-columns:48px minmax(0,1fr) 190px auto;align-items:center;gap:14px;padding:16px;border:1px solid var(--line);border-radius:7px;background:#fff;cursor:pointer;transition:border-color .18s,box-shadow .18s}.resume-card:hover{border-color:#B7CFF0;box-shadow:0 7px 18px rgba(26,60,110,.07)}.file-icon{width:44px;height:52px;display:grid;place-items:center;border-radius:6px;color:var(--blue);background:var(--blue-soft)}.file-icon svg{width:22px;height:22px;stroke:currentColor;fill:none;stroke-width:1.7}.resume-title{display:flex;align-items:center;gap:8px;color:var(--primary);font-size:15px;font-weight:800}.resume-badge{padding:2px 7px;border-radius:4px;color:var(--blue);background:var(--blue-soft);font-size:9px;font-weight:700}.resume-summary{margin-top:6px;color:var(--muted);font-size:11px}.resume-meta{display:grid;grid-template-columns:1fr 1fr;gap:4px 12px;color:var(--light);font-size:10px}.resume-meta strong{color:var(--green);font-weight:700}.resume-actions{display:flex;gap:8px}.icon-action{width:36px;height:36px;display:grid;place-items:center;border:1px solid var(--line);border-radius:6px;color:var(--muted);background:#fff}.icon-action:hover{border-color:var(--blue);color:var(--blue)}.icon-action svg{width:16px;height:16px;stroke:currentColor;fill:none;stroke-width:1.8}.edit-link{height:36px;display:flex;align-items:center;padding:0 13px;border-radius:6px;color:#fff;background:var(--blue);font-size:11px;font-weight:700;text-decoration:none}.resume-foot{display:flex;justify-content:space-between;gap:16px;padding:12px 18px;border-top:1px solid var(--line);color:var(--light);font-size:10px}.resume-foot a{color:var(--blue);text-decoration:none}
    .security-list{padding:0 18px}.security-row{min-height:70px;display:grid;grid-template-columns:38px minmax(0,1fr) auto;align-items:center;gap:13px;border-bottom:1px solid var(--line)}.security-row:last-child{border-bottom:0}.security-icon{width:34px;height:34px;display:grid;place-items:center;border-radius:50%;color:var(--blue);background:var(--blue-soft)}.security-icon.orange{color:var(--orange);background:var(--orange-soft)}.security-icon.red{color:var(--red);background:var(--red-soft)}.security-icon svg{width:17px;height:17px;stroke:currentColor;fill:none;stroke-width:1.8}.security-copy strong{display:block;color:var(--primary);font-size:12px}.security-copy span{display:block;margin-top:2px;color:var(--light);font-size:10px}.text-action{border:0;color:var(--blue);background:transparent;font-size:11px}.text-action.danger{color:var(--red)}
    dialog{width:min(480px,calc(100% - 32px));padding:0;border:0;border-radius:8px;box-shadow:0 24px 70px rgba(23,43,77,.24)}dialog::backdrop{background:rgba(18,32,52,.42);backdrop-filter:blur(2px)}.dialog-head{display:flex;align-items:center;justify-content:space-between;padding:16px 18px;border-bottom:1px solid var(--line)}.dialog-head h3{margin:0;color:var(--primary);font-size:16px}.dialog-close{width:32px;height:32px;display:grid;place-items:center;border:0;border-radius:6px;color:var(--muted);background:transparent}.dialog-close:hover{background:var(--bg)}.dialog-body{padding:18px}.dialog-copy{margin:0 0 14px;color:var(--muted);font-size:12px}.dialog-footer{display:flex;justify-content:flex-end;gap:8px;padding:14px 18px;border-top:1px solid var(--line);background:#FBFCFE}.toast{position:fixed;z-index:50;right:24px;bottom:24px;padding:11px 15px;border:1px solid #CDE7DD;border-radius:7px;color:#176B50;background:#F2FBF7;opacity:0;transform:translateY(10px);transition:.18s}.toast.show{opacity:1;transform:translateY(0)}
    @media(max-width:1000px){.topbar-inner,.main{width:calc(100% - 32px)}.brand-tag,.profile-mini strong{display:none}.nav-link{padding:0 8px}.profile-hero{grid-template-columns:1fr}.completion{padding:16px 0 0;border-top:1px solid var(--line);border-left:0}.resume-card{grid-template-columns:48px minmax(0,1fr) auto}.resume-meta{grid-column:2}.resume-actions{grid-column:3;grid-row:1/3}}
    @media(max-width:720px){.topbar{height:64px}.topbar-inner{height:64px}.main-nav{display:none}.main{padding-top:14px}.profile-hero{padding:18px}.identity{align-items:flex-start}.profile-avatar{width:70px;height:70px}.workspace{grid-template-columns:1fr}.form-grid{grid-template-columns:1fr}.resume-card{grid-template-columns:42px minmax(0,1fr)}.resume-meta,.resume-actions{grid-column:2;grid-row:auto}.resume-actions{justify-content:flex-start}.section-head{align-items:flex-start}.form-footer{align-items:flex-start;flex-direction:column}.button-row{width:100%}.button-row button{flex:1}}
    @media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important;transition:none!important}}
</style>
