<template>
  <AgentTopbar active="" />
  <main class="main">
    <div class="breadcrumb">首页 / 账号功能 / 账号安全</div>

    <section class="page-head">
      <div>
        <h1>账号安全</h1>
        <p>管理登录凭证和账号绑定信息，保护求职数据安全。</p>
      </div>
      <div class="security-state" :class="securityState.className">
        <span class="state-dot"></span>
        <span>{{ securityState.label }}</span>
      </div>
    </section>

    <div v-if="loading" class="state-panel">正在读取账号安全信息...</div>
    <div v-else-if="errorMessage" class="state-panel error-state">
      <strong>账号安全信息暂时无法读取</strong>
      <span>{{ errorMessage }}</span>
      <button class="secondary" type="button" @click="loadSecurity">重新加载</button>
    </div>
    <template v-else>
      <section class="overview-grid">
        <article class="overview-card">
          <span class="overview-label">登录账号</span>
          <strong>{{ profile.userName || '未获取' }}</strong>
          <span class="overview-note">账号用于账号密码登录</span>
        </article>
        <article class="overview-card">
          <span class="overview-label">最近登录</span>
          <strong>{{ formatDateTime(profile.loginDate) }}</strong>
          <span class="overview-note">当前设备已登录</span>
        </article>
        <article class="overview-card">
          <span class="overview-label">安全提示</span>
          <strong>{{ securityState.scoreText }}</strong>
          <span class="overview-note">绑定手机和邮箱可提升账号安全</span>
        </article>
      </section>

      <section class="security-card">
        <div class="section-head">
          <div>
            <h2>登录凭证</h2>
            <p>定期更新密码，避免在公共设备保存登录信息。</p>
          </div>
        </div>
        <div class="security-list">
          <div class="security-row">
            <span class="security-icon">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <rect x="5" y="10" width="14" height="11" rx="2" />
                <path d="M8 10V7a4 4 0 0 1 8 0v3" />
              </svg>
            </span>
            <div class="security-copy">
              <strong>登录密码</strong>
              <span>{{ passwordStatus }}</span>
            </div>
            <button class="text-button" type="button" @click="openModal('password')">修改密码</button>
          </div>
        </div>
      </section>

      <section class="security-card">
        <div class="section-head">
          <div>
            <h2>账号绑定</h2>
            <p>绑定后的手机号和邮箱可用于安全验证与重要通知。</p>
          </div>
        </div>
        <div class="security-list">
          <div class="security-row">
            <span class="security-icon">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <rect x="7" y="3" width="10" height="18" rx="2" />
                <path d="M10 17h4" />
              </svg>
            </span>
            <div class="security-copy">
              <strong>绑定手机号</strong>
              <span>{{ profile.phonenumber ? maskPhone(profile.phonenumber) : '暂未绑定手机号' }}</span>
            </div>
            <button class="text-button" type="button" @click="openModal('phone')">
              {{ profile.phonenumber ? '更换手机号' : '绑定手机号' }}
            </button>
          </div>
          <div class="security-row">
            <span class="security-icon orange">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <rect x="3" y="5" width="18" height="14" rx="2" />
                <path d="m4 7 8 6 8-6" />
              </svg>
            </span>
            <div class="security-copy">
              <strong>绑定邮箱</strong>
              <span>{{ profile.email ? maskEmail(profile.email) : '暂未绑定邮箱' }}</span>
            </div>
            <button class="text-button" type="button" @click="openModal('email')">
              {{ profile.email ? '更换邮箱' : '绑定邮箱' }}
            </button>
          </div>
        </div>
      </section>

      <section class="security-card device-card">
        <div class="section-head">
          <div>
            <h2>登录设备</h2>
            <p>退出后当前浏览器的登录状态会立即失效。</p>
          </div>
        </div>
        <div class="device-row">
          <span class="device-icon">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <rect x="3" y="4" width="18" height="13" rx="2" />
              <path d="M8 21h8M12 17v4" />
            </svg>
          </span>
          <div class="device-copy">
            <strong>当前浏览器</strong>
            <span>本设备在线 · 退出后需要重新登录</span>
          </div>
          <button class="secondary danger-button" type="button" :disabled="loggingOut" @click="logoutCurrentDevice">
            {{ loggingOut ? '退出中...' : '退出当前设备' }}
          </button>
        </div>
      </section>
    </template>
  </main>

  <div v-if="activeModal" class="modal-backdrop" @click.self="closeModal">
    <section class="modal" role="dialog" aria-modal="true" :aria-labelledby="`${activeModal}-title`">
      <div class="modal-head">
        <div>
          <h2 :id="`${activeModal}-title`">{{ modalTitle }}</h2>
          <p>{{ modalDescription }}</p>
        </div>
        <button class="close-button" type="button" aria-label="关闭" @click="closeModal">×</button>
      </div>

      <form class="modal-form" @submit.prevent="submitModal">
        <template v-if="activeModal === 'password'">
          <label class="field">
            <span>当前密码</span>
            <input v-model="passwordForm.oldPassword" type="password" autocomplete="current-password" maxlength="20" placeholder="请输入当前密码">
          </label>
          <label class="field">
            <span>新密码</span>
            <input v-model="passwordForm.newPassword" type="password" autocomplete="new-password" maxlength="20" placeholder="请输入 6-20 位新密码">
          </label>
          <label class="field">
            <span>确认新密码</span>
            <input v-model="passwordForm.confirmPassword" type="password" autocomplete="new-password" maxlength="20" placeholder="请再次输入新密码">
          </label>
        </template>

        <template v-else-if="activeModal === 'phone'">
          <label class="field">
            <span>新手机号</span>
            <input v-model.trim="phoneForm.phone" type="tel" inputmode="numeric" autocomplete="tel" maxlength="11" placeholder="请输入新手机号">
          </label>
          <label class="field">
            <span>短信验证码</span>
            <div class="code-field">
              <input v-model.trim="phoneForm.smsCode" type="text" inputmode="numeric" autocomplete="one-time-code" maxlength="6" placeholder="请输入 6 位验证码">
              <button class="code-button" type="button" :disabled="sendingCode || countdown > 0" @click="sendPhoneCode">
                {{ countdown > 0 ? `${countdown}s 后重试` : sendingCode ? '发送中...' : '获取验证码' }}
              </button>
            </div>
          </label>
          <p v-if="devCode" class="dev-hint">本地开发验证码：{{ devCode }}</p>
        </template>

        <template v-else>
          <label class="field">
            <span>新邮箱</span>
            <input v-model.trim="emailForm.email" type="email" autocomplete="email" maxlength="100" placeholder="请输入新邮箱">
          </label>
          <label class="field">
            <span>当前密码</span>
            <input v-model="emailForm.currentPassword" type="password" autocomplete="current-password" maxlength="20" placeholder="请输入当前密码完成验证">
          </label>
        </template>

        <p v-if="formError" class="form-error" role="alert">{{ formError }}</p>
        <div class="modal-footer">
          <button class="secondary" type="button" :disabled="submitting" @click="closeModal">取消</button>
          <button class="primary" type="submit" :disabled="submitting">
            {{ submitting ? '保存中...' : '确认保存' }}
          </button>
        </div>
      </form>
    </section>
  </div>

  <div v-if="toastMessage" class="toast" role="status">{{ toastMessage }}</div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { sendSmsCode } from '@/api/login'
