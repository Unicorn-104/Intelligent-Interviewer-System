<template>
  <div class="login-page">
    <header class="login-header">
      <div class="header-inner">
        <router-link class="brand" to="/enterprise/portal">
          <span class="brand-mark">AI</span>
          <span class="brand-text">慧科智聘</span>
        </router-link>
        <nav class="nav">
          <router-link to="/enterprise/portal" exact-active-class="active">首页</router-link>
          <router-link to="/enterprise/portal/features" active-class="active">平台能力</router-link>
          <router-link to="/enterprise/portal/onboarding" active-class="active">入驻流程</router-link>
        </nav>
        <div class="actions">
          <router-link class="btn" to="/enterprise/portal">返回门户</router-link>
          <router-link class="btn primary" to="/enterprise/register">企业注册</router-link>
        </div>
      </div>
    </header>

    <main class="login-main">
      <div class="login-main-inner">
        <section class="login-intro">
          <p class="eyebrow">企业招聘管理平台</p>
          <h1>让企业招聘更智能、更高效</h1>
          <p class="desc">登录企业招聘中心，统一管理岗位、候选人与面试流程。</p>
          <ul class="points">
            <li>岗位发布与招聘流程配置</li>
            <li>AI 简历筛选与候选人排序</li>
            <li>面试安排、在线笔试与人才库</li>
            <li>招聘数据看板与组织权限管理</li>
          </ul>
        </section>

        <section class="login-card">
          <h2>登录企业招聘中心</h2>
          <p class="sub">使用企业管理员或成员账号登录</p>

          <el-form ref="loginRef" :model="loginForm" :rules="loginRules" class="login-form">
            <el-form-item prop="username">
              <el-input
                v-model="loginForm.username"
                type="text"
                size="large"
                auto-complete="off"
                placeholder="账号"
              >
                <template #prefix><svg-icon icon-class="user" class="el-input__icon input-icon" /></template>
              </el-input>
            </el-form-item>
            <el-form-item prop="password">
              <el-input
                v-model="loginForm.password"
                type="password"
                size="large"
                auto-complete="off"
                placeholder="密码"
                @keyup.enter="handleLogin"
              >
                <template #prefix><svg-icon icon-class="password" class="el-input__icon input-icon" /></template>
              </el-input>
            </el-form-item>
            <el-form-item prop="code" v-if="captchaEnabled">
              <div class="captcha-row">
                <el-input
                  v-model="loginForm.code"
                  size="large"
                  auto-complete="off"
                  placeholder="验证码"
                  @keyup.enter="handleLogin"
                >
                  <template #prefix><svg-icon icon-class="validCode" class="el-input__icon input-icon" /></template>
                </el-input>
                <img :src="codeUrl" @click="getCode" class="login-code-img" />
              </div>
            </el-form-item>
            <div class="remember-row">
              <el-checkbox v-model="loginForm.rememberMe">记住密码</el-checkbox>
            </div>
            <el-button class="submit-btn" :loading="loading" size="large" type="primary" @click.prevent="handleLogin">
              <span v-if="!loading">登 录</span>
              <span v-else>登 录 中...</span>
            </el-button>
          </el-form>

          <div class="portal-entry">
            <router-link class="link-type" to="/enterprise/portal">先逛逛，了解平台能力</router-link>
            <router-link class="link-type" to="/enterprise/register">企业入驻注册</router-link>
          </div>
        </section>
      </div>
    </main>

    <footer class="login-footer">
      © 2026 智能面试官系统 · 企业招聘管理平台
    </footer>
  </div>
</template>

<script setup>
import { getCodeImg } from "@/api/login";
import Cookies from "js-cookie";
import { encrypt, decrypt } from "@/utils/jsencrypt";
import useUserStore from '@/store/modules/user'

const userStore = useUserStore()
const route = useRoute();
const router = useRouter();
const { proxy } = getCurrentInstance();

const loginForm = ref({
  username: "admin",
  password: "admin123",
  rememberMe: false,
  code: "",
  uuid: ""
});

const loginRules = {
  username: [{ required: true, trigger: "blur", message: "请输入您的账号" }],
  password: [{ required: true, trigger: "blur", message: "请输入您的密码" }],
  code: [{ required: true, trigger: "change", message: "请输入验证码" }]
};

const codeUrl = ref("");
const loading = ref(false);
// 验证码开关
const captchaEnabled = ref(true);
const redirect = ref(undefined);

watch(route, (newRoute) => {
    redirect.value = newRoute.query && newRoute.query.redirect;
}, { immediate: true });

function handleLogin() {
  proxy.$refs.loginRef.validate(valid => {
    if (valid) {
      loading.value = true;
      // 勾选了需要记住密码设置在 cookie 中设置记住用户名和密码
      if (loginForm.value.rememberMe) {
        Cookies.set("username", loginForm.value.username, { expires: 30 });
        Cookies.set("password", encrypt(loginForm.value.password), { expires: 30 });
        Cookies.set("rememberMe", loginForm.value.rememberMe, { expires: 30 });
      } else {
        // 否则移除
        Cookies.remove("username");
        Cookies.remove("password");
        Cookies.remove("rememberMe");
      }
      // 调用action的登录方法
      userStore.login(loginForm.value).then(() => {
        const query = route.query;
        const otherQueryParams = Object.keys(query).reduce((acc, cur) => {
          if (cur !== "redirect") {
            acc[cur] = query[cur];
          }
          return acc;
        }, {});
        router.push(redirect.value ? redirect.value : { path: "/enterprise/dashboard", query: otherQueryParams });
      }).catch(() => {
        loading.value = false;
        // 重新获取验证码
        if (captchaEnabled.value) {
          getCode();
        }
      });
    }
  });
}

