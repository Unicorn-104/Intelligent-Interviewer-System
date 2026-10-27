<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ArrowLeft, Sparkles, CheckCircle2, AlertTriangle, FileText, Send, RotateCcw } from '@/views/enterprise/components/icons'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { getInterviewReview, confirmInterviewReview, adjustInterviewReview, rejectInterviewReview, cascadeInterviewReview } from '@/api/interview'
import { triggerOffer } from '@/api/offer'

const router = useRouter()
const route = useRoute()
const toast = ref('')
const loading = ref(true)
const submitting = ref(false)
const review = ref(null)
const comment = ref('')
const selectedRecommendation = ref(2)
const editScores = ref({})
const resultType = ref('final')
const cascadeInfo = ref(null)
const offerTriggering = ref(false)
const offerCreated = ref(false)

// 维度字典与阶段建议字典（与后端 t_int_evaluation 字段注释一致）
const DIMENSION_NAMES = { 1: '技术能力', 2: '逻辑思维', 3: '沟通表达', 4: '性格匹配', 5: '稳定性' }
const RECOMMENDATIONS = [
  { value: 1, label: '强烈推荐' },
  { value: 2, label: '推荐' },
  { value: 3, label: '待定' },
  { value: 4, label: '不推荐' }
]

function notify(msg) {
  toast.value = msg
  setTimeout(() => (toast.value = ''), 2400)
}

function modeLabel(mode) {
  switch (Number(mode)) {
    case 1: return '纯 AI 面试'
    case 2: return 'AI + HR 协同'
    case 3: return 'AI + 多面试官'
    case 4: return '无 AI · 纯人工'
    default: return '面试'
  }
}

const dimensions = computed(() => {
  const raw = review.value?.dimensionScores
  if (!raw || typeof raw !== 'object') return []
  return Object.keys(raw)
    .sort((a, b) => Number(a) - Number(b))
    .map((key) => ({
      key,
      name: DIMENSION_NAMES[key] || `维度 ${key}`,
      score: Math.max(0, Math.min(100, Number(raw[key]) || 0))
    }))
})

const reviewed = computed(() => Number(review.value?.hrStatus) !== 0)

const scoresChanged = computed(() =>
  dimensions.value.some((item) => Number(editScores.value[item.key]) !== item.score)
)

function displayScore(key) {
  const value = Number(editScores.value[key])
  return Number.isFinite(value) ? Math.max(0, Math.min(100, value)) : 0
}

const statusInfo = computed(() => {
  if (!review.value) return { text: '', cls: 'gray' }
  if (review.value.hrRecommendation != null && Number(review.value.hrRecommendation) === 0) {
    return { text: '已驳回', cls: 'red' }
  }
  const hrStatus = Number(review.value.hrStatus)
  if (hrStatus === 1) return { text: '已确认', cls: 'green' }
  if (hrStatus === 2) return { text: '已调整', cls: 'green' }
  return { text: '待 HR 审核', cls: 'orange' }
})

const overallScore = computed(() => {
  const value = Number(review.value?.overallScore)
  return Number.isFinite(value) ? value.toFixed(1) : '—'
})

const stageTitle = computed(() => {
  const round = review.value?.round
  return round ? `第 ${round} 轮阶段评估` : '面试评估'
})

// 轮次说明：流程模板总轮次可获取时用于推导默认结果类型
const roundHint = computed(() => {
  const round = Number(review.value?.round)
  const total = Number(review.value?.totalRounds)
  if (!Number.isFinite(round) || round <= 0) return ''
  if (!Number.isFinite(total) || total <= 0) return `当前为第 ${round} 轮，无后续阶段配置信息`
  return `当前为第 ${round} / ${total} 轮`
})

const showOfferAction = computed(() =>
  reviewed.value
  && Number(review.value?.hrRecommendation) > 0
  && resultType.value === 'final'
)

async function load() {
  loading.value = true
  const sessionId = route.params.id
  if (!sessionId) {
    loading.value = false
    return
  }
  try {
    const res = await getInterviewReview(sessionId)
    review.value = res.data || null
    if (review.value) {
      const base = review.value.hrRecommendation ?? review.value.recommendation
      if (base !== null && base !== undefined && Number(base) > 0) {
        selectedRecommendation.value = Number(base)
      }
      comment.value = review.value.hrComment || ''
      editScores.value = Object.fromEntries(
        Object.entries(review.value.dimensionScores || {}).map(([key, value]) => [key, Number(value) || 0])
      )
      const round = Number(review.value.round)
      const total = Number(review.value.totalRounds)
      // 已终审时保留本次操作选择的结果类型，未终审时按轮次推导默认值
      if (!reviewed.value) {
        resultType.value = Number.isFinite(total) && total > 0 && round > 0 && round < total ? 'next' : 'final'
      }
    }
  } catch (e) {
    review.value = null
  } finally {
    loading.value = false
  }
}

