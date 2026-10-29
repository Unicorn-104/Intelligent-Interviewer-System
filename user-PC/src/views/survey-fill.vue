<template>
  <div class="sf-page">
    <header class="sf-topbar">
      <div class="sf-bar">
        <a class="sf-brand" :href="appHref('/index')"><span class="sf-mark">智</span>智聘 AI</a>
      </div>
    </header>

    <main class="sf-main">
      <section class="sf-card">
        <template v-if="loading">
          <div class="sf-loading">正在加载问卷…</div>
        </template>

        <template v-else-if="error">
          <span class="sf-badge warn">链接无效</span>
          <h1>问卷链接无效或已失效</h1>
          <p class="sf-tip">请确认链接是否完整，或联系招聘 HR 重新发送。</p>
          <button class="sf-back" @click="goBack">返回</button>
        </template>

        <template v-else-if="submitted">
          <span class="sf-badge ok">已提交</span>
          <h1>感谢您的反馈</h1>
          <p class="sf-tip">问卷已提交成功，您的评价将帮助招聘团队持续改进面试体验。</p>
          <button class="sf-back" @click="goBack">返回</button>
        </template>

        <template v-else>
          <span class="sf-badge">{{ info.companyName || '企业' }} · 满意度调研</span>
          <h1>{{ info.templateName || '面试体验调研' }}</h1>
          <p class="sf-tip">{{ info.candidateName ? info.candidateName + '，' : '' }}请根据本次求职体验填写以下问卷，提交后将匿名汇总给招聘团队。</p>

          <div class="sf-questions">
            <div v-for="(q, index) in questions" :key="q.qid" class="sf-q">
              <p class="sf-q-title"><span>{{ index + 1 }}.</span>{{ q.title }}</p>

              <div v-if="q.type === 'rating'" class="sf-stars">
                <button
                  v-for="n in 5"
                  :key="n"
                  :class="['sf-star', { on: Number(answers[q.qid]) >= n }]"
                  :title="n + ' 分'"
                  @click="answers[q.qid] = n"
                >★</button>
              </div>

              <div v-else-if="q.type === 'single'" class="sf-options">
                <label v-for="opt in q.options || []" :key="opt" class="sf-option">
                  <input v-model="answers[q.qid]" type="radio" :value="opt" />
                  <span>{{ opt }}</span>
                </label>
              </div>

              <div v-else-if="q.type === 'multi'" class="sf-options">
                <label v-for="opt in q.options || []" :key="opt" class="sf-option">
                  <input type="checkbox" :value="opt" :checked="isChecked(q.qid, opt)" @change="toggleMulti(q.qid, opt)" />
                  <span>{{ opt }}</span>
                </label>
              </div>

              <textarea v-else v-model="answers[q.qid]" class="sf-text" rows="3" maxlength="300" placeholder="请输入您的反馈" />
            </div>
          </div>

          <button class="sf-submit" :disabled="submitting || !answeredCount" @click="submit">
            {{ submitting ? '提交中…' : '提交问卷' }}
          </button>
          <p class="sf-hint">已填写 {{ answeredCount }} / {{ questions.length }} 题</p>
        </template>
      </section>
    </main>
  </div>
</template>

<script setup>
import { appHref } from '@/utils/agentNavigation'
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getSurveyFill, submitSurveyFill } from '@/api/system/survey'

const route = useRoute()
const router = useRouter()
const token = ref('')
const loading = ref(true)
const error = ref(false)
const info = ref({})
const questions = ref([])
const submitted = ref(false)
const submitting = ref(false)
const answers = reactive({})

// 已填写的题目数：评分/单选/多选/文本任一有值即算
const answeredCount = computed(() => questions.value.filter(q => {
  const value = answers[q.qid]
  return Array.isArray(value) ? value.length > 0 : value != null && String(value).trim() !== ''
}).length)

// 返回：优先回上一页（从消息里的链接进入），直接打开链接时没有上一页，回到求职者首页
function goBack() {
  if (window.history.state && window.history.state.back) router.back()
  else router.push('/index')
}

function isChecked(qid, opt) {
  const value = answers[qid]
  return Array.isArray(value) && value.includes(opt)
}

function toggleMulti(qid, opt) {
  const list = Array.isArray(answers[qid]) ? answers[qid] : []
  answers[qid] = list.includes(opt) ? list.filter(item => item !== opt) : [...list, opt]
}

function parseQuestions(raw) {
  if (Array.isArray(raw)) return raw
  try {
    const list = JSON.parse(raw || '[]')
    return Array.isArray(list) ? list : []
  } catch (e) {
    return []
  }
}