function getCode() {
  getCodeImg().then(res => {
    captchaEnabled.value = res.captchaEnabled === undefined ? true : res.captchaEnabled;
    if (captchaEnabled.value) {
      codeUrl.value = "data:image/gif;base64," + res.img;
      loginForm.value.uuid = res.uuid;
    }
  });
}

function getCookie() {
  const username = Cookies.get("username");
  const password = Cookies.get("password");
  const rememberMe = Cookies.get("rememberMe");
  loginForm.value = {
    username: username === undefined ? loginForm.value.username : username,
    password: password === undefined ? loginForm.value.password : decrypt(password),
    rememberMe: rememberMe === undefined ? false : Boolean(rememberMe)
  };
}

getCode();
getCookie();
</script>

<style lang='scss' scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background: #f5f7fb;
  color: #1f2733;
}
.login-header {
  background: #fff;
  border-bottom: 1px solid #e8ecf2;
}
.header-inner {
  max-width: 1180px;
  margin: 0 auto;
  height: 64px;
  padding: 0 20px;
  display: flex;
  align-items: center;
  gap: 40px;
}
.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  text-decoration: none;
  color: #1f2733;
}
.brand-mark {
  width: 32px;
  height: 32px;
  border-radius: 9px;
  background: linear-gradient(135deg, #2f6bff, #5a8bff);
  color: #fff;
  font-size: 13px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
}
.brand-text {
  font-size: 17px;
  font-weight: 600;
}
.nav {
  display: flex;
  gap: 24px;
  flex: 1;
  a {
    color: #5a6577;
    text-decoration: none;
    font-size: 15px;
    padding: 6px 0;
    border-bottom: 2px solid transparent;
    &.active {
      color: #2f6bff;
      border-bottom-color: #2f6bff;
    }
  }
}
.actions {
  display: flex;
  gap: 12px;
  align-items: center;
}
.btn {
  padding: 8px 18px;
  border-radius: 8px;
  font-size: 14px;
  text-decoration: none;
  color: #2f6bff;
  border: 1px solid #c8d7ff;
  background: #fff;
  &.primary {
    background: #2f6bff;
    border-color: #2f6bff;
    color: #fff;
  }
}
.login-main {
  flex: 1;
  background: linear-gradient(135deg, #1e3fae 0%, #2f6bff 55%, #6b9bff 100%);
  display: flex;
  align-items: center;
  padding: 52px 20px 60px;
}
.login-main-inner {
  width: 100%;
  max-width: 1180px;
  margin: 0 auto;
  display: grid;
  grid-template-columns: 1fr 420px;
  gap: 64px;
  align-items: center;
}
.login-intro {
  color: #fff;
  .eyebrow {
    margin: 0 0 14px;
    font-size: 13px;
    letter-spacing: 2px;
    color: rgba(255, 255, 255, 0.75);
  }
  h1 {
    margin: 0 0 16px;
    font-size: 36px;
    line-height: 1.35;
  }
  .desc {
    margin: 0 0 24px;
    font-size: 15px;
    line-height: 1.8;
    color: rgba(255, 255, 255, 0.86);
  }
  .points {
    margin: 0;
    padding: 0;
    list-style: none;
    li {
      position: relative;
      padding-left: 18px;
      margin-bottom: 12px;
      font-size: 14px;
      color: rgba(255, 255, 255, 0.88);
      &::before {
        content: '';
        position: absolute;
        left: 0;
        top: 7px;
        width: 7px;
        height: 7px;
        border-radius: 2px;
        background: rgba(255, 255, 255, 0.8);
      }
    }
  }
}
.login-card {
  background: #fff;
  border-radius: 14px;
  padding: 34px 34px 26px;
  box-shadow: 0 18px 48px rgba(11, 39, 110, 0.24);
  h2 {
    margin: 0 0 6px;
    font-size: 21px;
  }
  .sub {
    margin: 0 0 24px;
    color: #8a94a6;
    font-size: 13px;
  }
}
.login-form {
  :deep(.el-input__wrapper) {
    border-radius: 8px;
  }
  :deep(.el-form-item) {
    margin-bottom: 20px;
  }
  .input-icon {
    width: 14px;
    height: 14px;
  }
}
.captcha-row {
  display: flex;
  gap: 12px;
  width: 100%;
  .login-code-img {
    height: 40px;
    cursor: pointer;
    border-radius: 6px;
    flex-shrink: 0;
  }
}
.remember-row {
  margin-bottom: 20px;
}
.submit-btn {
  width: 100%;
  height: 44px;
  border-radius: 8px;
  font-size: 15px;
  background: #2f6bff;
  border-color: #2f6bff;
}
.portal-entry {
  margin-top: 18px;
  padding-top: 16px;
  border-top: 1px solid #eef1f6;
  display: flex;
  justify-content: space-between;
  font-size: 13px;
  .link-type {
    color: #2f6bff;
    text-decoration: none;
  }
}
.login-footer {
  padding: 20px;
  text-align: center;
  color: #9aa4b2;
  font-size: 12px;
}
@media (max-width: 900px) {
  .login-main-inner {
    grid-template-columns: 1fr;
    gap: 32px;
  }
  .login-intro h1 {
    font-size: 28px;
  }
  .nav {
    display: none;
  }
}
</style>
