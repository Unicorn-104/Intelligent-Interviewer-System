<template>
  <div class="app-container">
    <el-card class="box-card" shadow="hover">
      <template #header><span class="section-title">界面设置</span></template>
      <el-form :model="theme" label-width="140px" style="max-width: 600px">
        <el-form-item label="主题模式">
          <el-radio-group v-model="theme.mode" @change="handleSave">
            <el-radio value="light">浅色模式</el-radio>
            <el-radio value="dark">深色模式</el-radio>
            <el-radio value="auto">跟随系统</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="主色调">
          <el-color-picker v-model="theme.primaryColor" @change="handleSave" />
          <el-input v-model="theme.primaryColor" style="width: 120px; margin-left: 10px" disabled />
        </el-form-item>
        <el-form-item label="语言">
          <el-select v-model="theme.language" style="width: 200px" @change="handleSave">
            <el-option label="简体中文" value="zh-CN" />
            <el-option label="English" value="en-US" />
            <el-option label="日本語" value="ja-JP" />
          </el-select>
        </el-form-item>
        <el-form-item label="表格行高">
          <el-select v-model="theme.tableRowHeight" style="width: 200px" @change="handleSave">
            <el-option label="默认(40px)" value="normal" />
            <el-option label="紧凑(32px)" value="compact" />
            <el-option label="宽松(48px)" value="comfortable" />
          </el-select>
        </el-form-item>
        <el-form-item label="侧边栏宽度">
          <el-slider v-model="theme.sidebarWidth" :min="200" :max="400" :step="10" show-input @change="handleSave" />
        </el-form-item>
      </el-form>
    </el-card>

    <el-card class="box-card" shadow="hover" style="margin-top: 20px">
      <template #header><span class="section-title">系统维护</span></template>
      <el-row :gutter="20">
        <el-col :span="8">
          <el-button
            type="primary"
            plain
            icon="Refresh"
            @click="handleClearCache"
            v-hasPermi="['system:maintenance:cache']"
            >清除缓存</el-button
          >
        </el-col>
        <el-col :span="8">
          <el-button
            type="warning"
            plain
            icon="Document"
            @click="handleReportError"
            v-hasPermi="['system:maintenance:report']"
            >上报异常日志</el-button
          >
        </el-col>
        <el-col :span="8">
          <el-button type="info" plain icon="InfoFilled">当前版本: v{{ systemInfo.version }}</el-button>
        </el-col>
      </el-row>
      <el-divider />
      <el-descriptions :column="2" border>
        <el-descriptions-item label="系统名称">{{ systemInfo.systemName }}</el-descriptions-item>
        <el-descriptions-item label="版本">{{ systemInfo.version }}</el-descriptions-item>
        <el-descriptions-item label="运行时间">{{ systemInfo.runTime }}</el-descriptions-item>
        <el-descriptions-item label="Java版本">{{ systemInfo.javaVersion }}</el-descriptions-item>
        <el-descriptions-item label="操作系统">{{ systemInfo.os }}</el-descriptions-item>
        <el-descriptions-item label="服务器IP">{{ systemInfo.serverIp }}</el-descriptions-item>
      </el-descriptions>
    </el-card>
  </div>
</template>

<script setup name="SystemTheme">
import { getThemeConfig, updateThemeConfig, getMaintenanceInfo, clearCache, reportError } from '@/api/system/service'

const { proxy } = getCurrentInstance()

const theme = ref({
  mode: 'light',
  primaryColor: '#136BFD',
  language: 'zh-CN',
  tableRowHeight: 'normal',
  sidebarWidth: 220
})
const systemInfo = ref({})

function handleSave() {
  updateThemeConfig(theme.value)
    .then(() => proxy.$modal.msgSuccess('保存成功'))
    .catch((err) => {
      console.error('保存主题设置失败', err)
    })
}

function handleClearCache() {
  proxy.$modal
    .confirm('确认清除系统缓存？')
    .then(() => {
      return clearCache()
    })
    .then(() => {
      proxy.$modal.msgSuccess('缓存已清除')
    })
    .catch(() => {})
}

function handleReportError() {
  proxy.$modal
    .prompt('请输入异常描述（可选）', '', {
      confirmButtonText: '上报',
      cancelButtonText: '取消',
      inputPlaceholder: '请描述遇到的异常问题...'
    })
    .then(({ value }) => {
      return reportError({ error: value || '手动上报', time: new Date().toISOString() })
    })
    .then(() => {
      proxy.$modal.msgSuccess('日志已上报')
    })
    .catch(() => {})
}

getThemeConfig()
  .then((res) => {
    theme.value = res.data || theme.value
  })
  .catch((err) => {
    console.error('加载主题设置失败', err)
  })
getMaintenanceInfo()
  .then((res) => {
    systemInfo.value = res.data || systemInfo.value
  })
  .catch((err) => {
    console.error('获取系统信息失败', err)
  })
</script>
