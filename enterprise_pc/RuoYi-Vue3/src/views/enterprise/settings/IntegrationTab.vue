<script setup>
import { ref, inject, onMounted } from 'vue'
import { CalendarDays, Video } from '@/views/enterprise/components/icons'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import { listIntegrations, saveIntegration } from '@/api/system/settings'
const notify = inject('settingsNotify')
const list = ref([])
const modal = ref(null)
const form = ref({})

const meta = {
  outlook: { name: 'Microsoft Outlook Calendar', desc: '双向同步面试日程与个人空闲时间', icon: 'calendar', comp: CalendarDays, fields: [['clientId', 'Client ID'], ['redirectUri', '回调地址']] },
  tencent_meeting: { name: '腾讯会议', desc: '自动创建视频会议并发送参会信息', icon: 'meeting', comp: Video, fields: [['sdkId', 'SDK ID'], ['secret', 'Secret Key']] },
  zoom: { name: 'Zoom', desc: '为跨地区候选人创建视频会议', icon: 'zoom', letter: 'Z', fields: [['accountId', 'Account ID'], ['apiKey', 'API Key']] },
  livekit: { name: 'LiveKit', desc: '私有化实时音视频与 AI 转写服务', icon: 'live', letter: 'L', fields: [['serverUrl', '服务地址']] }
}
const statusPill = { 1: ['green', '已连接'], 2: ['orange', '需配置'], 0: ['gray', '未连接'] }

async function load() { const res = await listIntegrations(); list.value = res.data }
function parse(cfg) { try { return cfg ? JSON.parse(cfg) : {} } catch (e) { return {} } }
function open(p, connect) {
  form.value = { provider: p.provider, status: connect ? 1 : p.status, config: parse(p.configJson) }
  modal.value = p.provider
}
async function save(connect) {
  const configJson = JSON.stringify(form.value.config || {})
  const status = connect ? 1 : form.value.status
  await saveIntegration(form.value.provider, { status, configJson })
  notify(connect ? '已连接并保存' : '配置已保存'); modal.value = null; load()
}
async function disconnect(p) {
  await saveIntegration(p.provider, { status: 0, configJson: p.configJson })
  notify('已断开连接'); load()
}
onMounted(load)
</script>

<template>
  <div><header class="tab-head"><div><h2>面试集成</h2><p>连接日历与视频会议服务，实现排期自动化</p></div></header>
    <div class="integrations">
      <article v-for="p in list" :key="p.provider">
        <span class="integration-icon" :class="meta[p.provider]?.icon"><component :is="meta[p.provider]?.comp" :size="22" v-if="meta[p.provider]?.comp"/>{{meta[p.provider]?.letter}}</span>
        <div><h3>{{meta[p.provider]?.name||p.provider}}</h3><p>{{meta[p.provider]?.desc}}</p></div>
        <span class="pill" :class="statusPill[p.status][0]">{{statusPill[p.status][1]}}</span>
        <button v-if="p.status===1" class="btn sm" @click="open(p,false)">配置</button>
        <button v-if="p.status===1" class="btn sm danger-ghost" @click="disconnect(p)">断开</button>
        <button v-else class="btn sm primary" @click="open(p,true)">{{p.status===2?'配置':'连接'}}</button>
      </article>
    </div>
    <BaseModal v-if="modal" :title="'配置 '+(meta[modal]?.name||modal)" width="460px" @close="modal=null">
      <div class="form">
        <label v-for="f in (meta[modal]?.fields||[])" :key="f[0]">{{f[1]}}<input v-model="form.config[f[0]]" :placeholder="f[1]"/></label>
      </div>
      <template #footer>
        <button class="btn" @click="modal=null">取消</button>
        <button class="btn primary" @click="save(false)">仅保存</button>
        <button class="btn primary" @click="save(true)">保存并连接</button>
      </template>
    </BaseModal>
  </div>
</template>

<style scoped>
.tab-head{display:flex;align-items:flex-start;justify-content:space-between}.tab-head h2{font-size:19px}.tab-head p{font-size:10px;color:#8d9baf;margin-top:5px}
.integrations{margin-top:20px;display:flex;flex-direction:column;gap:10px}.integrations article{min-height:78px;border:1px solid #e1e8f1;border-radius:11px;padding:13px;display:flex;align-items:center;gap:12px}.integration-icon{width:42px;height:42px;border-radius:11px;background:#eaf1ff;color:#2563eb;display:grid;place-items:center;font-weight:700}.integration-icon.calendar{color:#0673d7}.integration-icon.zoom{background:#edf3ff}.integration-icon.live{background:#e9f9f4;color:#07966c}.integrations article>div{flex:1}.integrations h3{font-size:12px}.integrations p{font-size:9px;color:#8796ab;margin-top:5px}
.form{display:flex;flex-direction:column;gap:12px}.form label{font-size:11px;color:#465b79;display:flex;flex-direction:column;gap:5px}.form input{height:34px;border:1px solid #dfe6ef;border-radius:8px;padding:0 10px;font-size:12px}
</style>
