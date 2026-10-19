<script setup>
import { ref, reactive, onMounted, computed, nextTick } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Camera, Pencil, ShieldCheck, KeyRound, MessageCircle, Smartphone, Mail, Clock3, Globe2, BellRing, FileText, MessageSquare, Megaphone, Save } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import SwitchToggle from '@/views/enterprise/components/SwitchToggle.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { getUserProfile, updateUserProfile, updateUserPwd, uploadAvatar } from '@/api/system/user'
import { getMailProfile, saveMailProfile } from '@/api/offer'
import useUserStore from '@/store/modules/user'

const userStore = useUserStore()

const active = ref('个人资料')
const toast = ref('')

// 用户资料表单（可保存到后端）
const profileForm = reactive({
  nickName: '',
  email: '',
  phonenumber: '',
  sex: '0',
  remark: ''
})

// 展示态字段（从 getUserProfile 回填，不参与提交）
const display = reactive({
  userName: '',
  avatar: '',
  deptName: '',
  loginIp: '',
  loginDate: ''
})

// 偏好设置（localStorage 本地持久化）
const prefsForm = reactive({
  interviewDuration: '45min',
  calendarSync: 'both',
  notifyFreq: 'realtime',
  language: 'zh-CN',
  timezone: 'Asia/Shanghai'
})

// 通知设置（localStorage 本地持久化）
const notices = ref([
  { title: '面试提醒', desc: '面试开始前 30 分钟提醒', icon: Clock3, on: true },
  { title: '简历入库', desc: '有新候选人投递时通知', icon: FileText, on: true },
  { title: '候选人消息', desc: '收到候选人新消息时通知', icon: MessageSquare, on: true },
  { title: '系统更新', desc: '产品更新与维护公告', icon: Megaphone, on: false }
])

// 修改密码弹窗
const pwdDialogVisible = ref(false)
const pwdForm = reactive({ oldPassword: '', newPassword: '', confirmPassword: '' })
const pwdLoading = ref(false)

// 头像上传 loading
const avatarLoading = ref(false)

const heroName = computed(() => profileForm.nickName || display.userName || '未登录')
const heroDept = computed(() => display.deptName || '未分配部门')

function notify(m) { toast.value = m; setTimeout(() => toast.value = '', 2000) }

// ---------- 加载用户数据 ----------
async function loadProfile() {
  try {
    const res = await getUserProfile()
    const u = res.data || {}
    profileForm.nickName = u.nickName || ''
    profileForm.email = u.email || ''
    profileForm.phonenumber = u.phonenumber || ''
    profileForm.sex = u.sex || '0'
    profileForm.remark = u.remark || ''
    display.userName = u.userName || ''
    display.avatar = u.avatar ? (import.meta.env.VITE_APP_BASE_API + u.avatar) : ''
    display.deptName = u.dept?.deptName || ''
    display.loginIp = u.loginIp || ''
    display.loginDate = u.loginDate || ''
  } catch (e) {
    ElMessage.error('加载用户信息失败')
  }
}

// ---------- 保存基本信息 ----------
async function saveProfile() {
  try {
    await updateUserProfile({
      nickName: profileForm.nickName,
      email: profileForm.email,
      phonenumber: profileForm.phonenumber,
      sex: profileForm.sex,
      remark: profileForm.remark
    })
    // 同步 Pinia 用户信息，让 Topbar 实时刷新
    userStore.nickName = profileForm.nickName
    ElMessage.success('保存成功')
  } catch (e) {
    ElMessage.error(e?.message || '保存失败')
  }
}

// ---------- 取消编辑（回填原始值） ----------
function cancelEdit() {
  loadProfile()
  notify('修改已取消')
}

