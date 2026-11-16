<template>
  <div class="app-container">
    <el-card shadow="never">
      <div style="margin-bottom:16px">
        <el-upload :show-file-list="false" :before-upload="beforeUpload" action="/ai/kb/upload"
          :headers="{ Authorization: 'Bearer ' + token }" name="file" :data="{ category: '操作手册' }" accept=".txt,.md">
          <el-button type="primary">上传文档</el-button>
        </el-upload>
        <el-button type="success" style="margin-left:10px" @click="dialogVisible = true">手动添加知识</el-button>
      </div>

      <el-table :data="list" border size="small" v-loading="loading">
        <el-table-column label="ID" prop="kb_id" width="60" />
        <el-table-column label="问题/标题" prop="question" show-overflow-tooltip />
        <el-table-column label="分类" prop="category" width="120" />
        <el-table-column label="引用次数" prop="use_count" width="80" />
        <el-table-column label="创建时间" prop="created_at" width="160" />
        <el-table-column label="操作" width="80">
          <template #default="{ row }">
            <el-button type="danger" size="small" @click="del(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="dialogVisible" title="添加知识" width="600px">
      <el-form :model="form" label-width="80px">
        <el-form-item label="问题">
          <el-input v-model="form.question" placeholder="用户可能问的问题" />
        </el-form-item>
        <el-form-item label="回答">
          <el-input v-model="form.answer" type="textarea" :rows="5" placeholder="标准答案" />
        </el-form-item>
        <el-form-item label="分类">
          <el-input v-model="form.category" placeholder="如：系统管理" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="add">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getToken } from '@/utils/auth'
import { ElMessage, ElMessageBox } from 'element-plus'
import request from '@/utils/request'

const token = getToken()
const list = ref([])
const loading = ref(false)
const dialogVisible = ref(false)
const form = ref({ question: '', answer: '', category: '' })

function load() {
  loading.value = true
  request.get('/ai/kb/list').then(r => {
    list.value = r.data || []
  }).finally(() => loading.value = false)
}

function add() {
  if (!form.value.question || !form.value.answer) {
    ElMessage.warning('问题和回答不能为空')
    return
  }
  request.post('/ai/kb/add', null, { params: form.value }).then(() => {
    ElMessage.success('添加成功')
    dialogVisible.value = false
    form.value = { question: '', answer: '', category: '' }
    load()
  })
}

function del(row) {
  ElMessageBox.confirm('确认删除这条知识？', '提示', { type: 'warning' }).then(() => {
    request.delete('/ai/kb/' + row.kb_id).then(() => {
      ElMessage.success('已删除')
      load()
    })
  })
}

function beforeUpload(file) {
  if (!file.name.endsWith('.txt') && !file.name.endsWith('.md')) {
    ElMessage.warning('只支持txt/md')
    return false
  }
  ElMessage.success('上传中，Embedding需要几秒...')
  setTimeout(load, 3000)
  return true
}

onMounted(load)
</script>