import { updateUserPwd } from '@/api/system/user'
import { getAppSecurity, updateAppSecurityEmail, updateAppSecurityPhone } from '@/api/agent/security'
import useUserStore from '@/store/modules/user'
import { clearCandidateSession } from '@/utils/agentSession'
import { removeToken } from '@/utils/auth'
import { isValidPhoneNumber } from '@/utils/agentValidation'

const userStore = useUserStore()
const profile = ref({})
const loading = ref(false)
const errorMessage = ref('')
const toastMessage = ref('')
const activeModal = ref('')
const submitting = ref(false)
const sendingCode = ref(false)
const countdown = ref(0)
const devCode = ref('')
const formError = ref('')
const loggingOut = ref(false)
const passwordForm = reactive({ oldPassword: '', newPassword: '', confirmPassword: '' })
const phoneForm = reactive({ phone: '', smsCode: '' })
const emailForm = reactive({ email: '', currentPassword: '' })
let countdownTimer
let toastTimer

const modalTitle = computed(() => ({
  password: '修改登录密码',
  phone: profile.value.phonenumber ? '更换绑定手机号' : '绑定手机号',
  email: profile.value.email ? '更换绑定邮箱' : '绑定邮箱'
}[activeModal.value] || '账号设置'))

const modalDescription = computed(() => ({
  password: '请输入当前密码，并设置一个新的登录密码。',
  phone: '新手机号将用于短信验证和账号安全提醒。',
  email: '请输入当前密码验证身份后保存新的邮箱地址。'
}[activeModal.value] || ''))

