<template>
  <div class="scf">
    <slot name="top" />
    <div class="scf-grid">
      <div class="scf-field">
        <label>开考时间</label>
        <input class="scf-input" type="datetime-local" :min="minStart" v-model="form.startAt" />
      </div>
      <div class="scf-field">
        <label>截止时间</label>
        <input class="scf-input" type="datetime-local" :min="form.startAt || minStart" v-model="form.endAt" />
      </div>
      <div class="scf-field">
        <label>最大考试次数</label>
        <input class="scf-input" type="number" min="1" v-model.number="form.maxAttempts" />
      </div>
      <div class="scf-field">
        <label>通过阈值（分）<span v-if="totalScore" class="scf-hint">总分 {{ totalScore }}</span></label>
        <input class="scf-input" type="number" min="1" v-model.number="form.passThreshold" />
      </div>

      <div v-if="showSubmitRule" class="scf-field scf-full">
        <label>交卷规则</label>
        <div class="scf-checks">
          <label><input type="checkbox" v-model="form.autoSubmit" />超时自动交卷</label>
          <label><input type="checkbox" v-model="form.allowEarly" />允许提前交卷</label>
          <label class="scf-inline"><Timer :size="14" />自动保存间隔
            <input class="scf-input scf-tiny" type="number" min="5" v-model.number="form.autosaveInterval" /> 秒
          </label>
        </div>      </div>

      <div v-if="showDualCamera" class="scf-field scf-full">
        <label>双机位要求</label>
        <div class="scf-seg">
          <button type="button" :class="['scf-seg-btn', { on: !Number(form.forceDualCamera) }]" @click="form.forceDualCamera = 0">不启用</button>
          <button type="button" :class="['scf-seg-btn', { on: !!Number(form.forceDualCamera) }]" @click="form.forceDualCamera = 1">强制双机位</button>
        </div>
        <div v-if="Number(form.forceDualCamera)" class="scf-grid scf-sub">
          <div class="scf-field"><label>副机位角度要求</label><input class="scf-input" v-model="form.dualAngle" /></div>
          <div class="scf-field"><label>补充说明</label><input class="scf-input" v-model="form.dualNote" placeholder="如：手机横置，拍到全身与屏幕" /></div>
        </div>
      </div>

      <div v-if="showAutoFlow" class="scf-field scf-full">
        <label>通过自动邀约面试<span class="scf-hint">（总分达到阈值后自动为候选人创建面试邀约；不选则仅更新人才库状态，需人工安排）</span></label>
        <div class="scf-grid scf-sub scf-3">
          <div class="scf-field">
            <label>面试官</label>
            <select class="scf-input" v-model="form.autoInterviewerId">
              <option value="">不自动邀约</option>
              <option v-for="it in interviewers" :key="it.userId" :value="String(it.userId)">{{ it.userName }}{{ it.jobTitle ? ' · ' + it.jobTitle : '' }}</option>
            </select>
          </div>
          <div class="scf-field"><label>建议时间延后（天）</label><input class="scf-input" type="number" min="1" v-model.number="form.autoInviteDays" /></div>
          <div class="scf-field"><label>面试时长（分钟）</label><input class="scf-input" type="number" min="10" v-model.number="form.autoInviteDuration" /></div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { Timer } from '@/views/enterprise/components/icons'

defineProps({
  form: { type: Object, required: true },
  interviewers: { type: Array, default: () => [] },
  totalScore: { type: [Number, String], default: '' },
  minStart: { type: String, default: '' },
  showSubmitRule: { type: Boolean, default: true },
  showDualCamera: { type: Boolean, default: true },
  showAutoFlow: { type: Boolean, default: true }
})
</script>

<style scoped>
.scf{display:flex;flex-direction:column;gap:12px;min-width:0}
.scf-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}
.scf-sub{grid-column:1/-1}
.scf-3{grid-template-columns:repeat(3,minmax(0,1fr))}
.scf-field{display:flex;flex-direction:column;gap:6px;min-width:0}
.scf-field.scf-full{grid-column:1/-1}
.scf-field>label{font-size:12px;font-weight:600;color:#3b4a61;display:flex;gap:6px;align-items:baseline;flex-wrap:wrap}
.scf-hint{font-weight:400;font-size:10px;color:#8d9baf}
.scf-checks{display:flex;flex-wrap:wrap;gap:14px;align-items:center;font-size:12px;color:#40516a}
.scf-checks label{display:flex;align-items:center;gap:6px;font-size:12px;font-weight:400;color:#40516a;white-space:nowrap;flex:none}
.scf-inline{gap:4px;white-space:nowrap;flex:none}
.scf-tiny{width:76px;flex:none}
.scf-input{height:36px;border:1px solid var(--line,#dfe6ef);border-radius:9px;background:#fff;color:var(--text,#0f172a);padding:0 11px;font-size:12px;outline:none;width:100%;min-width:0;box-sizing:border-box;font-family:inherit}
.scf-input:focus{border-color:#2563eb;box-shadow:0 0 0 3px rgba(37,99,235,.1)}
.scf-seg{display:inline-flex;border:1px solid var(--line,#dfe6ef);border-radius:8px;overflow:hidden;width:fit-content}
.scf-seg-btn{border:0;background:#fff;color:#64748b;padding:7px 14px;font-size:12px;cursor:pointer}
.scf-seg-btn.on{background:#2563eb;color:#fff}
</style>
