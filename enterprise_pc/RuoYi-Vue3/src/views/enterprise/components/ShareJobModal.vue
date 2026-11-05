<script setup>
import { computed, ref } from 'vue'
import { Search, Send, Check } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import { listSessions } from '@/api/system/im'
import { shareJobCard } from '@/api/system/job'

const props = defineProps({ job: { type: Object, required: true } })
const emit = defineEmits(['close', 'sent'])

const keyword = ref('')
const people = ref([])
const loading = ref(true)
const sending = ref(false)
const pickedId = ref(null)

const filtered = computed(() => {
  const kw = keyword.value.trim()
  if (!kw) return people.value
  return people.value.filter(p => p.name.includes(kw) || p.summary.includes(kw))
})

// 联系人来源为消息中心会话列表：与哪个人聊过，就能把岗位卡片发给他
async function loadPeople() {
  loading.value = true
  try {
    const res = await listSessions()
    people.value = (res.data || []).map(s => ({
      id: s.sessionId,
      peerId: s.peerId,
      name: s.peerName || ('用户' + s.peerId),
      summary: s.lastMessage || ''
    }))
  } catch (e) {
    people.value = []
  } finally {
    loading.value = false
  }
}
loadPeople()

// 后端要求 24 位小写十六进制请求标识，用于识别同一次分享的重复提交
function newRequestId() {
  const bytes = new Uint8Array(12)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('')
}

async function send() {
  const target = people.value.find(p => p.id === pickedId.value)
  if (!target || sending.value) return
  sending.value = true
  try {
    await shareJobCard({
      sessionId: target.id,
      peerId: target.peerId,
      positionId: props.job.id,
      requestId: newRequestId()
    })
    emit('sent', target.name)
  } catch (e) {
    // 请求拦截器已提示失败原因，弹窗保持打开便于重试
  } finally {
    sending.value = false
  }
}
</script>

<template>
  <BaseModal title="分享岗位" width="520px" @close="$emit('close')">
    <div class="share-job">
      <div class="job-preview">
        <b>{{ job.name }}</b>
        <p>{{ job.dept }} · {{ job.city }} · {{ job.salary }}</p>
      </div>
      <label class="search-box"><Search :size="16"/><input v-model="keyword" placeholder="搜索消息中心联系人"/></label>
      <p class="tip">仅可分享给消息中心已有会话的候选人，如需新增联系人请先在候选人详情页发起沟通。</p>
      <p v-if="loading" class="empty">加载中…</p>
      <p v-else-if="!filtered.length" class="empty">{{ keyword.trim() ? '没有匹配的联系人' : '消息中心暂无联系人' }}</p>
      <div v-else class="person-list">
        <button v-for="p in filtered" :key="p.id" class="person" :class="{ on: pickedId === p.id }" @click="pickedId = p.id">
          <MiniAvatar :name="p.name" :size="34" color="#356f65"/>
          <div><b>{{ p.name }}</b><small>{{ p.summary || '暂无消息' }}</small></div>
          <Check v-if="pickedId === p.id" :size="16"/>
        </button>
      </div>
    </div>
    <template #footer>
      <button class="btn" @click="$emit('close')">取消</button>
      <button class="btn primary" :disabled="pickedId == null || sending" @click="send"><Send :size="15"/>{{ sending ? '发送中…' : '发送岗位卡片' }}</button>
    </template>
  </BaseModal>
</template>

<style scoped>
.share-job{display:flex;flex-direction:column;gap:12px}
.job-preview{border:1px solid #dce8fc;background:linear-gradient(135deg,#edf4ff,#f8fbff);border-radius:11px;padding:12px 14px}
.job-preview b{font-size:15px}
.job-preview p{margin-top:5px;color:#7d8da5;font-size:11px}
.search-box{height:38px;border:1px solid #dce4ee;border-radius:9px;display:flex;align-items:center;gap:8px;padding:0 11px;color:#8da0ba}
.search-box input{width:100%;border:0;outline:0;font-size:12px}
.tip{color:#9aa8ba;font-size:10px;line-height:1.5}
.empty{color:#98a5b7;font-size:11px;text-align:center;padding:18px 0}
.person-list{max-height:300px;overflow:auto;display:flex;flex-direction:column;gap:6px}
.person{display:flex;align-items:center;gap:10px;border:1px solid #e1e8f2;border-radius:10px;background:white;padding:8px 11px;text-align:left}
.person:hover{border-color:#b6cbf7}
.person.on{border-color:#2563eb;background:#edf4ff}
.person>div{min-width:0;flex:1}
.person b{display:block;font-size:13px}
.person small{display:block;margin-top:3px;color:#8392a7;font-size:10px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.person>svg{color:#2563eb;flex:none}
</style>
