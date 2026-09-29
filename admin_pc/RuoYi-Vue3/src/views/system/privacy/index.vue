<template>
  <div class="app-container">
    <el-card class="box-card" shadow="hover">
      <template #header><span class="section-title">简历权限设置</span></template>
      <el-form :model="privacy" label-width="140px" style="max-width: 600px">
        <el-form-item label="简历可见范围">
          <el-radio-group v-model="privacy.resumeVisibility" @change="handleSave">
            <el-radio value="all">所有人可见</el-radio>
            <el-radio value="contacted">仅接触过我的企业</el-radio>
            <el-radio value="none">仅自己可见</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="联系方式可见性">
          <el-radio-group v-model="privacy.phoneVisible" @change="handleSave">
            <el-radio value="true">公开</el-radio>
            <el-radio value="false">隐藏</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="邮箱可见性">
          <el-radio-group v-model="privacy.emailVisible" @change="handleSave">
            <el-radio value="true">公开</el-radio>
            <el-radio value="false">隐藏</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="企业搜索权限">
          <el-radio-group v-model="privacy.searchable" @change="handleSave">
            <el-radio value="true">允许企业搜索到我的简历</el-radio>
            <el-radio value="false">禁止企业搜索</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="求职状态">
          <el-select v-model="privacy.jobSeekingStatus" style="width: 200px" @change="handleSave">
            <el-option label="积极求职" value="active" />
            <el-option label="暂时观望" value="观望" />
            <el-option label="已入职" value="employed" />
          </el-select>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card class="box-card" shadow="hover" style="margin-top: 20px">
      <template #header><span class="section-title">数据管理</span></template>
      <el-row :gutter="20">
        <el-col :span="8">
          <el-statistic title="简历总数" :value="dataStats.resumeCount" />
        </el-col>
        <el-col :span="8">
          <el-statistic title="投递记录" :value="dataStats.applyCount" />
        </el-col>
        <el-col :span="8">
          <el-statistic title="面试场次" :value="dataStats.interviewCount" />
        </el-col>
      </el-row>
      <el-divider />
      <el-button type="primary" plain icon="Download" @click="handleExportData" v-hasPermi="['system:data:export']"
        >导出个人数据</el-button
      >
      <el-button type="danger" plain icon="Delete" @click="handleDeleteData" v-hasPermi="['system:data:delete']"
        >删除个人数据</el-button
      >
    </el-card>
  </div>
</template>

<script setup name="SystemPrivacy">
import { listPrivacy, updatePrivacy, exportData, deleteExportData } from '@/api/system/service'

const { proxy } = getCurrentInstance()

const privacy = ref({
  resumeVisibility: 'all',
  phoneVisible: 'true',
  emailVisible: 'false',
  searchable: 'true',
  jobSeekingStatus: 'active'
})
const dataStats = ref({ resumeCount: 0, applyCount: 0, interviewCount: 0 })

function handleSave() {
  updatePrivacy(privacy.value)
    .then(() => proxy.$modal.msgSuccess('保存成功'))
    .catch((err) => {
      console.error('保存隐私设置失败', err)
    })
}

function handleExportData() {
  proxy.$modal
    .confirm('确认导出个人数据吗？处理完成后将提醒您下载。')
    .then(() => {
      return exportData(1)
    })
    .then(() => {
      proxy.$modal.msgSuccess('数据导出中，请稍候')
    })
    .catch(() => {})
}

function handleDeleteData() {
  proxy.$modal
    .confirm('确认删除所有个人数据？此操作不可恢复！')
    .then(() => {
      return deleteExportData(1)
    })
    .then(() => {
      proxy.$modal.msgSuccess('数据已删除')
    })
    .catch(() => {})
}

listPrivacy()
  .then((res) => {
    privacy.value = res.data || privacy.value
  })
  .catch((err) => {
    console.error('加载隐私设置失败', err)
  })
</script>
