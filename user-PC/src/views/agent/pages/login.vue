<template>
  <header class="topbar">
    <div class="topbar-inner">
      <a class="brand" href="/agent/index"><span class="mark">智</span>智聘 AI</a>
      <span class="hint">候选人安全登录</span>
    </div>
  </header>

  <main class="page">
    <section class="login-card">
      <h1>登录候选人工作台</h1>
      <p class="sub">使用账号密码登录，继续管理你的求职进度</p>

      <form novalidate @submit.prevent="handleSubmit">
        <div class="field">
          <label for="username">账号</label>
          <input
            id="username"
            v-model.trim="form.username"
            autocomplete="username"
            maxlength="20"
            placeholder="请输入账号"
          >
        </div>

        <div class="field">
          <label for="password">密码</label>
          <input
            id="password"
            v-model="form.password"
            autocomplete="current-password"
            maxlength="20"
            placeholder="请输入密码"
            type="password"
          >
        </div>

        <div v-if="captchaEnabled" class="field">
          <label for="code">验证码</label>
          <div class="captcha-row">
            <input
              id="code"
              v-model.trim="form.code"
              autocomplete="off"
              maxlength="6"
              placeholder="请输入验证码"
            >
            <button class="captcha-image" type="button" title="点击刷新验证码" @click="getCode">
              <img v-if="codeUrl" :src="codeUrl" alt="验证码">
              <span v-else>加载中</span>
            </button>
          </div>
        </div>

        <p v-if="error" class="error" role="alert">{{ error }}</p>

        <label class="agree">
          <input v-model="form.agree" type="checkbox">
          <span>我已阅读并同意《隐私政策》和《用户协议》</span>
        </label>

        <button class="primary" :disabled="loading" type="submit">
          {{ loading ? '登录中...' : '登录' }}
        </button>
      </form>

      <div class="footer-link">
        还没有账号？
        <a href="/agent/register">立即注册</a>
      </div>
    </section>
  </main>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import { getCodeImg } from '@/api/login'
import useUserStore from '@/store/modules/user'
import { clearCandidateSession } from '@/utils/agentSession'
import { removeToken } from '@/utils/auth'

const route = useRoute()
const router = useRouter()
const userStore = useUserStore()

const form = reactive({
  username: '',
  password: '',
  code: '',
  uuid: '',
  agree: false
})
const error = ref('')
const loading = ref(false)
const captchaEnabled = ref(true)
const codeUrl = ref('')

async function getCode() {
  try {
    const res = await getCodeImg()
    captchaEnabled.value = res.captchaEnabled !== false
    codeUrl.value = captchaEnabled.value && res.img ? `data:image/gif;base64,${res.img}` : ''
    form.uuid = res.uuid || ''
  } catch {
    error.value = '验证码加载失败，请稍后重试'
  }
}

function validate() {
  if (!form.username || form.username.length < 2 || form.username.length > 20) {
    return '请输入 2 到 20 个字符的账号'
  }
  if (!form.password || form.password.length < 5 || form.password.length > 20) {
    return '请输入 5 到 20 个字符的密码'
  }
  if (captchaEnabled.value && !form.code) {
    return '请输入验证码'
  }
  if (!form.agree) {
    return '请先阅读并同意隐私政策和用户协议'
  }
  return ''
}

async function handleSubmit() {
  error.value = validate()
  if (error.value) return

  loading.value = true
  clearCandidateSession()
  removeToken()
  try {
    await userStore.login(form)
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/agent/index'
    await router.push(redirect.startsWith('/agent') ? redirect : '/agent/index')
  } catch {
    error.value = '登录失败，请检查账号、密码和验证码'
    if (captchaEnabled.value) await getCode()
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  clearCandidateSession()
  getCode()
})
</script>

<style>
:root{--p:#1A3C6E;--b:#2B7FFF;--bg:#F5F7FA;--card:#fff;--text:#172B4D;--muted:#6B7A90;--line:#E6EBF2;--soft:#EAF2FF;--shadow:0 12px 35px rgba(26,60,110,.1)}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.6 "PingFang SC","Microsoft YaHei",system-ui,sans-serif}.topbar{height:72px;background:#fff;border-bottom:1px solid var(--line);display:flex;align-items:center}.topbar-inner{width:min(1240px,calc(100% - 48px));margin:auto;display:flex;align-items:center}.brand{display:flex;align-items:center;gap:10px;color:var(--p);text-decoration:none;font-weight:800;font-size:18px}.mark{width:34px;height:34px;border-radius:9px;display:grid;place-items:center;color:#fff;background:linear-gradient(145deg,#2B7FFF,#1A3C6E)}.hint{margin-left:auto;color:var(--muted);font-size:12px}.page{min-height:calc(100vh - 72px);display:grid;place-items:center;padding:36px 20px}.login-card{width:min(430px,100%);padding:34px 36px;border:1px solid var(--line);border-radius:14px;background:var(--card);box-shadow:var(--shadow)}h1{margin:0;color:var(--p);font-size:24px}.sub{margin:6px 0 26px;color:var(--muted);font-size:13px}.field{margin-top:16px}.field label{display:block;margin-bottom:7px;font-weight:700;color:var(--p)}input{width:100%;height:44px;padding:0 13px;border:1px solid #D8E1ED;border-radius:8px;outline:none;background:#fff;color:var(--text)}input:focus{border-color:var(--b);box-shadow:0 0 0 3px rgba(43,127,255,.12)}.captcha-row{display:grid;grid-template-columns:1fr 126px;gap:10px}.captcha-image{height:44px;padding:0;border:1px solid #D8E1ED;border-radius:8px;overflow:hidden;color:var(--muted);background:#F6F9FD;cursor:pointer}.captcha-image img{display:block;width:100%;height:100%;object-fit:cover}.agree{display:flex;gap:8px;align-items:flex-start;margin-top:16px;color:var(--muted);font-size:12px}.agree input{width:16px;height:16px;margin-top:3px}.error{min-height:20px;margin:9px 0 0;color:#C34B55;font-size:12px}.primary{width:100%;height:44px;margin-top:24px;border:0;border-radius:8px;color:#fff;background:var(--b);font-weight:800;cursor:pointer}.primary:hover{background:#1C66D6}.primary:disabled{background:#9BBBEA;cursor:not-allowed}.footer-link{margin-top:18px;color:var(--muted);text-align:center;font-size:12px}.footer-link a{color:var(--b);font-weight:700;text-decoration:none}.footer-link a:hover{text-decoration:underline}@media(max-width:520px){.topbar-inner{width:calc(100% - 28px)}.login-card{padding:28px 22px}}
</style>