const passwordStatus = computed(() => profile.value.pwdUpdateDate
  ? `上次修改于 ${formatDateTime(profile.value.pwdUpdateDate)}`
  : '建议定期更换登录密码')

const securityState = computed(() => {
  const boundCount = [profile.value.phonenumber, profile.value.email].filter(Boolean).length
  if (boundCount === 2) return { label: '安全状态良好', scoreText: '安全等级：高', className: 'secure' }
  if (boundCount === 1) return { label: '建议完善绑定', scoreText: '安全等级：中', className: 'attention' }
  return { label: '需要完善安全设置', scoreText: '安全等级：低', className: 'danger' }
})

async function loadSecurity() {
  loading.value = true
  errorMessage.value = ''
  try {
    const response = await getAppSecurity()
    profile.value = response.data || {}
  } catch (error) {
    errorMessage.value = error?.message || '账号安全信息暂时无法读取'
  } finally {
    loading.value = false
  }
}

function openModal(type) {
  activeModal.value = type
  formError.value = ''
  devCode.value = ''
  resetForms()
  if (type === 'phone') phoneForm.phone = profile.value.phonenumber || ''
  if (type === 'email') emailForm.email = profile.value.email || ''
}

function closeModal() {
  if (submitting.value) return
  activeModal.value = ''
  formError.value = ''
  devCode.value = ''
  stopCountdown()
}

function resetForms() {
  passwordForm.oldPassword = ''
  passwordForm.newPassword = ''
  passwordForm.confirmPassword = ''
  phoneForm.phone = ''
  phoneForm.smsCode = ''
  emailForm.email = ''
  emailForm.currentPassword = ''
}

async function sendPhoneCode() {
  formError.value = ''
  if (!isValidPhoneNumber(phoneForm.phone)) {
    formError.value = '请输入正确的新手机号'
    return
  }
  if (phoneForm.phone === profile.value.phonenumber) {
    formError.value = '新手机号不能与当前手机号相同'
    return
  }

  sendingCode.value = true
  try {
    const response = await sendSmsCode(phoneForm.phone, 'bind_phone')
    devCode.value = response.devCode || ''
    startCountdown()
    showToast('验证码已发送')
  } catch (error) {
    formError.value = error?.message || '验证码发送失败，请稍后重试'
  } finally {
    sendingCode.value = false
  }
}

function startCountdown() {
  stopCountdown()
  countdown.value = 60
  countdownTimer = window.setInterval(() => {
    countdown.value -= 1
    if (countdown.value <= 0) stopCountdown()
  }, 1000)
}

function stopCountdown() {
  if (countdownTimer) window.clearInterval(countdownTimer)
  countdownTimer = null
  countdown.value = 0
}

async function submitModal() {
  formError.value = ''
  const validationMessage = validateModal()
  if (validationMessage) {
    formError.value = validationMessage
    return
  }

  const modalType = activeModal.value
  submitting.value = true
  try {
    let response
    if (modalType === 'password') {
      response = await updateUserPwd(passwordForm.oldPassword, passwordForm.newPassword)
    } else if (modalType === 'phone') {
      response = await updateAppSecurityPhone({
        phone: phoneForm.phone,
        smsCode: phoneForm.smsCode
      })
    } else {
      response = await updateAppSecurityEmail({
        email: emailForm.email,
        currentPassword: emailForm.currentPassword
      })
    }
    if (modalType !== 'password' && response.data) profile.value = response.data
    closeModal()
    showToast(modalType === 'password' ? '登录密码已更新' : '账号绑定信息已更新')
    await loadSecurity()
  } catch (error) {
    formError.value = error?.message || '保存失败，请稍后重试'
  } finally {
    submitting.value = false
  }
}

