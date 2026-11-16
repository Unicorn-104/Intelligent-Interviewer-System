<template>
  <div class="app-container">
    <el-card shadow="never" class="mb16">
      <div class="page-header">
        <div>
          <h2 style="margin:0">功能开关管理</h2>
          <p style="margin:4px 0 0;color:#909399;font-size:13px">控制求职者端、企业端、企业PC端各功能模块的启用与禁用，保存后各端下次启动生效</p>
        </div>
        <div>
          <el-button @click="setAll(true)">全部开启</el-button>
          <el-button @click="setAll(false)">全部关闭</el-button>
          <el-button @click="loadData" :loading="loading">刷新</el-button>
          <el-button type="primary" @click="save" :loading="saving">保存全部</el-button>
        </div>
      </div>
    </el-card>

    <!-- 求职者端 -->
    <el-card shadow="never" class="mb16">
      <template #header>
        <div class="section-header">
          <el-icon :size="18" color="#4f6ef7"><Iphone /></el-icon>
          <span style="font-weight:600;margin-left:6px">求职者端 (App)</span>
          <el-tag size="small" type="info" style="margin-left:8px">{{ countOn('capp') }}/{{ groups.capp.length }} 已启用</el-tag>
        </div>
      </template>
      <div class="feature-grid">
        <div v-for="item in groups.capp" :key="item.key" class="feature-card" :class="{ off: !item.enabled }">
          <div class="feature-icon" :style="{ background: item.color }">
            <el-icon :size="20" color="#fff"><component :is="item.icon" /></el-icon>
          </div>
          <div class="feature-info">
            <div class="feature-name">{{ item.name }}</div>
            <div class="feature-desc">{{ item.desc }}</div>
          </div>
          <div class="feature-actions">
            <el-button size="small" text @click="openEnterpriseDialog(item)">企业配置</el-button>
            <el-switch v-model="item.enabled" />
          </div>
        </div>
      </div>
    </el-card>

    <!-- 求职者PC端 -->
    <el-card shadow="never" class="mb16">
      <template #header>
        <div class="section-header">
          <el-icon :size="18" color="#6366f1"><Monitor /></el-icon>
          <span style="font-weight:600;margin-left:6px">求职者端 (Web)</span>
          <el-tag size="small" type="info" style="margin-left:8px">{{ countOn('uap') }}/{{ groups.uap.length }} 已启用</el-tag>
        </div>
      </template>
      <div class="feature-grid">
        <div v-for="item in groups.uap" :key="item.key" class="feature-card" :class="{ off: !item.enabled }">
          <div class="feature-icon" :style="{ background: item.color }">
            <el-icon :size="20" color="#fff"><component :is="item.icon" /></el-icon>
          </div>
          <div class="feature-info">
            <div class="feature-name">{{ item.name }}</div>
            <div class="feature-desc">{{ item.desc }}</div>
          </div>
          <div class="feature-actions">
            <el-button size="small" text @click="openEnterpriseDialog(item)">企业配置</el-button>
            <el-switch v-model="item.enabled" />
          </div>
        </div>
      </div>
    </el-card>

    <!-- 企业端App -->
    <el-card shadow="never" class="mb16">
      <template #header>
        <div class="section-header">
          <el-icon :size="18" color="#22c55e"><OfficeBuilding /></el-icon>
          <span style="font-weight:600;margin-left:6px">企业端 (App)</span>
          <el-tag size="small" type="info" style="margin-left:8px">{{ countOn('eapp') }}/{{ groups.eapp.length }} 已启用</el-tag>
        </div>
      </template>
      <div class="feature-grid">
        <div v-for="item in groups.eapp" :key="item.key" class="feature-card" :class="{ off: !item.enabled }">
          <div class="feature-icon" :style="{ background: item.color }">
            <el-icon :size="20" color="#fff"><component :is="item.icon" /></el-icon>
          </div>
          <div class="feature-info">
            <div class="feature-name">{{ item.name }}</div>
            <div class="feature-desc">{{ item.desc }}</div>
          </div>
          <div class="feature-actions">
            <el-button size="small" text @click="openEnterpriseDialog(item)">企业配置</el-button>
            <el-switch v-model="item.enabled" />
          </div>
        </div>
      </div>
    </el-card>

    <!-- 企业PC端 -->
    <el-card shadow="never">
      <template #header>
        <div class="section-header">
          <el-icon :size="18" color="#f59e0b"><Monitor /></el-icon>
          <span style="font-weight:600;margin-left:6px">企业端 (Web后台)</span>
          <el-tag size="small" type="info" style="margin-left:8px">{{ countOn('epc') }}/{{ groups.epc.length }} 已启用</el-tag>
        </div>
      </template>
      <div class="feature-grid">
        <div v-for="item in groups.epc" :key="item.key" class="feature-card" :class="{ off: !item.enabled }">
          <div class="feature-icon" :style="{ background: item.color }">
            <el-icon :size="20" color="#fff"><component :is="item.icon" /></el-icon>
          </div>
          <div class="feature-info">
            <div class="feature-name">{{ item.name }}</div>
            <div class="feature-desc">{{ item.desc }}</div>
          </div>
          <div class="feature-actions">
            <el-button size="small" text @click="openEnterpriseDialog(item)">企业配置</el-button>
            <el-switch v-model="item.enabled" />
          </div>
        </div>
      </div>
    </el-card>

    <!-- 企业级配置弹窗 -->
    <el-dialog v-model="enterpriseDialog.visible" :title="`企业级配置 - ${enterpriseDialog.featureName}`" width="600px">
      <el-alert title="企业级配置会覆盖全局默认设置" type="info" :closable="false" style="margin-bottom:16px" />
      <el-input v-model="enterpriseDialog.search" placeholder="搜索企业名称..." clearable style="margin-bottom:12px" />
      <el-table :data="filteredEnterprises" size="small" max-height="400">
        <el-table-column prop="name" label="企业名称" />
        <el-table-column prop="contact" label="联系人" width="100" />
        <el-table-column label="覆盖全局" width="90" align="center">
          <template #default="scope">
            <el-switch v-model="scope.row.override" />
          </template>
        </el-table-column>
        <el-table-column label="覆盖值" width="90" align="center">
          <template #default="scope">
            <el-switch v-if="scope.row.override" v-model="scope.row.enabled"
              active-text="开" inactive-text="关" />
            <span v-else style="color:#999">跟随全局</span>
          </template>
        </el-table-column>
      </el-table>
      <template #footer>
        <el-button @click="enterpriseDialog.visible = false">取消</el-button>
        <el-button type="primary" @click="saveEnterpriseConfig">保存企业配置</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="FeatureManage">
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import request from '@/utils/request'
import {
  Iphone, OfficeBuilding, Monitor,
  MagicStick, ChatDotRound, Document,
  Bell, Service, School,
  Tools, Star, Calendar, Tickets, VideoCamera
} from '@element-plus/icons-vue'