// ---------- 修改密码 ----------
function openPwdDialog() {
  pwdForm.oldPassword = ''
  pwdForm.newPassword = ''
  pwdForm.confirmPassword = ''
  pwdDialogVisible.value = true
}
async function submitPwd() {
  if (!pwdForm.oldPassword) return ElMessage.warning('请输入旧密码')
  if (!pwdForm.newPassword) return ElMessage.warning('请输入新密码')
  if (pwdForm.newPassword !== pwdForm.confirmPassword) return ElMessage.warning('两次新密码不一致')
  pwdLoading.value = true
  try {
    await updateUserPwd(pwdForm.oldPassword, pwdForm.newPassword)
    ElMessage.success('密码修改成功')
    pwdDialogVisible.value = false
  } catch (e) {
    ElMessage.error(e?.message || '密码修改失败')
  } finally {
    pwdLoading.value = false
  }
}

// ---------- 头像上传 ----------
async function handleAvatarChange(e) {
  const file = e.target.files?.[0]
  // 清空 input，保证选同一个文件也能触发 change
  e.target.value = ''
  if (!file) return
  // 类型校验（与后端 MimeTypeUtils.IMAGE_EXTENSION 保持一致）
  if (!/\.(jpe?g|png|gif|bmp|webp)$/i.test(file.name)) {
    return ElMessage.warning('图片格式仅限 jpg、jpeg、png、gif、bmp、webp')
  }
  if (file.size / 1024 / 1024 >= 5) {
    return ElMessage.warning('图片大小不能超过 5MB')
  }
  avatarLoading.value = true
  try {
    const fd = new FormData()
    fd.append('avatarfile', file)
    // 后端 AjaxResult 将 imgUrl 放在响应体顶层，而非 data 字段
    const res = await uploadAvatar(fd)
    const imgUrl = res?.imgUrl
    if (imgUrl) {
      // 加时间戳避免浏览器缓存同名旧图
      const fullUrl = import.meta.env.VITE_APP_BASE_API + imgUrl + '?t=' + Date.now()
      display.avatar = fullUrl
      userStore.avatar = fullUrl
      ElMessage.success('头像上传成功')
    } else {
      ElMessage.error(res?.msg || '头像上传失败，请联系管理员')
    }
  } catch (err) {
    ElMessage.error(err?.message || '头像上传失败')
  } finally {
    avatarLoading.value = false
  }
}

// ---------- 偏好设置（localStorage 本地持久化） ----------
function savePreferences() {
  try {
    localStorage.setItem('pref_settings', JSON.stringify(prefsForm))
    ElMessage.success('偏好设置已保存')
  } catch (e) {
    ElMessage.error('保存失败')
  }
}
function loadPreferences() {
  const raw = localStorage.getItem('pref_settings')
  if (raw) {
    try { Object.assign(prefsForm, JSON.parse(raw)) } catch {}
  }
}

// ---------- 通知设置（localStorage 本地持久化） ----------
function saveNotices() {
  try {
    localStorage.setItem('notice_settings', JSON.stringify(notices.value.map(n => ({ title: n.title, on: n.on }))))
    ElMessage.success('通知设置已保存')
  } catch (e) {
    ElMessage.error('保存失败')
  }
}
function loadNotices() {
  const raw = localStorage.getItem('notice_settings')
  if (raw) {
    try {
      const saved = JSON.parse(raw)
      notices.value.forEach(n => {
        const match = saved.find(s => s.title === n.title)
        if (match) n.on = match.on
      })
    } catch {}
  }
}

// ---------- 账号安全（暂缺后端接口，保留提示） ----------
function securityPlaceholder(label) {
  notify(`${label} 接口待后端实现`)
}

// ---------- 邮箱与发信设置 ----------
const mail = reactive({
  companyEmail: '',
  configured: false,
  smtpHost: '',
  smtpPort: '',
  ssl: 1,
  username: '',
  password: ''
})
const mailLoading = ref(false)

async function loadMailProfile() {
  try {
    const res = await getMailProfile()
    const d = res.data || {}
    mail.companyEmail = d.companyEmail || ''
    mail.configured = !!d.configured
    mail.smtpHost = d.smtpHost || ''
    mail.smtpPort = d.smtpPort ?? ''
    mail.ssl = d.ssl ?? 1
    mail.username = d.username || ''
    mail.password = ''
  } catch (e) { /* 拦截器已提示 */ }
}

