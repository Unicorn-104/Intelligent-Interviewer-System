<script setup>
import { ref, inject, onMounted } from 'vue'
import { Save } from '@/views/enterprise/components/icons'
import { getCompanyInfo, updateCompanyInfo } from '@/api/system/settings'
const notify = inject('settingsNotify')
const loading = ref(false)
const saving = ref(false)
const form = ref({})

function normalize(data = {}) {
  return {
    name: data.name || '',
    industry: data.industry || '',
    size: data.size || '',
    city: data.city || '',
    address: data.address || '',
    website: data.website || '',
    logoUrl: data.logoUrl || '',
    intro: data.intro || ''
  }
}

async function load() {
  loading.value = true
  try {
    const res = await getCompanyInfo()
    form.value = normalize(res.data)
  } finally {
    loading.value = false
  }
}

async function save() {
  if (!form.value.name) {
    notify('企业名称不能为空')
    return
  }
  saving.value = true
  try {
    const res = await updateCompanyInfo(form.value)
    form.value = normalize(res.data)
    notify('公司信息已保存')
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<template>
  <div>
    <header class="tab-head">
      <div><h2>公司信息</h2><p>维护企业在候选人端展示的基础资料</p></div>
      <button class="btn primary" type="button" :disabled="saving || loading" @click="save">
        <Save :size="15"/>{{ saving ? '保存中…' : '保存修改' }}
      </button>
    </header>

    <div v-if="loading" class="loading">正在加载公司信息…</div>
    <form v-else class="company-form" @submit.prevent="save">
      <div class="form-grid">
        <label><span class="field-label">企业名称<em>*</em></span><input v-model.trim="form.name" maxlength="100" placeholder="请输入企业全称"/></label>
        <label><span class="field-label">所属行业</span><input v-model.trim="form.industry" maxlength="50" placeholder="如：互联网/软件"/></label>
        <label><span class="field-label">企业规模</span><input v-model.trim="form.size" maxlength="20" placeholder="如：100-499人"/></label>
        <label><span class="field-label">所在城市</span><input v-model.trim="form.city" maxlength="50" placeholder="如：杭州"/></label>
        <label class="full"><span class="field-label">详细地址</span><input v-model.trim="form.address" maxlength="200" placeholder="请输入办公地址"/></label>
        <label class="full"><span class="field-label">企业官网</span><input v-model.trim="form.website" maxlength="255" placeholder="如：https://www.example.com"/></label>
        <label class="full"><span class="field-label">Logo 地址<span class="field-tip">（企业标识图片的 URL，用于候选人端企业主页和职位卡片展示）</span></span><input v-model.trim="form.logoUrl" maxlength="255" placeholder="请输入企业 Logo 图片地址"/></label>
        <label class="full"><span class="field-label">企业简介</span><textarea v-model.trim="form.intro" rows="5" maxlength="4000" placeholder="介绍企业业务、团队与文化"></textarea></label>
      </div>
      <p class="form-tip">保存后将同步更新候选人端展示的企业资料。</p>
    </form>
  </div>
</template>

<style scoped>
.tab-head{display:flex;align-items:flex-start;justify-content:space-between}.tab-head h2{font-size:19px}.tab-head p{font-size:10px;color:#8d9baf;margin-top:5px}
.company-form{margin-top:20px}.form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px 18px}
.form-grid label{display:flex;flex-direction:column;gap:7px;min-width:0;font-size:11px;color:#465b79}
.form-grid label.full{grid-column:1/-1}
.field-label{display:flex;align-items:center;line-height:1.4}
.field-tip{color:#9aa7b9;font-size:10px;font-weight:400}
.form-grid em{color:#ef4444;font-style:normal;margin-left:2px}
.form-grid input,.form-grid textarea{width:100%;box-sizing:border-box;border:1px solid #dfe6ef;border-radius:8px;padding:0 10px;font-family:inherit;font-size:12px;color:#172b4d;background:#fff;outline:none}
.form-grid input{height:36px}
.form-grid textarea{padding:9px 10px;line-height:1.6;resize:vertical}
.form-grid input:focus,.form-grid textarea:focus{border-color:#2563eb}
.form-tip{margin-top:12px;font-size:9px;color:#9aa7b9}
.loading{height:120px;display:grid;place-items:center;color:#9aa7b9;font-size:10px}
@media(max-width:900px){.form-grid{grid-template-columns:1fr}}
</style>