async function publish() {
  if (!review.value || reviewed.value || submitting.value) return
  submitting.value = true
  try {
    const res = await confirmInterviewReview(review.value.sessionId, {
      recommendation: selectedRecommendation.value,
      comment: comment.value || undefined,
      isFinal: resultType.value === 'final'
    })
    cascadeInfo.value = res.data?.cascade || null
    notify(res.data?.message || res.msg || '评估已确认发布')
    await load()
  } catch (e) {
    // 请求拦截器已统一提示
  } finally {
    submitting.value = false
  }
}

async function adjust() {
  if (!review.value || reviewed.value || submitting.value) return
  if (!dimensions.value.length) {
    notify('该报告没有可调整的维度评分')
    return
  }
  if (!scoresChanged.value) {
    notify('评分未修改，可直接确认并发布')
    return
  }
  const dims = {}
  for (const item of dimensions.value) {
    const score = Number(editScores.value[item.key])
    if (!Number.isFinite(score) || score < 0 || score > 100) {
      notify(`${item.name}评分需在 0-100 之间`)
      return
    }
    dims[item.key] = Math.round(score)
  }
  submitting.value = true
  try {
    const res = await adjustInterviewReview(review.value.sessionId, {
      ...dims,
      recommendation: selectedRecommendation.value,
      comment: comment.value || undefined
    })
    if (resultType.value !== 'final') {
      // 调整接口不含级联，非终面时按级联规则单独创建下一轮预约
      const cascadeRes = await cascadeInterviewReview(review.value.sessionId)
      cascadeInfo.value = cascadeRes.data || null
    }
    notify(res.data?.message || res.msg || '评分已调整并确认通过')
    await load()
  } catch (e) {
    // 请求拦截器已统一提示
  } finally {
    submitting.value = false
  }
}

async function reject() {
  if (!review.value || reviewed.value || submitting.value) return
  if (!window.confirm('驳回后候选人将被标记为「已淘汰」并发送感谢信，确认继续？')) return
  submitting.value = true
  try {
    const res = await rejectInterviewReview(review.value.sessionId, { reason: comment.value || 'HR 终审驳回' })
    notify(res.data?.message || res.msg || '已驳回')
    await load()
  } catch (e) {
    // 请求拦截器已统一提示
  } finally {
    submitting.value = false
  }
}

async function createOfferDraft() {
  if (!review.value || offerTriggering.value) return
  offerTriggering.value = true
  try {
    const res = await triggerOffer(review.value.sessionId, {})
    offerCreated.value = true
    notify(res.data?.message || res.msg || '已生成录用意向书草稿')
  } catch (e) {
    // 请求拦截器已统一提示
  } finally {
    offerTriggering.value = false
  }
}

function goOffer() {
  router.push('/enterprise/offer')
}

function backToList() {
  router.push('/enterprise/interviews')
}

onMounted(load)
</script>

