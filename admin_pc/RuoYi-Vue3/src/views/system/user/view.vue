<template>
  <el-drawer
    title="用户信息详情"
    v-model="visible"
    direction="rtl"
    size="68%"
    append-to-body
    :before-close="handleClose"
    class="detail-drawer"
  >
    <div v-loading="loading" class="drawer-content">
      <!-- 基本信息 -->
      <h4 class="section-header">基本信息</h4>
      <el-row :gutter="20" class="mb8">
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">用户名称：</label>
            <span class="info-value plaintext">{{ info.nickName }}</span>
          </div>
        </el-col>
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">归属部门：</label>
            <span class="info-value plaintext">{{ info.dept && info.dept.deptName }}</span>
          </div>
        </el-col>
      </el-row>
      <el-row :gutter="20" class="mb8">
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">手机号码：</label>
            <span class="info-value plaintext">{{ info.phonenumber }}</span>
          </div>
        </el-col>
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">邮箱：</label>
            <span class="info-value plaintext">{{ info.email }}</span>
          </div>
        </el-col>
      </el-row>
      <el-row :gutter="20" class="mb8">
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">登录账号：</label>
            <span class="info-value plaintext">{{ info.userName }}</span>
          </div>
        </el-col>
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">用户状态：</label>
            <span class="info-value plaintext">
              <el-tag size="small" :type="info.status === '0' ? 'success' : 'danger'">{{
                info.status === '0' ? '正常' : '停用'
              }}</el-tag>
            </span>
          </div>
        </el-col>
      </el-row>
      <el-row :gutter="20" class="mb8">
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">岗位：</label>
            <span class="info-value plaintext">{{ postNames || '无岗位' }}</span>
          </div>
        </el-col>
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">用户性别：</label>
            <span class="info-value plaintext">{{ sexLabel }}</span>
          </div>
        </el-col>
      </el-row>
      <el-row :gutter="20" class="mb8">
        <el-col :span="24">
          <div class="info-item full-width">
            <label class="info-label">角色：</label>
            <span class="info-value plaintext">{{ roleNames || '无角色' }}</span>
          </div>
        </el-col>
      </el-row>
      <!-- 其他信息 -->
      <h4 class="section-header">其他信息</h4>
      <el-row :gutter="20" class="mb8">
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">创建者：</label>
            <span class="info-value plaintext">{{ info.createBy }}</span>
          </div>
        </el-col>
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">创建时间：</label>
            <span class="info-value plaintext">{{ info.createTime }}</span>
          </div>
        </el-col>
      </el-row>
      <el-row :gutter="20" class="mb8">
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">更新者：</label>
            <span class="info-value plaintext">{{ info.updateBy }}</span>
          </div>
        </el-col>
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">更新时间：</label>
            <span class="info-value plaintext">{{ info.updateTime }}</span>
          </div>
        </el-col>
      </el-row>
      <el-row :gutter="20" class="mb8">
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">最后登录IP：</label>
            <span class="info-value plaintext">{{ info.loginIp }}</span>
          </div>
        </el-col>
        <el-col :span="12">
          <div class="info-item">
            <label class="info-label">最后登录时间：</label>
            <span class="info-value plaintext">{{ info.loginDate }}</span>
          </div>
        </el-col>
      </el-row>
      <el-row :gutter="20" class="mb8">
        <el-col :span="24">
          <div class="info-item full-width">
            <label class="info-label">备注：</label>
            <span class="info-value plaintext">{{ info.remark }}</span>
          </div>
        </el-col>
      </el-row>

      <!-- 投递记录 -->
      <template v-if="apps.length">
        <h4 class="section-header">投递记录（{{ apps.length }}）</h4>
        <el-timeline style="padding-left:8px">
          <el-timeline-item
            v-for="a in apps" :key="a.appId"
            :timestamp="`${a.created} 投递 → 当前：${a.statusText}`"
            placement="top"
            :type="a.status >= 5 ? 'success' : a.status === 7 || a.status === 10 ? 'danger' : 'primary'"
          >
            <div style="font-weight:600">{{ a.posTitle }}</div>
            <div style="color:#666;font-size:13px">
              {{ a.companyName }} · 匹配分 {{ a.score || '-' }}
              <span v-if="a.updated !== a.created"> · 最近更新 {{ a.updated }}</span>
            </div>
          </el-timeline-item>
        </el-timeline>
      </template>
    </div>
  </el-drawer>
</template>

<script setup>
import { getUser } from '@/api/system/user'
import request from '@/utils/request'

const visible = ref(false)
const loading = ref(false)
const info = reactive({})
const postOptions = ref([])
const roleOptions = ref([])
const apps = ref([])

const { sys_user_sex } = useDict('sys_user_sex')

const sexLabel = computed(() => selectDictLabel(sys_user_sex.value, info.sex) || '-')

const postNames = computed(() => {
  if (!postOptions.value.length || !info.postIds) return ''
  return (
    postOptions.value
      .filter((p) => info.postIds?.includes(p.postId))
      .map((p) => p.postName)
      .join('、') || ''
  )
})

const roleNames = computed(() => {
  if (!roleOptions.value.length || !info.roleIds) return ''
  return (
    roleOptions.value
      .filter((r) => info.roleIds?.includes(r.roleId))
      .map((r) => r.roleName)
      .join('、') || ''
  )
})

const open = async (userId) => {
  visible.value = true
  loading.value = true
  try {
    const res = await getUser(userId)
    Object.assign(info, res.data || {})
    postOptions.value = res.posts || []
    roleOptions.value = res.roles || []
    info.postIds = res.postIds || []
    info.roleIds = res.roleIds || []
    // 加载投递记录
    try {
      const r = await request({ url: `/system/user-apps/${userId}` })
      apps.value = r.data || []
    } catch { apps.value = [] }
  } catch (error) {
    console.error('获取用户信息失败:', error)
  } finally {
    loading.value = false
  }
}

function handleClose() {
  visible.value = false
}

defineExpose({
  open
})
</script>