const loading = ref(false)
const saving = ref(false)

const groups = reactive({
  capp: [],
  uap: [],
  eapp: [],
  epc: []
})

function iconColor(color) {
  return `linear-gradient(135deg,${color},${color}dd)`
}

async function loadData() {
  loading.value = true
  try {
    const res = await request({ url: '/system/feature/list', method: 'get' })
    groups.capp = res.data.filter(x => x.group === '求职者端App').map(x => ({ ...x, color: iconColor(x.color) }))
    groups.uap = res.data.filter(x => x.group === '求职者PC端').map(x => ({ ...x, color: iconColor(x.color) }))
    groups.eapp = res.data.filter(x => x.group === '企业端App').map(x => ({ ...x, color: iconColor(x.color) }))
    groups.epc = res.data.filter(x => x.group === '企业端Web').map(x => ({ ...x, color: iconColor(x.color) }))
  } catch (e) {
    ElMessage.error('加载失败')
  } finally {
    loading.value = false
  }
}

async function save() {
  saving.value = true
  try {
    const all = [...groups.capp, ...groups.uap, ...groups.eapp, ...groups.epc]
    const data = {}
    all.forEach(x => { data[x.key] = x.enabled })
    await request({ url: '/system/feature/save', method: 'post', data })
    ElMessage.success('保存成功')
  } catch (e) {
    ElMessage.error('保存失败')
  } finally {
    saving.value = false
  }
}

function countOn(group) {
  return groups[group].filter(x => x.enabled).length
}

function setAll(val) {
  groups.capp.forEach(x => x.enabled = val)
  groups.uap.forEach(x => x.enabled = val)
  groups.eapp.forEach(x => x.enabled = val)
  groups.epc.forEach(x => x.enabled = val)
}

// 企业级配置弹窗
const enterpriseDialog = reactive({
  visible: false,
  featureKey: '',
  featureName: '',
  search: '',
  enterprises: []
})

async function openEnterpriseDialog(item) {
  enterpriseDialog.featureKey = item.key
  enterpriseDialog.featureName = item.name
  enterpriseDialog.visible = true
  enterpriseDialog.search = ''
  enterpriseDialog.enterprises = []
  try {
    const res = await request({ url: '/system/feature/overrides/' + item.key, method: 'get' })
    enterpriseDialog.enterprises = res.data.enterprises || []
  } catch (e) {
    enterpriseDialog.enterprises = []
  }
}

const filteredEnterprises = computed(() => {
  if (!enterpriseDialog.search) return enterpriseDialog.enterprises
  return enterpriseDialog.enterprises.filter(x => x.name && x.name.includes(enterpriseDialog.search))
})

async function saveEnterpriseConfig() {
  try {
    await request({
      url: '/system/feature/overrides/save',
      method: 'post',
      data: {
        featureKey: enterpriseDialog.featureKey,
        overrides: enterpriseDialog.enterprises
      }
    })
    ElMessage.success('企业配置已保存')
    enterpriseDialog.visible = false
  } catch (e) {
    ElMessage.error('保存失败')
  }
}

onMounted(() => { loadData() })
</script>

<style scoped>
.mb16 { margin-bottom: 16px; }
.page-header { display: flex; justify-content: space-between; align-items: center; }
.section-header { display: flex; align-items: center; }
.feature-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 12px; }
.feature-card {
  display: flex; align-items: center; gap: 12px;
  padding: 14px; border: 1px solid #eef0f5; border-radius: 10px;
  transition: all 0.2s; background: #fff;
}
.feature-card:hover { border-color: #4f6ef7; box-shadow: 0 2px 8px rgba(79,110,247,0.1); }
.feature-card.off { opacity: 0.55; background: #fafafa; }
.feature-icon {
  width: 40px; height: 40px; border-radius: 10px;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.feature-info { flex: 1; min-width: 0; }
.feature-name { font-size: 14px; font-weight: 600; color: #1f2329; }
.feature-desc { font-size: 12px; color: #909399; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.feature-actions { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
</style>
