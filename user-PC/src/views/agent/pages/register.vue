<template>
  <header class="topbar">
    <div class="topbar-inner">
      <a class="brand" :href="appHref('/index')"><span class="mark">智</span>智聘 AI</a>
      <span class="hint">创建求职者端账号</span>
    </div>
  </header>

  <main class="page">
    <section class="register-card">
      <h1>注册求职者端账号</h1>
      <p class="sub">选择注册方式，开启简历、岗位和投递管理</p>

      <div class="mode-tabs" role="tablist" aria-label="注册方式">
        <button class="mode-tab" :class="{ active: mode === 'phone' }" type="button" role="tab" :aria-selected="mode === 'phone'" @click="switchMode('phone')">手机号注册</button>
        <button class="mode-tab" :class="{ active: mode === 'account' }" type="button" role="tab" :aria-selected="mode === 'account'" @click="switchMode('account')">账号密码注册</button>
      </div>

      <form novalidate @submit.prevent="handleSubmit">
        <div v-if="mode === 'phone'" class="field">
          <label for="phone">手机号</label>
          <input id="phone" v-model.trim="form.phone" autocomplete="tel" maxlength="11" placeholder="请输入手机号" inputmode="numeric">
        </div>

        <div v-if="mode === 'phone'" class="field">
          <label for="smsCode">短信验证码</label>
          <div class="code-row">
            <input id="smsCode" v-model.trim="form.smsCode" autocomplete="one-time-code" maxlength="6" placeholder="请输入短信验证码" inputmode="numeric">
            <button class="code-button" type="button" :disabled="cooldown > 0 || sendingCode" @click="handleSendCode">{{ cooldown > 0 ? `${cooldown}s 后重试` : sendingCode ? '发送中...' : '获取验证码' }}</button>
          </div>
          <p v-if="devCode" class="dev-hint">本地开发验证码：{{ devCode }}</p>
        </div>

        <div v-else class="field">
          <label for="username">账号</label>
          <input id="username" v-model.trim="form.username" autocomplete="username" maxlength="20" placeholder="2 到 20 位字母、数字、下划线或连字符">
        </div>

        <div class="field">
          <label for="password">设置密码</label>
          <input id="password" v-model="form.password" autocomplete="new-password" maxlength="20" placeholder="5 到 20 个字符" type="password">
        </div>

        <div class="field">
          <label for="confirmPassword">确认密码</label>
          <input id="confirmPassword" v-model="form.confirmPassword" autocomplete="new-password" maxlength="20" placeholder="请再次输入密码" type="password">
        </div>

        <p v-if="error" class="error" role="alert">{{ error }}</p>

        <label class="agree">
          <input v-model="form.agree" type="checkbox">
          <span>我已阅读并同意《隐私政策》和《用户协议》</span>
        </label>

        <button class="primary" :disabled="loading" type="submit">{{ loading ? '注册中...' : '注册' }}</button>
      </form>

      <div class="footer-link">已有账号？ <a :href="appHref('/login')">返回登录</a></div>
    </section>
  </main>
</template>