async function saveMailConfig() {
  if (!mail.smtpHost || !mail.username || !mail.smtpPort) {
    return ElMessage.warning('请填写 SMTP 服务器、端口与认证账号')
  }
  if (!mail.configured && !mail.password) {
    return ElMessage.warning('首次保存请填写邮箱授权码')
  }
  mailLoading.value = true
  try {
    const res = await saveMailProfile({
      smtpHost: mail.smtpHost,
      smtpPort: Number(mail.smtpPort),
      ssl: Number(mail.ssl),
      username: mail.username,
      password: mail.password
    })
    mail.configured = !!(res.data?.configured)
    mail.password = ''
    ElMessage.success(res.data?.message || '保存成功')
  } catch (e) {
    ElMessage.error(e?.message || '保存失败')
  } finally {
    mailLoading.value = false
  }
}

onMounted(() => {
  loadProfile()
  loadMailProfile()
  loadPreferences()
  loadNotices()
})
</script>

<template>
  <div class="page profile-page">
    <!-- Hero 头像区 -->
    <section class="card profile-hero">
      <div class="avatar-wrap">
        <MiniAvatar :name="heroName" :size="76" color="#8d5579" :src="display.avatar" />
        <label class="avatar-upload" :class="{loading:avatarLoading}" :title="avatarLoading ? '上传中…' : '更换头像'">
          <span v-if="avatarLoading" class="avatar-spinner"></span>
          <Camera v-else :size="13" />
          <input type="file" accept="image/*" style="display:none" :disabled="avatarLoading" @change="handleAvatarChange" />
        </label>
      </div>
      <div>
        <h1>{{ heroName }} <span class="pill">招聘管理员</span></h1>
        <p>高级招聘经理 · {{ heroDept }}</p>
        <small>登录账号 {{ display.userName }} · 最近登录：{{ display.loginDate || '--' }}</small>
      </div>
      <button class="btn primary" @click="active = '个人资料'; nextTick(() => document.querySelector('.form-card')?.scrollIntoView({behavior:'smooth'}))">
        <Pencil :size="16" />编辑资料
      </button>
    </section>

    <!-- Tab 切换 -->
    <nav class="card tabs">
      <button v-for="tab in ['个人资料','偏好设置','通知设置']" :key="tab" :class="{active:active===tab}" @click="active=tab">{{tab}}</button>
    </nav>

    <!-- ============ 个人资料 Tab ============ -->
    <template v-if="active==='个人资料'">
    <div class="profile-grid">
      <!-- 基本信息表单 -->
      <section class="card form-card">
        <div class="section-title">
          <div><h2>基本信息</h2><p>以下信息将在招聘流程中同步展示给候选人</p></div>
        </div>
        <div class="form-fields">
          <div class="field">
            <label>姓名</label>
            <input class="input" v-model="profileForm.nickName" placeholder="请输入姓名" />
          </div>
          <div class="field">
            <label>手机号</label>
            <input class="input" v-model="profileForm.phonenumber" placeholder="请输入手机号" maxlength="11" />
          </div>
          <div class="field">
            <label>邮箱</label>
            <input class="input" v-model="profileForm.email" placeholder="请输入邮箱" />
          </div>
          <div class="field">
            <label>性别</label>
            <select class="select" v-model="profileForm.sex">
              <option value="0">男</option>
              <option value="1">女</option>
              <option value="2">保密</option>
            </select>
          </div>
          <div class="field">
            <label>所属部门</label>
            <input class="input" :value="heroDept" disabled title="部门信息请联系管理员修改" />
          </div>
          <div class="field field-remark">
            <label>个人简介</label>
            <textarea class="textarea" v-model="profileForm.remark" rows="4" placeholder="请输入个人简介"></textarea>
          </div>
        </div>
        <div class="save-row">
          <button class="btn" @click="cancelEdit">取消</button>
          <button class="btn primary" @click="saveProfile"><Save :size="15"/>保存修改</button>
        </div>
      </section>

      <!-- 账号与安全 -->
      <aside>
        <section class="card security-card">
          <div class="section-title"><span>账号与安全</span><ShieldCheck :size="18" class="green-icon"/></div>
          <p>管理登录密码与账号绑定信息</p>
          <div class="security-row">
            <span><KeyRound :size="16"/>登录密码</span>
            <em>上次修改：--</em>
            <button @click="openPwdDialog">修改密码</button>
          </div>
          <div class="security-row">
            <span><Smartphone :size="16"/>绑定手机号</span>
            <em>{{ profileForm.phonenumber ? profileForm.phonenumber.slice(0,3) + '****' + profileForm.phonenumber.slice(-4) : '未绑定' }}</em>
            <button @click="active = '个人资料'">更换</button>
          </div>
          <div class="security-row">
            <span><Mail :size="16"/>绑定邮箱</span>
            <em>{{ profileForm.email || '未绑定' }}</em>
            <button @click="active = '个人资料'">更换</button>
          </div>
          <div class="security-row">
            <span><MessageCircle :size="16"/>绑定微信</span>
            <em>未绑定</em>
            <button @click="securityPlaceholder('绑定微信')">去绑定</button>
          </div>
          <div class="security-row">
            <span><ShieldCheck :size="16"/>双重验证</span>
            <em>未开启</em>
            <button @click="securityPlaceholder('双重验证')">管理</button>
          </div>
        </section>

        <!-- 登录记录（后端暂无接口，展示当前登录信息） -->
        <section class="card login-card">
          <h3>登录记录</h3>
          <div class="login-item">
            <b>当前会话 · 浏览器</b>
            <span class="pill green">当前在线</span>
            <small>IP：{{ display.loginIp || '--' }} · {{ display.loginDate || '--' }}</small>
          </div>
          <button @click="securityPlaceholder('查看全部登录记录')">查看全部登录记录</button>
        </section>
      </aside>
    </div>

    <!-- 邮箱与发信设置 -->
    <section class="card mail-card">
      <div class="section-title">
        <div><h2>邮箱与发信设置</h2><p>发送 Offer 时可选择企业邮箱或个人邮箱发信 · 个人授权码加密存储，不会明文回显</p></div>
        <Mail :size="18" class="green-icon" />
      </div>
      <div class="mail-grid">
        <div class="field">
          <label>企业邮箱（发件地址）</label>
          <input class="input" :value="mail.companyEmail || '未配置'" disabled title="企业邮箱由企业资料统一管理" />
        </div>
        <div class="field">
          <label>SMTP 服务器</label>
          <input class="input" v-model="mail.smtpHost" placeholder="如 smtp.qq.com" />
        </div>
        <div class="field">
          <label>SMTP 端口</label>
          <input class="input" v-model="mail.smtpPort" placeholder="SSL 常用 465，STARTTLS 常用 587" maxlength="5" />
        </div>
        <div class="field">
          <label>连接方式</label>
          <select class="select" v-model="mail.ssl">
            <option :value="1">SSL（推荐）</option>
            <option :value="0">STARTTLS / 非 SSL</option>
          </select>
        </div>
        <div class="field">
          <label>认证账号（发件人）</label>
          <input class="input" v-model="mail.username" placeholder="如 your_name@qq.com" />
        </div>
        <div class="field">
          <label>授权码 / 密码</label>
          <input class="input" type="password" v-model="mail.password" :placeholder="mail.configured ? '已保存 ********，留空则不修改' : '如 QQ 邮箱 16 位授权码'" />
        </div>
      </div>
      <div class="save-row">
        <button class="btn primary" :disabled="mailLoading" @click="saveMailConfig"><Save :size="15" />{{ mailLoading ? '保存中…' : '保存发信配置' }}</button>
      </div>
    </section>
    </template>

    <!-- ============ 偏好设置 Tab ============ -->
    <section v-else-if="active==='偏好设置'" class="card preference-card">
      <div class="section-title"><div><h2>工作偏好</h2><p>根据你的工作习惯个性化 TalentFlow</p></div></div>
      <div class="preference-grid">
        <div class="field"><label>面试默认时长</label>
          <select class="select" v-model="prefsForm.interviewDuration">
            <option value="30min">30 分钟</option><option value="45min">45 分钟</option><option value="60min">60 分钟</option>
          </select>
        </div>
        <div class="field"><label>日历同步偏好</label>
          <select class="select" v-model="prefsForm.calendarSync">
            <option value="both">双向同步</option><option value="import">仅导入日程</option><option value="none">不同步</option>
          </select>
        </div>
        <div class="field"><label>消息通知频率</label>
          <select class="select" v-model="prefsForm.notifyFreq">
            <option value="realtime">实时通知</option><option value="daily">每日汇总</option><option value="none">不通知</option>
          </select>
        </div>
        <div class="field"><label>语言选择</label>
          <select class="select" v-model="prefsForm.language">
            <option value="zh-CN">简体中文</option><option value="en-US">English</option>
          </select>
        </div>
        <div class="field"><label>时区设置</label>
          <select class="select" v-model="prefsForm.timezone">
            <option value="Asia/Shanghai">(UTC+08:00) 北京，上海</option>
            <option value="Asia/Tokyo">(UTC+09:00) 东京</option>
            <option value="Europe/London">(UTC+00:00) 伦敦</option>
            <option value="America/New_York">(UTC-05:00) 纽约</option>
          </select>
        </div>
      </div>
      <div class="save-row"><button class="btn primary" @click="savePreferences">保存偏好</button></div>
    </section>

    <!-- ============ 通知设置 Tab ============ -->
    <section v-else class="card notification-card">
      <div class="section-title"><div><h2>通知设置</h2><p>选择你希望收到的提醒类型</p></div></div>
      <div class="notice-list">
        <div v-for="item in notices" :key="item.title">
          <span class="notice-icon"><component :is="item.icon" :size="17"/></span>
          <div><b>{{item.title}}</b><small>{{item.desc}}</small></div>
          <SwitchToggle v-model="item.on"/>
        </div>
      </div>
      <div class="save-row"><button class="btn primary" @click="saveNotices"><BellRing :size="15"/>保存设置</button></div>
    </section>

    <!-- 修改密码弹窗 -->
    <el-dialog v-model="pwdDialogVisible" title="修改登录密码" width="420px" :close-on-click-modal="false">
      <el-form label-width="90px">
        <el-form-item label="旧密码">
          <el-input v-model="pwdForm.oldPassword" type="password" show-password placeholder="请输入旧密码" />
        </el-form-item>
        <el-form-item label="新密码">
          <el-input v-model="pwdForm.newPassword" type="password" show-password placeholder="请输入新密码" />
        </el-form-item>
        <el-form-item label="确认新密码">
          <el-input v-model="pwdForm.confirmPassword" type="password" show-password placeholder="请再次输入新密码" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="pwdDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="pwdLoading" @click="submitPwd">确定修改</el-button>
      </template>
    </el-dialog>

    <ToastMessage :message="toast"/>
  </div>
