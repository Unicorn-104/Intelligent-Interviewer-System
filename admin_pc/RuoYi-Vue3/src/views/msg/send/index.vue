<template>
  <div class="app-container">
    <el-card shadow="never">
      <el-form :model="form" label-width="100px">
        <el-form-item label="发送渠道">
          <el-radio-group v-model="form.channel">
            <el-radio-button value="inapp">站内信</el-radio-button>
            <el-radio-button value="email">邮件</el-radio-button>
          </el-radio-group>
        </el-form-item>

        <el-form-item label="接收人">
          <el-select v-model="form.targets" multiple filterable placeholder="选择企业用户" style="width:60%">
            <el-option v-for="u in recipients" :key="u.userId"
              :label="(u.companyName || '个人') + ' / ' + u.userName + (u.email ? ' ('+u.email+')' : '')"
              :value="u.userId" />
          </el-select>
          <el-button text @click="form.targets = allUserIds">全选</el-button>
          <el-button text @click="form.targets = []">清空</el-button>
        </el-form-item>

        <el-form-item label="标题">
          <el-input v-model="form.title" placeholder="消息标题" style="width:60%" />
        </el-form-item>

        <el-form-item label="内容">
          <el-input v-model="form.content" type="textarea" :rows="6" placeholder="消息内容" style="width:60%" />
        </el-form-item>

        <el-form-item>
          <el-button type="primary" :loading="sending" @click="send">发送</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup name="MsgSend">
import request from '@/utils/request'
const recipients = ref([])
const allUserIds = ref([])
const sending = ref(false)
const form = ref({ channel: 'inapp', targets: [], title: '', content: '' })

onMounted(async () => {
  const r = await request({ url: '/msg/send/recipients' })
  recipients.value = r.data || []
  allUserIds.value = recipients.value.map(u => u.userId)
})

async function send() {
  if (!form.value.targets.length) return ElMessage.warning('请选择接收人')
  if (!form.value.content.trim()) return ElMessage.warning('请输入内容')
  sending.value = true
  try {
    const r = await request({ url: '/msg/send', method: 'post', data: form.value })
    ElMessage.success(`发送完成：成功 ${r.data.ok}，失败 ${r.data.fail}`)
    form.value.content = ''
    form.value.targets = []
  } catch (e) {
    ElMessage.error('发送失败')
  } finally {
    sending.value = false
  }
}
</script>