<script setup>
import { appHref } from '@/utils/agentNavigation'
import { onBeforeUnmount, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { register, sendSmsCode } from '@/api/login'
import { isValidAccount, isValidPhoneNumber, isValidSmsCode } from '@/utils/agentValidation'

const router = useRouter()
const route = useRoute()
const mode = ref(route.query.mode === 'account' ? 'account' : 'phone')
const form = reactive({ username: '', phone: '', smsCode: '', password: '', confirmPassword: '', agree: false })
const error = ref('')
const loading = ref(false)
const sendingCode = ref(false)
const cooldown = ref(0)
const devCode = ref('')
let cooldownTimer

function switchMode(nextMode) {
  mode.value = nextMode
  form.phone = ''
  form.username = ''
  form.smsCode = ''
  form.password = ''
  form.confirmPassword = ''
  devCode.value = ''
  error.value = ''
}

function isValidPhone(phone) {
  return isValidPhoneNumber(phone)
}

async function handleSendCode() {
  error.value = ''
  if (!isValidPhone(form.phone)) {
    error.value = '请输入正确的手机号'
    return
  }

  sendingCode.value = true
  try {
    const res = await sendSmsCode(form.phone, 'register')
    devCode.value = res.devCode || ''
    if (res.devCode) form.smsCode = res.devCode
    cooldown.value = 60
    cooldownTimer = window.setInterval(() => {
      cooldown.value -= 1
      if (cooldown.value <= 0) {
        window.clearInterval(cooldownTimer)
        cooldownTimer = undefined
      }
    }, 1000)
  } catch (requestError) {
    error.value = requestError?.message || '验证码发送失败，请稍后重试'
  } finally {
    sendingCode.value = false
  }
}

function validate() {
  if (mode.value === 'phone' && !isValidPhone(form.phone)) return '请输入正确的手机号'
  if (mode.value === 'phone' && !isValidSmsCode(form.smsCode)) return '请输入 6 位短信验证码'
  if (mode.value === 'account' && !isValidAccount(form.username)) return '账号需为 2 到 20 位字母、数字、下划线或连字符'
  if (!form.password || form.password.length < 5 || form.password.length > 20) return '请输入 5 到 20 个字符的密码'
  if (form.password !== form.confirmPassword) return '两次输入的密码不一致'
  if (!form.agree) return '请先阅读并同意隐私政策和用户协议'
  return ''
}

async function handleSubmit() {
  error.value = validate()
  if (error.value) return

  loading.value = true
  try {
    const payload = mode.value === 'phone'
      ? { phone: form.phone, smsCode: form.smsCode, password: form.password }
      : { username: form.username, password: form.password, registerType: 'account_password' }
    await register(payload)
    ElMessage.success(mode.value === 'phone' ? '注册成功，请使用短信验证码登录' : '注册成功，请使用账号密码登录')
    await router.push({ path: '/login', query: mode.value === 'account' ? { mode: 'account' } : {} })
  } catch (requestError) {
    error.value = requestError?.message || '注册失败，请检查填写内容后重试'
  } finally {
    loading.value = false
  }
}

onBeforeUnmount(() => {
  if (cooldownTimer) window.clearInterval(cooldownTimer)
})
</script>

<style>
:root{--p:#1A3C6E;--b:#2B7FFF;--bg:#F5F7FA;--card:#fff;--text:#172B4D;--muted:#6B7A90;--line:#E6EBF2;--shadow:0 12px 35px rgba(26,60,110,.1)}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.6 "PingFang SC","Microsoft YaHei",system-ui,sans-serif}.topbar{height:72px;background:#fff;border-bottom:1px solid var(--line);display:flex;align-items:center}.topbar-inner{width:min(1240px,calc(100% - 48px));margin:auto;display:flex;align-items:center}.brand{display:flex;align-items:center;gap:10px;color:var(--p);text-decoration:none;font-weight:800;font-size:18px}.mark{width:34px;height:34px;border-radius:9px;display:grid;place-items:center;color:#fff;background:linear-gradient(145deg,#2B7FFF,#1A3C6E)}.hint{margin-left:auto;color:var(--muted);font-size:12px}.page{min-height:calc(100vh - 72px);display:grid;place-items:center;padding:36px 20px}.register-card{width:min(450px,100%);padding:34px 36px;border:1px solid var(--line);border-radius:14px;background:var(--card);box-shadow:var(--shadow)}h1{margin:0;color:var(--p);font-size:24px}.sub{margin:6px 0 22px;color:var(--muted);font-size:13px}.mode-tabs{display:grid;grid-template-columns:1fr 1fr;gap:4px;padding:4px;border-radius:8px;background:#F1F5FA}.mode-tab{height:36px;border:0;border-radius:6px;color:var(--muted);background:transparent;cursor:pointer;font-size:13px}.mode-tab.active{color:var(--p);background:#fff;box-shadow:0 2px 7px rgba(26,60,110,.1);font-weight:700}.field{margin-top:16px}.field label{display:block;margin-bottom:7px;font-weight:700;color:var(--p)}input{width:100%;height:44px;padding:0 13px;border:1px solid #D8E1ED;border-radius:8px;outline:none;background:#fff;color:var(--text)}input:focus{border-color:var(--b);box-shadow:0 0 0 3px rgba(43,127,255,.12)}.code-row{display:grid;grid-template-columns:1fr 122px;gap:10px}.code-button{height:44px;border:1px solid #BDD3F3;border-radius:8px;color:var(--b);background:#F7FAFF;cursor:pointer;font-size:12px}.code-button:hover:not(:disabled){background:#EAF2FF}.code-button:disabled{color:#9AA8BA;cursor:not-allowed}.dev-hint{margin:6px 0 0;color:#4E8A68;font-size:12px}.agree{display:flex;gap:8px;align-items:flex-start;margin-top:16px;color:var(--muted);font-size:12px}.agree input{width:16px;height:16px;margin-top:3px}.error{min-height:20px;margin:9px 0 0;color:#C34B55;font-size:12px}.primary{width:100%;height:44px;margin-top:24px;border:0;border-radius:8px;color:#fff;background:var(--b);font-weight:800;cursor:pointer}.primary:hover{background:#1C66D6}.primary:disabled{background:#9BBBEA;cursor:not-allowed}.footer-link{margin-top:18px;color:var(--muted);text-align:center;font-size:12px}.footer-link a{color:var(--b);font-weight:700;text-decoration:none}.footer-link a:hover{text-decoration:underline}@media(max-width:520px){.topbar-inner{width:calc(100% - 28px)}.register-card{padding:28px 22px}.code-row{grid-template-columns:1fr 112px}.mode-tab{font-size:12px}}
</style>
