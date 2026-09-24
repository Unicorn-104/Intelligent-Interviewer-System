<template>
  <div class="app-container">
    <el-form :model="form" label-width="140px" style="max-width: 720px">
      <el-form-item label="客服工作时间" prop="workTime">
        <el-input v-model="form.workTime" placeholder="请输入客服工作时间，如：工作日 9:00 - 18:00" />
      </el-form-item>
      <el-form-item label="客服电话" prop="phone">
        <el-input v-model="form.phone" placeholder="请输入客服电话" />
      </el-form-item>
      <el-form-item label="客服邮箱" prop="email">
        <el-input v-model="form.email" placeholder="请输入客服邮箱" />
      </el-form-item>
      <el-form-item label="人工响应超时(秒)" prop="responseTimeout">
        <el-input-number v-model="form.responseTimeout" :min="10" :max="120" />
        <span class="form-tip">超过该时长未接入人工时将引导用户留言</span>
      </el-form-item>
      <el-form-item label="智能客服机器人" prop="robotEnabled">
        <el-switch v-model="form.robotEnabled" active-text="开启" inactive-text="关闭" />
      </el-form-item>
      <el-form-item label="机器人欢迎语" prop="robotWelcome">
        <el-input
          v-model="form.robotWelcome"
          type="textarea"
          :rows="4"
          :disabled="!form.robotEnabled"
          placeholder="请输入机器人欢迎语"
        />
      </el-form-item>
      <el-form-item label="非工作时间指引" prop="manualGuide">
        <el-input v-model="form.manualGuide" type="textarea" :rows="3" placeholder="请输入非工作时间指引" />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" :loading="loading" @click="submitForm">保存配置</el-button>
      </el-form-item>
    </el-form>
  </div>
</template>

<script setup name="Service">
import { getServiceConfig, updateServiceConfig } from '@/api/content/service'

const { proxy } = getCurrentInstance()

const loading = ref(false)

const form = reactive({
  workTime: undefined,
  phone: undefined,
  email: undefined,
  responseTimeout: 10,
  robotEnabled: false,
  robotWelcome: undefined,
  manualGuide: undefined
})

/** 查询客服配置 */
function getConfig() {
  getServiceConfig()
    .then((response) => {
      const res = response.data || response
      form.workTime = res.workTime
      form.phone = res.phone
      form.email = res.email
      form.responseTimeout = res.responseTimeout != undefined ? Number(res.responseTimeout) : 10
      form.robotEnabled = res.robotEnabled === true || res.robotEnabled === 'true' || res.robotEnabled === 1
      form.robotWelcome = res.robotWelcome
      form.manualGuide = res.manualGuide
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('查询失败，请重试') || proxy?.$message?.error('查询失败，请重试')
    })
}

/** 保存配置 */
function submitForm() {
  loading.value = true
  updateServiceConfig(JSON.parse(JSON.stringify(form)))
    .then(() => {
      proxy.$modal.msgSuccess('保存成功')
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('操作失败') || proxy?.$message?.error('操作失败')
    })
    .finally(() => {
      loading.value = false
    })
}

getConfig()
</script>

<style lang="scss" scoped>
.app-container {
  .form-tip {
    margin-left: 8px;
    color: #909399;
    font-size: 12px;
  }
}
</style>