function validateModal() {
  if (activeModal.value === 'password') {
    if (!passwordForm.oldPassword) return '请输入当前密码'
    if (!passwordForm.newPassword || passwordForm.newPassword.length < 6 || passwordForm.newPassword.length > 20) {
      return '新密码长度应为 6-20 位'
    }
    if (passwordForm.oldPassword === passwordForm.newPassword) return '新密码不能与当前密码相同'
    if (passwordForm.newPassword !== passwordForm.confirmPassword) return '两次输入的新密码不一致'
  }
  if (activeModal.value === 'phone') {
    if (!isValidPhoneNumber(phoneForm.phone)) return '请输入正确的新手机号'
    if (phoneForm.phone === profile.value.phonenumber) return '新手机号不能与当前手机号相同'
    if (!/^\d{6}$/.test(phoneForm.smsCode)) return '请输入 6 位短信验证码'
  }
  if (activeModal.value === 'email') {
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailForm.email)) return '请输入正确的邮箱地址'
    if (!emailForm.currentPassword) return '请输入当前密码'
  }
  return ''
}

async function logoutCurrentDevice() {
  if (!window.confirm('确定退出当前设备吗？退出后需要重新登录。')) return
  loggingOut.value = true
  try {
    await userStore.logOut()
  } catch {
    userStore.$reset()
    removeToken()
  } finally {
    clearCandidateSession()
    window.__agentNavigate('/login')
  }
}

function maskPhone(phone) {
  const value = String(phone || '')
  return value.length === 11 ? `${value.slice(0, 3)}****${value.slice(-4)}` : value
}

function maskEmail(email) {
  const [name, domain] = String(email || '').split('@')
  if (!domain) return email
  const visible = name.length > 2 ? name.slice(0, 2) : name.slice(0, 1)
  return `${visible}***@${domain}`
}

function formatDateTime(value) {
  if (!value) return '暂无记录'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return String(value)
  return date.toLocaleString('zh-CN', { hour12: false })
}

function showToast(message) {
  toastMessage.value = message
  window.clearTimeout(toastTimer)
  toastTimer = window.setTimeout(() => {
    toastMessage.value = ''
  }, 2400)
}

onMounted(loadSecurity)

onBeforeUnmount(() => {
  stopCountdown()
  window.clearTimeout(toastTimer)
})
</script>

