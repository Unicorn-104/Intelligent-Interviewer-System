<template>
<header class="topbar"><div class="topbar-inner"><a class="brand" href="/agent/index"><span class="mark">智</span>智聘 AI</a><span class="hint">候选人安全登录</span></div></header><main class="page"><section class="login-card"><h1>登录候选人工作台</h1><p class="sub">使用手机号接收验证码，无需设置密码</p><form id="loginForm" novalidate @submit.prevent="handleSubmit"><div class="field"><label for="phone">手机号</label><input id="phone" v-model.trim="form.phone" inputmode="numeric" maxlength="11" placeholder="请输入 11 位手机号" autocomplete="tel"></div><div class="field"><label for="code">短信验证码</label><div class="code-row"><input id="code" v-model.trim="form.code" inputmode="numeric" maxlength="6" placeholder="请输入 6 位验证码" autocomplete="one-time-code"><button class="code-btn" id="sendCode" type="button" :disabled="countdown > 0" @click="sendCode">{{ countdown > 0 ? `${countdown}s 后重发` : sendText }}</button></div></div><div class="error" id="error" role="alert">{{ error }}</div><label class="agree"><input id="agree" v-model="form.agree" type="checkbox"><span>我已阅读并同意《隐私政策》和《用户协议》，了解面试数据的使用范围。</span></label><button class="primary" type="submit">登录</button></form><div class="demo"><b>演示提示：</b>输入任意 11 位手机号，验证码可填写 <b>123456</b>。</div></section></main>
</template>

<script setup>
import { computed, onBeforeUnmount, reactive, ref } from 'vue'
import { setCandidateSession } from '@/utils/agentSession'
import { isValidPhoneNumber, isValidSmsCode } from '@/utils/agentValidation'

const DEMO_CODE = '123456'
const SESSION_TTL = 24 * 60 * 60 * 1000

const form = reactive({
  phone: '',
  code: '',
  agree: false
})
const error = ref('')
const countdown = ref(0)
let timer = null

const sendText = computed(() => (countdown.value === 0 ? '获取验证码' : '重新获取'))

function startCountdown() {
  countdown.value = 60
  timer = window.setInterval(() => {
    countdown.value -= 1
    if (countdown.value <= 0) {
      window.clearInterval(timer)
      timer = null
      countdown.value = 0
    }
  }, 1000)
}

function sendCode() {
  error.value = ''
  if (!isValidPhoneNumber(form.phone)) {
    error.value = '请先输入正确的 11 位手机号'
    document.getElementById('phone')?.focus()
    return
  }
  startCountdown()
}

function createDemoAccessToken(phone) {
  return `candidate-demo-${phone}-${Date.now()}`
}

function handleSubmit() {
  error.value = ''
  if (!isValidPhoneNumber(form.phone)) {
    error.value = '手机号格式不正确'
    document.getElementById('phone')?.focus()
    return
  }
  if (!isValidSmsCode(form.code) || form.code !== DEMO_CODE) {
    error.value = '验证码不正确，请输入演示验证码 123456'
    document.getElementById('code')?.focus()
    return
  }
  if (!form.agree) {
    error.value = '请先阅读并同意隐私政策和用户协议'
    document.getElementById('agree')?.focus()
    return
  }

  const now = Date.now()
  setCandidateSession({
    phone: form.phone,
    loginAt: now,
    expiresAt: now + SESSION_TTL,
    accessToken: createDemoAccessToken(form.phone)
  })
  window.__agentNavigate(new URLSearchParams(location.search).get('redirect') || '/agent/index')
}

onBeforeUnmount(() => {
  if (timer) window.clearInterval(timer)
})
</script>

<style>
:root{--p:#1A3C6E;--b:#2B7FFF;--bg:#F5F7FA;--card:#fff;--text:#172B4D;--muted:#6B7A90;--line:#E6EBF2;--soft:#EAF2FF;--shadow:0 12px 35px rgba(26,60,110,.1)}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.6 "PingFang SC","Microsoft YaHei",system-ui,sans-serif}.topbar{height:72px;background:#fff;border-bottom:1px solid var(--line);display:flex;align-items:center}.topbar-inner{width:min(1240px,calc(100% - 48px));margin:auto;display:flex;align-items:center}.brand{display:flex;align-items:center;gap:10px;color:var(--p);text-decoration:none;font-weight:800;font-size:18px}.mark{width:34px;height:34px;border-radius:9px;display:grid;place-items:center;color:#fff;background:linear-gradient(145deg,#2B7FFF,#1A3C6E)}.hint{margin-left:auto;color:var(--muted);font-size:12px}.page{min-height:calc(100vh - 72px);display:grid;place-items:center;padding:36px 20px}.login-card{width:min(430px,100%);padding:34px 36px;border:1px solid var(--line);border-radius:14px;background:var(--card);box-shadow:var(--shadow)}h1{margin:0;color:var(--p);font-size:24px}.sub{margin:6px 0 26px;color:var(--muted);font-size:13px}.field{margin-top:16px}.field label{display:block;margin-bottom:7px;font-weight:700;color:var(--p)}input{width:100%;height:44px;padding:0 13px;border:1px solid #D8E1ED;border-radius:8px;outline:none;background:#fff;color:var(--text)}input:focus{border-color:var(--b);box-shadow:0 0 0 3px rgba(43,127,255,.12)}.code-row{display:grid;grid-template-columns:1fr 116px;gap:10px}.code-btn,.primary,.ghost{height:44px;border:0;border-radius:8px;font-weight:800;cursor:pointer}.code-btn{border:1px solid #C9D7E8;color:var(--b);background:var(--soft)}.code-btn:disabled{color:#9AA8BA;background:#F2F5F9;cursor:not-allowed}.primary{width:100%;margin-top:24px;color:#fff;background:var(--b)}.primary:hover{background:#1C66D6}.agree{display:flex;gap:8px;align-items:flex-start;margin-top:16px;color:var(--muted);font-size:12px}.agree input{width:16px;height:16px;margin-top:3px}.error{min-height:20px;margin-top:9px;color:#C34B55;font-size:12px}.demo{margin-top:18px;padding:11px 12px;border-radius:8px;color:#52647D;background:#F6F9FD;font-size:12px}.demo b{color:var(--p)}@media(max-width:520px){.topbar-inner{width:calc(100% - 28px)}.login-card{padding:28px 22px}}
</style>
