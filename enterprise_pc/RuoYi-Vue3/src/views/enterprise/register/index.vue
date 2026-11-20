<template>
  <div class="register-page">
    <div class="register-card">
      <div class="card-head">
        <h1>企业入驻注册</h1>
        <p>提交后由平台审核，审核通过即可登录企业招聘中心。</p>
      </div>
      <el-form ref="formRef" :model="form" :rules="rules" label-width="96px">
        <el-divider content-position="left">企业信息</el-divider>
        <el-form-item label="企业名称" prop="companyName">
          <el-input v-model="form.companyName" placeholder="请输入营业执照上的企业全称" />
        </el-form-item>
        <el-form-item label="信用代码" prop="creditCode">
          <el-input v-model="form.creditCode" placeholder="统一社会信用代码（选填）" />
        </el-form-item>
        <el-form-item label="所属行业" prop="industry">
          <el-input v-model="form.industry" placeholder="如：互联网、制造业（选填）" />
        </el-form-item>
        <el-form-item label="所在城市" prop="city">
          <el-input v-model="form.city" placeholder="如：上海（选填）" />
        </el-form-item>
        <el-form-item label="企业规模" prop="companySize">
          <el-input v-model="form.companySize" placeholder="如：100-499人（选填）" />
        </el-form-item>

        <el-divider content-position="left">联系人</el-divider>
        <el-form-item label="联系人" prop="contactName">
          <el-input v-model="form.contactName" placeholder="请输入联系人姓名" />
        </el-form-item>
        <el-form-item label="手机号" prop="phone">
          <el-input v-model="form.phone" placeholder="请输入联系人手机号" />
        </el-form-item>
        <el-form-item label="邮箱" prop="email">
          <el-input v-model="form.email" placeholder="选填" />
        </el-form-item>

        <el-divider content-position="left">登录账号</el-divider>
        <el-form-item label="账号" prop="username">
          <el-input v-model="form.username" placeholder="2-20 个字符" />
        </el-form-item>
        <el-form-item label="密码" prop="password">
          <el-input v-model="form.password" type="password" show-password placeholder="5-20 个字符" />
        </el-form-item>
        <el-form-item label="确认密码" prop="confirmPassword">
          <el-input v-model="form.confirmPassword" type="password" show-password placeholder="再次输入密码" />
        </el-form-item>
        <el-form-item v-if="captchaEnabled" label="验证码" prop="code">
          <div class="captcha-row">
            <el-input v-model="form.code" placeholder="请输入验证码" @keyup.enter="handleSubmit" />
            <img :src="codeUrl" class="captcha-img" @click="getCode" />
          </div>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" :loading="loading" style="width: 100%" @click="handleSubmit">
            提交入驻申请
          </el-button>
        </el-form-item>
      </el-form>
      <div class="card-foot">
        <router-link to="/enterprise/portal">先逛逛，浏览公开岗位</router-link>
        <span class="divider">|</span>
        <router-link to="/enterprise/login">已有账号，去登录</router-link>
      </div>
    </div>
  </div>
</template>

<script setup>
import { getCurrentInstance, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessageBox } from 'element-plus'
import { getCodeImg } from '@/api/login'
import { registerEnterprise } from '@/api/portal'

const router = useRouter()
const { proxy } = getCurrentInstance()

const form = reactive({
  companyName: '',
  creditCode: '',
  industry: '',
  city: '',
  companySize: '',
  contactName: '',
  phone: '',
  email: '',
  username: '',
  password: '',
  confirmPassword: '',
  code: '',
  uuid: ''
})

const validateConfirm = (rule, value, callback) => {
  if (form.password !== value) {
    callback(new Error('两次输入的密码不一致'))
  } else {
    callback()
  }
}

const rules = {
  companyName: [{ required: true, message: '请输入企业名称', trigger: 'blur' }],
  contactName: [{ required: true, message: '请输入联系人', trigger: 'blur' }],
  phone: [
    { required: true, message: '请输入手机号', trigger: 'blur' },
    { pattern: /^1[3-9]\d{9}$/, message: '请输入正确的手机号', trigger: 'blur' }
  ],
  username: [
    { required: true, message: '请输入账号', trigger: 'blur' },
    { min: 2, max: 20, message: '账号长度必须介于 2 和 20 之间', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 5, max: 20, message: '密码长度必须介于 5 和 20 之间', trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, message: '请再次输入密码', trigger: 'blur' },
    { validator: validateConfirm, trigger: 'blur' }
  ],
  code: [{ required: true, message: '请输入验证码', trigger: 'change' }]
}

const loading = ref(false)
const captchaEnabled = ref(true)
const codeUrl = ref('')

function getCode() {
  getCodeImg().then(res => {
    captchaEnabled.value = res.captchaEnabled === undefined ? true : res.captchaEnabled
    if (captchaEnabled.value) {
      codeUrl.value = 'data:image/gif;base64,' + res.img
      form.uuid = res.uuid
    }
  })
}

function handleSubmit() {
  proxy.$refs.formRef.validate(valid => {
    if (!valid) return
    loading.value = true
    registerEnterprise({ ...form })
      .then(() => {
        ElMessageBox.alert('企业入驻申请已提交，请等待平台审核。审核通过后即可使用账号登录。', '提交成功', {
          type: 'success'
        })
          .then(() => router.push('/enterprise/login'))
          .catch(() => {})
      })
      .catch(() => {
        if (captchaEnabled.value) getCode()
      })
      .finally(() => {
        loading.value = false
      })
  })
}

getCode()
</script>

<style lang="scss" scoped>
.register-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 40px 20px;
  background: linear-gradient(135deg, #1e3fae 0%, #2f6bff 55%, #6b9bff 100%);
}
.register-card {
  width: 640px;
  max-width: 100%;
  background: #fff;
  border-radius: 14px;
  padding: 32px 36px 26px;
  box-shadow: 0 18px 48px rgba(11, 39, 110, 0.24);
}
.card-head {
  margin-bottom: 16px;
  h1 {
    margin: 0 0 8px;
    font-size: 22px;
    color: #1f2733;
  }
  p {
    margin: 0;
    color: #8a94a6;
    font-size: 13px;
  }
}
.captcha-row {
  display: flex;
  gap: 12px;
  width: 100%;
}
.captcha-img {
  height: 32px;
  cursor: pointer;
  border-radius: 4px;
}
.card-foot {
  text-align: center;
  font-size: 13px;
  color: #8a94a6;
  a {
    color: #2f6bff;
    text-decoration: none;
  }
  .divider {
    margin: 0 10px;
    color: #d5dbe5;
  }
}
</style>
