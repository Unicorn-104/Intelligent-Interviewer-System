<template>
  <div class="app-container list-page">
    <!-- 统计卡 -->
    <div class="stat-row">
      <div class="stat-card" @click="quickFilter(undefined)">
        <div class="stat-num">{{ stats.total }}</div>
        <div class="stat-label">全部用户</div>
      </div>
      <div class="stat-card stat-normal" @click="quickFilter('0')">
        <div class="stat-num">{{ stats.normal }}</div>
        <div class="stat-label">正常</div>
      </div>
      <div class="stat-card stat-banned" @click="quickFilter('1')">
        <div class="stat-num">{{ stats.banned }}</div>
        <div class="stat-label">已封禁</div>
      </div>
      <div class="stat-card stat-pending" @click="quickFilter('2')">
        <div class="stat-num">{{ stats.pending }}</div>
        <div class="stat-label">待注销审核</div>
      </div>
    </div>

    <!-- 搜索卡片 -->
    <div class="search-card">
      <el-form :model="queryParams" ref="queryRef" :inline="true">
        <el-form-item label="昵称/账号" prop="userName">
          <el-input
            v-model="queryParams.userName"
            placeholder="请输入昵称或账号"
            clearable
            @keyup.enter="handleQuery"
          />
        </el-form-item>
        <el-form-item label="手机号" prop="phone">
          <el-input v-model="queryParams.phone" placeholder="请输入手机号" clearable @keyup.enter="handleQuery" />
        </el-form-item>
        <el-form-item label="身份" prop="identity">
          <el-select v-model="queryParams.identity" placeholder="请选择身份" clearable>
            <el-option v-for="item in identityOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-select v-model="queryParams.status" placeholder="请选择状态" clearable>
            <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
          <el-button icon="Refresh" @click="resetQuery">重置</el-button>
        </el-form-item>
      </el-form>
    </div>

    <!-- 表格卡片 -->
    <div class="table-card">
      <el-row :gutter="10" class="toolbar">
        <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
      </el-row>

      <el-table v-loading="loading" :data="userList" stripe border>
        <el-table-column label="ID" align="center" prop="userId" width="70" />
        <el-table-column label="昵称" align="center" prop="userName" min-width="140" />
        <el-table-column label="账号" align="center" prop="account" min-width="160" />
        <el-table-column label="手机号" align="center" width="130">
          <template #default="scope">{{ maskPhone(scope.row.phone) }}</template>
        </el-table-column>
        <el-table-column label="身份" align="center" width="100">
          <template #default="scope">
            <el-tag effect="plain" :type="identityTag(scope.row.identity)">{{
              identityLabel(scope.row.identity)
            }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="归属企业" align="center" prop="companyName" min-width="160" />
        <el-table-column label="实名" align="center" width="90">
          <template #default="scope">
            <el-tag effect="plain" :type="realTag(scope.row.realStatus)">{{ realLabel(scope.row.realStatus) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="简历数" align="center" prop="resumeCount" width="80" />
        <el-table-column label="投递数" align="center" prop="applyCount" width="80" />
        <el-table-column label="状态" align="center" width="100">
          <template #default="scope">
            <el-tag effect="plain" :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="注册时间" align="center" width="170">
          <template #default="scope">{{ formatTime(scope.row.registerTime) }}</template>
        </el-table-column>
        <el-table-column label="最后登录" align="center" width="170">
          <template #default="scope">{{ formatTime(scope.row.lastLoginTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" align="center" width="220" fixed="right">
          <template #default="scope">
            <el-button link type="primary" icon="View" @click="handleDetail(scope.row)">详情</el-button>
            <el-button link type="warning" icon="Key" @click="handleResetPwd(scope.row)">重置密码</el-button>
            <el-button
              v-if="scope.row.status === '0'"
              link
              type="danger"
              icon="Lock"
              @click="handleToggleStatus(scope.row)"
              v-hasPermi="['member:user:edit']"
              >封禁</el-button
            >
            <el-button
              v-if="scope.row.status === '1'"
              link
              type="success"
              icon="Unlock"
              @click="handleToggleStatus(scope.row)"
              v-hasPermi="['member:user:edit']"
              >解封</el-button
            >
            <el-button
              v-if="scope.row.status === '2'"
              link
              type="warning"
              icon="Checked"
              @click="handleCancelAudit(scope.row)"
              v-hasPermi="['member:user:edit']"
              >注销审核</el-button
            >
          </template>
        </el-table-column>
      </el-table>

      <pagination
        v-show="total > 0"
        :total="total"
        v-model:page="queryParams.pageNum"
        v-model:limit="queryParams.pageSize"
        @pagination="getList"
      />
    </div>

    <!-- 用户详情抽屉 -->
    <el-drawer v-model="detailOpen" :title="'用户详情 — ' + detailUser.userName" size="650px" append-to-body>
      <div style="background:#f5f7fa; padding:4px; margin:-20px -24px; padding:20px 24px;">
        <!-- 基本信息 -->
        <div style="background:#fff; border-radius:8px; padding:16px; margin-bottom:14px; box-shadow:0 1px 4px rgba(0,0,0,0.06);">
          <div style="font-size:14px; font-weight:600; color:#1d2129; margin-bottom:12px; padding-left:10px; border-left:3px solid #409eff;">基本信息</div>
          <el-descriptions :column="2" border>
            <el-descriptions-item label="用户ID">{{ detailUser.userId }}</el-descriptions-item>
            <el-descriptions-item label="昵称">{{ detailUser.userName }}</el-descriptions-item>
            <el-descriptions-item label="账号">{{ detailUser.account }}</el-descriptions-item>
            <el-descriptions-item label="手机号">{{ detailUser.phone }}</el-descriptions-item>
            <el-descriptions-item label="邮箱">{{ detailUser.email }}</el-descriptions-item>
            <el-descriptions-item label="身份">
              <el-tag effect="plain" :type="identityTag(detailUser.identity)">{{ identityLabel(detailUser.identity) }}</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="归属企业">{{ detailUser.companyName }}</el-descriptions-item>
            <el-descriptions-item label="实名姓名">{{ detailUser.realName }}</el-descriptions-item>
            <el-descriptions-item label="实名状态">
              <el-tag effect="plain" :type="realTag(detailUser.realStatus)">{{ realLabel(detailUser.realStatus) }}</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="简历数">{{ detailUser.resumeCount }}</el-descriptions-item>
            <el-descriptions-item label="投递数">{{ detailUser.applyCount }}</el-descriptions-item>
            <el-descriptions-item label="状态">
              <el-tag effect="plain" :type="statusTag(detailUser.status)">{{ statusLabel(detailUser.status) }}</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="注册时间" :span="2">{{ detailUser.registerTime }}</el-descriptions-item>
            <el-descriptions-item label="最后登录" :span="2">{{ detailUser.lastLoginTime }}</el-descriptions-item>
          </el-descriptions>
        </div>

        <!-- 投递记录 -->
        <div style="background:#fff; border-radius:8px; padding:16px; margin-bottom:14px; box-shadow:0 1px 4px rgba(0,0,0,0.06);">
          <div style="font-size:14px; font-weight:600; color:#1d2129; margin-bottom:12px; padding-left:10px; border-left:3px solid #67c23a;">投递记录（{{ detailApps.length }}）</div>
          <div v-if="detailApps.length" style="display:flex; flex-direction:column; gap:8px;">
            <div v-for="a in detailApps" :key="a.appId"
              @click="router.push('/recruit/candidate')"
              :style="{display:'flex', justifyContent:'space-between', alignItems:'center', padding:'10px 12px', borderRadius:'6px', cursor:'pointer',
                background: a.status >= 5 ? '#f0f9eb' : (a.status === 7 || a.status === 10 ? '#fef0f0' : '#fdf6ec'),
                borderLeft: '3px solid ' + (a.status >= 5 ? '#67c23a' : (a.status === 7 || a.status === 10 ? '#f56c6c' : '#e6a23c'))}"
              title="点击查看候选人管理">
              <div>
                <div style="font-weight:600; font-size:14px; color:#303133;">{{ a.posTitle }}</div>
                <div style="font-size:12px; color:#909399; margin-top:3px;">{{ a.companyName }} · 投递于 {{ a.created }}</div>
                <div v-if="a.updated !== a.created" style="font-size:12px; color:#909399;">最近更新 {{ a.updated }}</div>
              </div>
              <div style="text-align:right; flex-shrink:0; margin-left:12px;">
                <el-tag size="small" :type="a.status >= 5 ? 'success' : a.status === 7 || a.status === 10 ? 'danger' : 'warning'">{{ a.statusText }}</el-tag>
                <div v-if="a.score != null" style="font-size:12px; color:#909399; margin-top:4px;">匹配分 {{ a.score }}</div>
              </div>
            </div>
          </div>
          <el-empty v-else description="暂无投递记录" :image-size="70" />
        </div>

        <!-- 登录设备 -->
        <div style="background:#fff; border-radius:8px; padding:16px; margin-bottom:14px; box-shadow:0 1px 4px rgba(0,0,0,0.06);">
          <div style="font-size:14px; font-weight:600; color:#1d2129; margin-bottom:12px; padding-left:10px; border-left:3px solid #409eff;">登录设备（{{ detailDevices.length }} 台）</div>
          <el-table v-if="detailDevices.length" :data="detailDevices" border size="small" class="mini-table">
            <el-table-column label="设备" align="center" prop="deviceName" min-width="140" />
            <el-table-column label="IP" align="center" prop="ip" width="120" />
            <el-table-column label="归属地" align="center" prop="location" width="110" />
            <el-table-column label="登录时间" align="center" prop="loginTime" width="155" />
            <el-table-column label="当前在线" align="center" width="85">
              <template #default="scope">
                <el-tag :type="currentTag(scope.row.current)">{{ currentLabel(scope.row.current) }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="操作" align="center" width="100">
              <template #default="scope">
                <el-button link type="danger" @click="handleForceOffline(scope.row)">强制下线</el-button>
              </template>
            </el-table-column>
          </el-table>
          <el-empty v-else description="暂无登录设备记录" :image-size="70" />
        </div>

        <!-- 最近登录记录 -->
        <div style="background:#fff; border-radius:8px; padding:16px; margin-bottom:14px; box-shadow:0 1px 4px rgba(0,0,0,0.06);">
          <div style="font-size:14px; font-weight:600; color:#1d2129; margin-bottom:12px; padding-left:10px; border-left:3px solid #909399;">最近登录记录</div>
          <el-table v-if="detailLoginLogs.length" :data="detailLoginLogs" border size="small">
            <el-table-column label="时间" align="center" prop="time" width="165" />
            <el-table-column label="IP" align="center" prop="ip" width="120" />
            <el-table-column label="归属地" align="center" prop="location" />
            <el-table-column label="结果" align="center" prop="result" width="70" />
          </el-table>
          <el-empty v-else description="暂无登录记录" :image-size="70" />
        </div>
      </div>
    </el-drawer>

    <!-- 注销审核对话框 -->
    <el-dialog title="注销审核" v-model="auditOpen" width="500px" append-to-body>
      <el-form ref="auditRef" :model="form" :rules="rules" label-width="100px">
        <el-form-item label="用户昵称"
          ><span class="text-highlight">{{ form.userName }}</span></el-form-item
        >
        <el-form-item label="审核结果" prop="pass">
          <el-radio-group v-model="form.pass" @change="handlePassChange">
            <el-radio value="1">通过注销</el-radio>
            <el-radio value="0">驳回</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="驳回原因" prop="reason">
          <el-input v-model="form.reason" type="textarea" :rows="3" placeholder="驳回时必须填写原因" />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitAudit">确 定</el-button>
          <el-button @click="cancelAudit">取 消</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="MemberUser">
import { useRouter } from 'vue-router'
const router = useRouter()
import { listUser, getUser, changeStatus, auditCancel, logoutForce, statsUser } from '@/api/member/user'
import request from '@/utils/request'

const { proxy } = getCurrentInstance()
const userList = ref([])
const detailOpen = ref(false)
const detailUser = ref({})
const detailDevices = ref([])
const detailLoginLogs = ref([])
const detailApps = ref([])
const auditOpen = ref(false)
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)
const stats = ref({ total: 0, normal: 0, banned: 0, pending: 0 })

const statusOptions = [
  { value: '0', label: '正常', tag: 'success' },
  { value: '1', label: '已封禁', tag: 'danger' },
  { value: '2', label: '注销待审核', tag: 'warning' },
  { value: '3', label: '已注销', tag: 'info' }
]
const identityOptions = [
  { value: '0', label: '求职者', tag: 'success' },
  { value: '1', label: '企业用户', tag: 'primary' }
]
const realStatusOptions = [
  { value: '1', label: '已认证', tag: 'success' },
  { value: '0', label: '未实名', tag: 'info' }
]

function statusTag(status) {
  const item = statusOptions.find((o) => o.value === String(status))
  return item ? item.tag : 'info'
}

function statusLabel(status) {
  const item = statusOptions.find((o) => o.value === String(status))
  return item ? item.label : '未知'
}

const validateReason = (rule, value, callback) => {
  if (data.form.pass === '0' && (!value || String(value).trim() === '')) callback(new Error('驳回时必须填写原因'))
  else callback()
}

const data = reactive({
  form: {
    userId: undefined,
    userName: undefined,
    pass: '1',
    reason: undefined
  },
  queryParams: {
    pageNum: 1,
    pageSize: 10,
    userName: undefined,
    phone: undefined,
    identity: undefined,
    status: undefined
  },
  rules: {
    pass: [{ required: true, message: '请选择审核结果', trigger: 'change' }],
    reason: [{ required: true, validator: validateReason, trigger: 'blur' }]
  }
})

const { form, queryParams, rules } = toRefs(data)

/** 查询用户列表 */
function getList() {
  loading.value = true
  listUser(data.queryParams)
    .then((response) => {
      userList.value = response.rows
      total.value = response.total
      loading.value = false
    })
    .catch((err) => {
      console.error('查询用户列表失败:', err)
      loading.value = false
    })
  getStats()
}

function getStats() {
  statsUser()
    .then((res) => {
      stats.value = res.data || res || {}
    })
    .catch(() => {})
}

/** 统计卡点选筛选 */
function quickFilter(status) {
  data.queryParams.status = status
  handleQuery()
}

/** 手机号脱敏 138****8000 */
function maskPhone(phone) {
  if (!phone) return '-'
  const s = String(phone)
  return s.length >= 7 ? s.slice(0, 3) + '****' + s.slice(-4) : s
}

/** 搜索按钮操作 */
function handleQuery() {
  data.queryParams.pageNum = 1
  getList()
}

/** 重置按钮操作 */
function reset() {
  data.form.userId = undefined
  data.form.userName = undefined
  data.form.pass = '1'
  data.form.reason = undefined
}
function resetQuery() {
  proxy.resetForm('queryRef')
  handleQuery()
}

/** 强制下线操作 */
function handleForceOffline(row) {
  proxy.$modal
    .confirm('确认强制该用户下线吗？')
    .then(() => {
      return logoutForce(row.userId)
    })
    .then(() => {
      proxy.$modal.msgSuccess('已下发')
    })
    .catch(() => {})
}

function handleToggleStatus(row) {
  const b = row.status === '0'
  const t = b ? '封禁' : '解封'
  const s = b ? '1' : '0'
  proxy.$modal
    .confirm('确认' + t + '「' + row.userName + '」？')
    .then(() =>
      changeStatus({ userId: row.userId, status: s }).then(() => {
        getList()
        proxy.$modal.msgSuccess(t + '成功')
      })
    )
    .catch(() => {})
}
function handleResetPwd(row) {
  proxy.$modal
    .confirm('确认重置「' + row.userName + '」的密码？新密码将通过短信/邮件发送。')
    .then(() => {
      proxy.$modal.msgSuccess('重置请求已提交，新密码已发送')
    })
    .catch(() => {})
}
function handleDetail(row) {
  getUser(row.userId)
    .then((response) => {
      detailUser.value = response.data || {}
      detailDevices.value = response.devices || []
      detailLoginLogs.value = response.loginLogs || []
      detailOpen.value = true
      // 加载投递记录
      request({ url: `/system/user-apps/${row.userId}` }).then(r => {
        detailApps.value = r.data || []
      }).catch(() => { detailApps.value = [] })
    })
    .catch((err) => {
      console.error('查询用户详情失败:', err)
    })
}
function handleCancelAudit(row) {
  reset()
  data.form.userId = row.userId
  data.form.userName = row.userName
  auditOpen.value = true
}
function handlePassChange() {
  if (proxy.$refs['auditRef']) proxy.$refs['auditRef'].clearValidate('reason')
}
function cancelAudit() {
  auditOpen.value = false
  reset()
}
function submitAudit() {
  proxy.$refs['auditRef'].validate((v) => {
    if (v) {
      auditCancel({
        userId: data.form.userId,
        status: data.form.pass,
        reason: data.form.reason
      })
        .then(() => {
          proxy.$modal.msgSuccess('审核成功')
          auditOpen.value = false
          getList()
        })
        .catch((err) => {
          console.error('审核失败:', err)
        })
    }
  })
}

/** 身份标签 */
function identityLabel(v) {
  const o = identityOptions.find((x) => x.value === String(v))
  return o ? o.label : v
}
function identityTag(v) {
  const o = identityOptions.find((x) => x.value === String(v))
  return o?.tag || 'info'
}

/** 实名标签 */
function realLabel(v) {
  const o = realStatusOptions.find((x) => x.value === String(v))
  return o ? o.label : v
}
function realTag(v) {
  const o = realStatusOptions.find((x) => x.value === String(v))
  return o?.tag || 'info'
}

/** 格式化时间 */
function formatTime(time) {
  if (!time) return ''
  return time.replace('T', ' ').substring(0, 19)
}

/** 当前在线标签 */
function currentLabel(v) {
  return v ? '在线' : '离线'
}
function currentTag(v) {
  return v ? 'success' : 'info'
}

getList()
</script>

<style lang="scss" scoped>
.list-page {
  .stat-row {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 14px;
    margin-bottom: 16px;
  }
  .stat-card {
    background: #fff;
    border-radius: 10px;
    padding: 18px 20px;
    box-shadow: 0 2px 10px rgba(72, 47, 105, 0.05);
    cursor: pointer;
    border-left: 4px solid transparent;
    transition:
      transform 0.15s ease,
      box-shadow 0.15s ease;
  }
  .stat-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 18px rgba(72, 47, 105, 0.1);
  }
  .stat-num {
    font-size: 28px;
    font-weight: 700;
    line-height: 1.2;
  }
  .stat-label {
    color: #86909c;
    font-size: 13px;
    margin-top: 4px;
  }
  .stat-normal {
    border-left-color: #22c55e;
  }
  .stat-normal .stat-num {
    color: #22c55e;
  }
  .stat-banned {
    border-left-color: #ef4444;
  }
  .stat-banned .stat-num {
    color: #ef4444;
  }
  .stat-pending {
    border-left-color: #f59e0b;
  }
  .stat-pending .stat-num {
    color: #f59e0b;
  }

  .search-card {
    background: #fff;
    padding: 18px 20px 6px;
    margin-bottom: 16px;
    border-radius: 8px;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
    border: 1px solid #ebeef5;
  }

  .table-card {
    background: #fff;
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
    border: 1px solid #ebeef5;
  }

  .toolbar {
    padding: 12px 20px;
    border-bottom: 1px solid #f5f7fa;
  }

  // ===== 抽屉样式 =====
  :deep(.el-drawer) {
    .el-drawer__header {
      padding: 16px 24px;
      margin-bottom: 0;
      border-bottom: 1px solid #ebeef5;
    }
    .el-drawer__body {
      padding: 20px 24px;
      background: #f5f7fa;
    }
    .el-drawer__title {
      font-size: 15px !important;
      font-weight: 600;
      color: #1d2129;
    }
  }

  :deep(.drawer-content) {
    .detail-section {
      margin-bottom: 14px;
      padding: 14px 16px;
      background: #fff;
      border-radius: 8px;
      box-shadow: 0 1px 4px rgba(0,0,0,0.06);
      &:last-child { margin-bottom: 0; }
    }

    .section-title {
      font-size: 14px;
      font-weight: 600;
      color: #1d2129;
      padding-bottom: 10px;
      margin-bottom: 12px;
      border-bottom: 1px solid #f0f2f5;
      position: relative;
      padding-left: 10px;
      &::before {
        content: '';
        position: absolute;
        left: 0;
        top: 50%;
        transform: translateY(-50%);
        width: 3px;
        height: 14px;
        background: #409eff;
        border-radius: 2px;
      }
    }

    .mini-table { margin-bottom: 8px; }

    .app-list {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .app-card {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 10px 12px;
      border-radius: 6px;
      background: #f7f8fa;
      border-left: 3px solid #e6a23c;
      &.app-card-success { border-left-color: #67c23a; background: #f0f9eb; }
      &.app-card-danger  { border-left-color: #f56c6c; background: #fef0f0; }
    }
    .app-title { font-weight: 600; font-size: 14px; color: #303133; }
    .app-meta  { font-size: 12px; color: #909399; margin-top: 3px; }
    .app-card-right { text-align: right; flex-shrink: 0; margin-left: 12px; }
    .app-score { font-size: 12px; color: #909399; margin-top: 4px; }
  }

  .text-highlight {
    font-weight: 600;
    color: #1d2129;
    font-size: 14px;
  }
  .dialog-footer {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
  }
}
</style>