<template>
  <div class="page evaluation-page">
    <button class="back" @click="backToList"><ArrowLeft :size="15"/>返回面试列表</button>

    <div v-if="loading" class="card state-card">正在加载评估报告…</div>

    <div v-else-if="!review" class="card state-card empty">
      <FileText :size="28" />
      <b>暂无评估报告</b>
      <p>该场次尚未生成 AI 评估报告，请确认面试已结束且评估已完成后再查看。</p>
      <button class="btn" @click="backToList">返回面试列表</button>
    </div>

    <template v-else>
      <div class="page-heading">
        <div>
          <h1>{{ stageTitle }}</h1>
          <p>{{ review.candidateName || '未知候选人' }} · {{ review.positionTitle || '—' }} · {{ modeLabel(review.mode) }} · 会话 SES-{{ review.sessionId }}</p>
        </div>
        <span class="pill" :class="statusInfo.cls">{{ statusInfo.text }}</span>
      </div>

      <div class="evaluation-grid">
        <main>
          <section class="card score-card">
            <div class="score-overview">
              <div>
                <span class="eyebrow"><Sparkles :size="14"/>AI 阶段评估</span>
                <strong>{{ overallScore }}<small> / 100</small></strong>
                <p>基于对话证据、评分卡和人工补充生成</p>
              </div>
              <div class="ring">{{ Math.round(Number(review.overallScore) || 0) }}</div>
            </div>
            <div v-if="dimensions.length" class="score-bars">
              <div v-for="item in dimensions" :key="item.key">
                <span>{{ item.name }}</span>
                <input
                  v-if="!reviewed"
                  v-model.number="editScores[item.key]"
                  class="score-input"
                  type="number"
                  min="0"
                  max="100"
                  :disabled="submitting"
                />
                <b v-else>{{ item.score }}</b>
                <i><u :style="{ width: displayScore(item.key) + '%' }"/></i>
              </div>
            </div>
            <p v-else class="dim-empty">该报告未包含维度评分明细。</p>
          </section>

          <section class="card evidence-card">
            <div class="section-title"><span>AI 综合评语</span><FileText :size="16"/></div>
            <p class="summary-text">{{ review.summary || '暂无综合评语' }}</p>
            <div v-if="review.advantages" class="detail-block">
              <b>候选人亮点</b>
              <p class="summary-text">{{ review.advantages }}</p>
            </div>
            <div v-if="review.risks" class="detail-block">
              <b>潜在风险</b>
              <p class="summary-text">{{ review.risks }}</p>
            </div>
            <div v-if="review.gaps" class="detail-block">
              <b>能力缺口</b>
              <p class="summary-text">{{ review.gaps }}</p>
            </div>
          </section>
        </main>

        <aside>
          <section class="card decision-card">
            <div class="section-title"><span>HR 终审</span><CheckCircle2 :size="17" class="green"/></div>

            <div v-if="reviewed" class="reviewed-banner">
              <b>本场评估已完成终审</b>
              <p>结论：{{ RECOMMENDATIONS.find((r) => r.value === Number(review.hrRecommendation ?? review.recommendation))?.label || '—' }}</p>
              <p v-if="review.hrComment">评语：{{ review.hrComment }}</p>
            </div>

            <div v-if="cascadeInfo" class="cascade-box">
              <b>级联流转结果</b>
              <p>{{ cascadeInfo.message }}</p>
              <p v-if="cascadeInfo.nextRound">
                下一轮：第 {{ cascadeInfo.nextRound }} 轮 · 建议时间 {{ cascadeInfo.suggestedTime }}
              </p>
            </div>

            <label>结果类型</label>
            <div class="decision-options result-types">
              <button
                :class="{ active: resultType === 'final' }"
                :disabled="reviewed || submitting"
                @click="resultType = 'final'"
              >终面</button>
              <button
                :class="{ active: resultType === 'next' }"
                :disabled="reviewed || submitting"
                @click="resultType = 'next'"
              >非终面</button>
            </div>
            <p class="result-hint">
              {{ roundHint }}<template v-if="roundHint"> · </template>
              终面通过后进入 Offer 流程；非终面通过后按级联规则自动创建下一轮预约
            </p>

            <label>阶段建议</label>
            <div class="decision-options">
              <button
                v-for="item in RECOMMENDATIONS"
                :key="item.value"
                :class="{ active: selectedRecommendation === item.value }"
                :disabled="reviewed || submitting"
                @click="selectedRecommendation = item.value"
              >{{ item.label }}</button>
            </div>

            <label>HR 补充评语</label>
            <textarea v-model="comment" class="textarea" :disabled="reviewed || submitting" placeholder="补充阶段结论、风险或下一阶段重点…"/>

            <div class="review-note"><AlertTriangle :size="14"/><span>AI 只能生成建议，最终流转由授权 HR 或用人经理确认。</span></div>

            <button class="btn primary full" :disabled="reviewed || submitting" @click="publish">
              <Send :size="15"/>{{ submitting ? '提交中…' : '确认并发布评估' }}
            </button>
            <button class="btn full" :disabled="reviewed || submitting || !scoresChanged" @click="adjust">
              <Sparkles :size="15"/>调整评分后通过
            </button>
            <button class="btn full" :disabled="reviewed || submitting" @click="reject">
              <RotateCcw :size="15"/>驳回淘汰
            </button>
          </section>

          <section v-if="showOfferAction" class="card next-card offer-card">
            <b>录用流程</b>
            <p>终面已通过，可生成本场次的录用意向书草稿，并前往 Offer 管理补充薪资与入职信息。</p>
            <button class="btn primary full" :disabled="offerTriggering || offerCreated" @click="createOfferDraft">
              {{ offerCreated ? '已生成草稿' : (offerTriggering ? '生成中…' : '生成录用意向书') }}
            </button>
            <button class="btn full" @click="goOffer">前往 Offer 管理</button>
          </section>

          <section class="card next-card">
            <b>发布后动作</b>
            <p>通过：确认本轮评估，终面后前往 Offer 管理发起录用流程；驳回：候选人归档人才库并发送感谢信。</p>
          </section>
        </aside>
      </div>
    </template>

    <ToastMessage :message="toast"/>
  </div>