<style scoped>
:global(*){box-sizing:border-box}:global(body){margin:0;color:#172B4D;background:#F5F7FA;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif}.main{width:min(1120px,calc(100% - 48px));margin:0 auto;padding:28px 0 60px}.breadcrumb{margin-bottom:12px;color:#96A3B5;font-size:11px}.page-head{display:flex;align-items:flex-end;justify-content:space-between;gap:20px;margin-bottom:16px}.page-head h1{margin:0;color:#1A3C6E;font-size:25px}.page-head p{margin:6px 0 0;color:#6B7A90;font-size:12px}.security-state{display:flex;align-items:center;gap:7px;padding:8px 10px;border:1px solid #D5E8DD;border-radius:6px;color:#176B50;background:#F2FBF7;font-size:11px;font-weight:700}.security-state.attention{border-color:#F0DEB8;color:#996116;background:#FFF9EB}.security-state.danger{border-color:#F2C7CC;color:#B73844;background:#FFF3F4}.state-dot{width:7px;height:7px;border-radius:50%;background:#20A06B}.attention .state-dot{background:#D28A19}.danger .state-dot{background:#D94B55}.overview-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin-bottom:12px}.overview-card{min-height:112px;padding:16px;border:1px solid #E5EAF1;border-radius:8px;background:#fff;box-shadow:0 6px 22px rgba(26,60,110,.055)}.overview-label{display:block;color:#96A3B5;font-size:11px}.overview-card strong{display:block;margin-top:12px;overflow:hidden;color:#1A3C6E;font-size:15px;text-overflow:ellipsis;white-space:nowrap}.overview-note{display:block;margin-top:6px;color:#6B7A90;font-size:10px}.security-card{margin-top:12px;border:1px solid #E5EAF1;border-radius:8px;background:#fff;box-shadow:0 6px 22px rgba(26,60,110,.055)}.section-head{display:flex;align-items:center;justify-content:space-between;gap:18px;min-height:70px;padding:15px 18px;border-bottom:1px solid #E5EAF1}.section-head h2{margin:0;color:#1A3C6E;font-size:16px}.section-head p{margin:4px 0 0;color:#96A3B5;font-size:10px}.security-list{padding:0 18px}.security-row{min-height:82px;display:grid;grid-template-columns:38px minmax(0,1fr) auto;align-items:center;gap:13px;border-bottom:1px solid #E5EAF1}.security-row:last-child{border-bottom:0}.security-icon,.device-icon{width:34px;height:34px;display:grid;place-items:center;border-radius:50%;color:#2B7FFF;background:#EAF2FF}.security-icon.orange{color:#C7791D;background:#FFF3E3}.security-icon svg,.device-icon svg{width:17px;height:17px;stroke:currentColor;fill:none;stroke-width:1.8}.security-copy strong,.device-copy strong{display:block;color:#1A3C6E;font-size:12px}.security-copy span,.device-copy span{display:block;margin-top:3px;color:#96A3B5;font-size:10px}.text-button{border:0;color:#2B7FFF;background:transparent;font-size:11px;font-weight:700;cursor:pointer}.text-button:hover{color:#1D67D8}.device-row{display:flex;align-items:center;gap:13px;padding:18px}.device-copy{min-width:0;flex:1}.secondary,.primary{height:38px;padding:0 15px;border-radius:6px;font-size:11px;font-weight:700;cursor:pointer}.secondary{border:1px solid #CBD9EA;color:#1A3C6E;background:#fff}.secondary:hover{border-color:#2B7FFF;color:#2B7FFF}.primary{border:1px solid #2B7FFF;color:#fff;background:#2B7FFF}.primary:hover{background:#1D67D8}.secondary:disabled,.primary:disabled,.code-button:disabled{cursor:not-allowed;opacity:.5}.danger-button{color:#B73844;border-color:#F0C7CC}.danger-button:hover{border-color:#D94B55;color:#D94B55}.state-panel{display:grid;place-items:center;gap:9px;min-height:250px;padding:30px;border:1px solid #E5EAF1;border-radius:8px;background:#fff;color:#6B7A90;text-align:center}.state-panel strong{color:#1A3C6E;font-size:16px}.error-state{color:#CF3F4B}.modal-backdrop{position:fixed;inset:0;z-index:80;display:grid;place-items:center;padding:20px;background:rgba(18,32,52,.42);backdrop-filter:blur(2px)}.modal{width:min(480px,100%);overflow:hidden;border-radius:8px;background:#fff;box-shadow:0 24px 70px rgba(23,43,77,.24)}.modal-head{display:flex;align-items:flex-start;justify-content:space-between;gap:18px;padding:18px;border-bottom:1px solid #E5EAF1}.modal-head h2{margin:0;color:#1A3C6E;font-size:17px}.modal-head p{margin:5px 0 0;color:#6B7A90;font-size:11px}.close-button{width:30px;height:30px;border:0;border-radius:5px;color:#6B7A90;background:transparent;font-size:22px;line-height:1;cursor:pointer}.close-button:hover{background:#F5F7FA}.modal-form{padding:18px}.field{display:block;margin-bottom:14px}.field>span{display:block;margin-bottom:6px;color:#53657D;font-size:11px;font-weight:700}.field input{width:100%;height:40px;padding:0 11px;border:1px solid #D7E0EC;border-radius:6px;color:#172B4D;background:#fff;font:inherit;font-size:12px;outline:none}.field input:focus{border-color:#2B7FFF;box-shadow:0 0 0 3px rgba(43,127,255,.11)}.code-field{display:flex;gap:8px}.code-field input{min-width:0;flex:1}.code-button{height:40px;min-width:105px;padding:0 10px;border:1px solid #CBD9EA;border-radius:6px;color:#1A3C6E;background:#fff;font-size:11px;font-weight:700;cursor:pointer}.code-button:hover{border-color:#2B7FFF;color:#2B7FFF}.dev-hint{margin:-4px 0 12px;color:#996116;font-size:10px}.form-error{margin:0 0 14px;color:#C33F4B;font-size:11px}.modal-footer{display:flex;justify-content:flex-end;gap:8px;padding-top:4px}.toast{position:fixed;right:24px;bottom:24px;z-index:90;padding:11px 15px;border:1px solid #CDE7DD;border-radius:7px;color:#176B50;background:#F2FBF7}@media(max-width:700px){.main{width:calc(100% - 28px);padding-top:20px}.page-head{display:block}.security-state{width:max-content;margin-top:12px}.overview-grid{grid-template-columns:1fr}.security-row{grid-template-columns:34px minmax(0,1fr);padding:14px 0}.security-row .text-button{grid-column:2;justify-self:start}.device-row{align-items:flex-start;flex-wrap:wrap}.device-row .secondary{margin-left:47px}.modal-backdrop{padding:12px}}@media(max-width:420px){.code-field{display:grid}.code-button{width:100%}}
</style>