</template>

<style scoped>
.profile-hero{height:137px;padding:20px 24px;display:flex;align-items:center;gap:20px}
.avatar-wrap{position:relative}
.avatar-upload{position:absolute;right:-2px;bottom:0;width:26px;height:26px;border:2px solid white;border-radius:50%;background:#2563eb;color:white;display:grid;place-items:center;cursor:pointer}
.avatar-upload:hover{background:#1d4ed8}
.avatar-upload.loading{cursor:wait;opacity:.8}
.avatar-spinner{width:12px;height:12px;border:2px solid rgba(255,255,255,.4);border-top-color:#fff;border-radius:50%;animation:avatar-spin .7s linear infinite}
@keyframes avatar-spin{to{transform:rotate(360deg)}}
.profile-hero h1{display:flex;align-items:center;gap:9px;font-size:21px}
.profile-hero p{font-size:12px;color:#64748b;margin-top:7px}
.profile-hero small{display:block;color:#94a2b5;font-size:10px;margin-top:8px}
.profile-hero>.btn{margin-left:auto}
.tabs{height:57px;margin:15px 0;padding:9px 16px;display:flex;gap:4px}
.tabs button{height:39px;padding:0 30px;border:0;border-radius:9px;background:#f1f4f8;color:#566882}
.tabs button.active{background:#2563eb;color:white}
.profile-grid{display:grid;grid-template-columns:minmax(610px,1.45fr) minmax(380px,.95fr);gap:15px}
.form-card{padding:23px}
.section-title h2{font-size:18px}
.section-title p{font-size:10px;color:#96a4b7;margin-top:5px;font-weight:400}
.form-fields{margin-top:18px;display:grid;grid-template-columns:1fr 1fr;gap:16px}
.field{display:flex;flex-direction:column;gap:6px}
.field label{font-size:12px;color:#566882;font-weight:500}
.field .input,.field .select{height:38px;border:1px solid #e2e8f0;border-radius:8px;padding:0 12px;font-size:13px;background:#fff}
.field .input:focus,.field .select:focus{outline:none;border-color:#2563eb;box-shadow:0 0 0 3px rgba(37,99,235,.12)}
.field .input:disabled{background:#f8fafc;color:#94a3b8;cursor:not-allowed}
.field .textarea{border:1px solid #e2e8f0;border-radius:8px;padding:10px 12px;font-size:13px;resize:vertical;min-height:90px}
.field .textarea:focus{outline:none;border-color:#2563eb;box-shadow:0 0 0 3px rgba(37,99,235,.12)}
.field-remark{grid-column:1/-1}
.save-row{display:flex;gap:10px;justify-content:flex-end;margin-top:16px}
.security-card{padding:22px}
.green-icon{color:#10b981}
.security-card>p{font-size:10px;color:#96a4b7;margin:5px 0 12px}
.security-row{height:47px;border-bottom:1px solid #edf1f6;display:flex;align-items:center;gap:8px}
.security-row span{display:flex;gap:7px;align-items:center;font-size:11px}
.security-row svg{color:#75869f}
.security-row em{margin-left:auto;color:#91a0b4;font-size:9px;font-style:normal}
.security-row button{border:0;background:transparent;color:#2563eb;font-size:10px}
.login-card{margin-top:15px;padding:20px}
.login-card h3{font-size:14px}
.login-item{margin-top:14px;position:relative;padding:10px;background:#f8fafc;border-radius:8px}
.login-item b,.login-item small{display:block}
.login-item b{font-size:11px}
.login-item small{font-size:9px;color:#95a3b6;margin-top:4px}
.login-item .pill{position:absolute;right:0;top:0}
.login-card>button{float:right;border:0;background:none;color:#2563eb;font-size:9px;margin-top:12px}
.preference-card,.notification-card{padding:25px;min-height:480px}
.mail-card{margin-top:15px;padding:23px}
.mail-card .section-title{display:flex;align-items:flex-start;justify-content:space-between}
.mail-grid{margin-top:18px;display:grid;grid-template-columns:1fr 1fr 1fr;gap:16px}
.preference-grid{margin-top:24px;display:grid;grid-template-columns:1fr 1fr;gap:20px}
.preference-grid .field:last-child{grid-column:1/-1}
.preference-grid .select{height:40px;border:1px solid #e2e8f0;border-radius:8px;padding:0 12px;font-size:13px;background:#fff}
.notice-list{margin-top:20px}
.notice-list>div{height:70px;display:flex;align-items:center;gap:12px;border-bottom:1px solid #e8edf4}
.notice-icon{width:38px;height:38px;border-radius:10px;background:#edf4ff;color:#2563eb;display:grid;place-items:center}
.notice-list>div>div{flex:1}
.notice-list b,.notice-list small{display:block}
.notice-list b{font-size:12px}
.notice-list small{font-size:9px;color:#91a0b5;margin-top:4px}
</style>