</template>

<style scoped>
.evaluation-page{padding-bottom:28px}.back{border:0;background:transparent;color:#6f7f99;display:flex;align-items:center;gap:5px;font-size:11px;padding:0;margin-bottom:9px}.page-heading{align-items:center}.page-heading>span{margin-left:auto}.evaluation-grid{display:grid;grid-template-columns:minmax(650px,1fr) 330px;gap:15px}.evaluation-grid>main,.evaluation-grid>aside{display:flex;flex-direction:column;gap:15px}.score-card,.evidence-card,.decision-card,.next-card{padding:19px}.state-card{padding:34px;text-align:center;color:#64748b;font-size:12px}.state-card.empty{display:flex;flex-direction:column;align-items:center;gap:8px}.state-card.empty b{font-size:14px;color:#334155}.state-card.empty p{font-size:10px;color:#8291a5;line-height:1.6}.state-card.empty .btn{margin-top:6px}.score-overview{display:flex;justify-content:space-between;align-items:center;background:linear-gradient(135deg,#edf4ff,#f9fbff);border-radius:11px;padding:16px}.eyebrow{display:flex;align-items:center;gap:5px;color:#2563eb;font-size:10px;font-weight:700}.score-overview strong{display:block;font-size:36px;color:#2057d8;margin-top:7px}.score-overview strong small{font-size:11px;color:#7890b2}.score-overview p{font-size:9px;color:#7d8da5;margin-top:3px}.ring{width:66px;height:66px;border:7px solid #c9ddff;border-top-color:#2563eb;border-right-color:#2563eb;border-radius:50%;display:grid;place-items:center;color:#2563eb;font-size:15px}.score-bars{margin-top:18px}.score-bars>div{display:grid;grid-template-columns:100px 54px 1fr;gap:8px;align-items:center;margin:12px 0;font-size:10px;color:#657791}.score-bars b{text-align:right;color:#263d62}.score-input{width:50px;height:26px;padding:0 4px;border:1px solid #dbe4ef;border-radius:6px;text-align:center;font-size:10px;color:#263d62;background:#fff}.score-input:focus{outline:none;border-color:#8db4fa;box-shadow:0 0 0 2px #e8f0ff}.score-bars i{height:7px;border-radius:5px;background:#e2e8f1}.score-bars u{display:block;height:100%;border-radius:inherit;background:linear-gradient(90deg,#3477f5,#06b6d4)}.dim-empty{font-size:10px;color:#8291a5;margin-top:14px}.evidence-card>.section-title svg{color:#2563eb}.summary-text{font-size:10px;line-height:1.7;color:#5f7089;white-space:pre-line;margin-top:8px}.detail-block{padding-top:12px;margin-top:12px;border-top:1px solid #e8edf4}.detail-block b{font-size:11px;color:#334155}.decision-card label{display:block;font-size:10px;color:#63758f;margin:16px 0 7px}.decision-options{display:grid;grid-template-columns:1fr 1fr;gap:7px}.decision-options button{height:34px;border:1px solid #dbe4ef;background:#fff;border-radius:7px;color:#657892;font-size:10px}.decision-options button.active{color:#2563eb;border-color:#8db4fa;background:#edf4ff;font-weight:700}.decision-options button:disabled{cursor:not-allowed;opacity:.6}.textarea{min-height:90px;resize:vertical}.textarea:disabled{background:#f7f9fc;color:#7b8ba3}.review-note{display:flex;gap:6px;align-items:flex-start;padding:9px;background:#fff5e6;border-radius:8px;color:#a96b18;font-size:9px;line-height:1.45;margin:12px 0}.green{color:#10b981}.full{width:100%;margin-top:7px}.full:disabled{cursor:not-allowed;opacity:.6}.next-card{font-size:10px}.next-card p{font-size:9px;color:#8291a5;line-height:1.5;margin-top:6px}.reviewed-banner{padding:10px 11px;margin-top:14px;border-radius:8px;background:#f0fdf6;border:1px solid #cbeee0}.reviewed-banner b{font-size:11px;color:#07865e}.reviewed-banner p{font-size:9px;color:#4b7f6c;line-height:1.55;margin-top:4px}.cascade-box{padding:10px 11px;margin-top:10px;border-radius:8px;background:#eef4ff;border:1px solid #d3e2ff}.cascade-box b{font-size:11px;color:#2057d8}.cascade-box p{font-size:9px;color:#5470a3;line-height:1.55;margin-top:4px}.result-hint{font-size:9px;color:#8291a5;line-height:1.5;margin-top:6px}.result-types{margin-top:0}.offer-card .full+.full{margin-top:6px}
</style>