async function submit() {
  if (!answeredCount.value) return
  submitting.value = true
  try {
    // 只提交有作答的题目，未作答的题目不落空值
    const payload = {}
    questions.value.forEach(q => {
      const value = answers[q.qid]
      if (Array.isArray(value) ? value.length : value != null && String(value).trim() !== '') {
        payload[q.qid] = value
      }
    })
    await submitSurveyFill({ token: token.value, answers: payload })
    submitted.value = true
  } catch (e) {
    error.value = false
    window.alert(e?.message || '提交失败，请稍后重试')
  } finally {
    submitting.value = false
  }
}

onMounted(async () => {
  token.value = route.query.token || ''
  if (!token.value) {
    loading.value = false
    error.value = true
    return
  }
  try {
    const res = await getSurveyFill(token.value)
    info.value = res?.data || {}
    questions.value = parseQuestions(info.value.questions)
    // 令牌已失效与「已填写」要区分：失效直接提示无效，已填写展示已提交
    if (info.value.invalid) {
      error.value = true
      return
    }
    submitted.value = !!info.value.submitted
    if (!questions.value.length) error.value = true
  } catch (e) {
    error.value = true
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.sf-page {
  --p: #1A3C6E;
  --b: #2B7FFF;
  --bg: #F5F7FA;
  --text: #172B4D;
  --muted: #6B7A90;
  --line: #E6EBF2;
  min-height: 100vh;
  background: var(--bg);
  color: var(--text);
  font: 14px/1.6 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
}
.sf-page * { box-sizing: border-box; }
.sf-page button { font: inherit; cursor: pointer; }
.sf-page h1 { margin: 0; }

.sf-topbar { height: 72px; display: flex; align-items: center; background: #fff; border-bottom: 1px solid var(--line); }
.sf-bar { width: min(760px, calc(100% - 48px)); margin: auto; }
.sf-brand { display: flex; align-items: center; gap: 10px; color: var(--p); font-size: 18px; font-weight: 800; text-decoration: none; }
.sf-mark { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 9px; color: #fff; background: linear-gradient(145deg, #2B7FFF, #1A3C6E); }

.sf-main { padding: 40px 24px; display: flex; justify-content: center; }
.sf-card { width: min(720px, 100%); padding: 32px; border: 1px solid var(--line); border-radius: 14px; background: #fff; box-shadow: 0 12px 34px rgba(26, 60, 110, .08); }
.sf-loading { padding: 40px 0; text-align: center; color: var(--muted); }
.sf-badge { display: inline-block; padding: 4px 10px; border-radius: 999px; color: var(--b); background: #EAF2FF; font-size: 12px; font-weight: 700; }
.sf-badge.warn { color: #C98A00; background: #FFF7E6; }
.sf-badge.ok { color: #15803D; background: #E9F9EF; }
.sf-card h1 { margin-top: 12px; font-size: 20px; color: var(--p); }
.sf-tip { margin-top: 10px; color: var(--muted); font-size: 13px; }

.sf-questions { margin-top: 24px; display: grid; gap: 20px; }
.sf-q { padding-bottom: 18px; border-bottom: 1px dashed var(--line); }
.sf-q:last-child { border-bottom: 0; padding-bottom: 0; }
.sf-q-title { display: flex; gap: 6px; margin: 0 0 10px; font-size: 14px; font-weight: 600; color: var(--text); }
.sf-stars { display: flex; gap: 6px; }
.sf-star { width: 34px; height: 34px; border: 1px solid var(--line); border-radius: 8px; background: #fff; color: #D5DEEA; font-size: 18px; line-height: 1; }
.sf-star.on { color: #F5A524; border-color: #F7D08A; background: #FFFAF0; }
.sf-options { display: grid; gap: 8px; }
.sf-option { display: flex; align-items: center; gap: 8px; padding: 9px 12px; border: 1px solid var(--line); border-radius: 9px; font-size: 13px; color: #40516A; cursor: pointer; }
.sf-option:hover { border-color: var(--b); }
.sf-option input { accent-color: var(--b); }
.sf-text { width: 100%; padding: 10px 12px; border: 1px solid var(--line); border-radius: 9px; font: inherit; font-size: 13px; color: var(--text); outline: none; resize: vertical; }
.sf-text:focus { border-color: var(--b); }

.sf-submit { width: 100%; height: 46px; margin-top: 24px; border: 0; border-radius: 10px; color: #fff; font-size: 15px; font-weight: 700; background: linear-gradient(135deg, #2B7FFF, #1A3C6E); box-shadow: 0 8px 20px rgba(43, 127, 255, .26); }
.sf-submit:disabled { opacity: .55; cursor: not-allowed; box-shadow: none; }
.sf-hint { margin-top: 10px; text-align: center; color: var(--muted); font-size: 12px; }
.sf-back { margin-top: 20px; min-width: 120px; height: 40px; padding: 0 24px; border: 1px solid var(--line); border-radius: 10px; background: #fff; color: var(--p); font-size: 14px; font-weight: 700; }
.sf-back:hover { border-color: var(--b); color: var(--b); }
</style>
