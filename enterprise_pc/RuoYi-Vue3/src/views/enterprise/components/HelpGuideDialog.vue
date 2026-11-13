<script setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'

const props = defineProps({ modelValue: Boolean })
const emit = defineEmits(['update:modelValue'])
const router = useRouter()

const keyword = ref('')
const activeId = ref('dashboard')

// 指南内容：覆盖企业端全部现有功能，keywords 用于搜索
const MODULES = [
  {
    id: 'dashboard', group: '入门', title: '招聘总览', route: '/enterprise/dashboard',
    keywords: '首页 指标 漏斗 待办 建议',
    summary: '登录后的默认首页，汇总招聘进展与今日待办。',
    steps: [
      '顶部指标卡展示在招岗位、简历总量、待处理面试、已完成面试数量。',
      '招聘漏斗按「新入库 → 评分通过 → 面试中 → 已录用」查看各阶段人数。',
      '「待办事项」区块定时刷新，展示待审批、待安排、待评估等需要处理的事项。',
      '右上角「快速发布岗位」可直接进入岗位新建流程。',
      '「AI 建议」根据当前招聘数据给出可执行提示，仅作参考，不自动改数据。'
    ],
    tips: ['点击漏斗任一阶段可跳转对应列表查看明细。', '指标口径按当前登录账号所属企业统计。']
  },
  {
    id: 'jobs', group: '招聘', title: '岗位管理', route: '/enterprise/jobs',
    keywords: '岗位 发布 编辑 复制 JD 解析 流程 配置',
    summary: '岗位的新建、编辑、复制、上下架与招聘流程配置。',
    steps: [
      '点击「发布新岗位」填写标题、薪资、城市、经验、学历、技能与职责后提交。',
      '发布弹窗内可粘贴 JD 文本，点击「AI 智能解析 JD」自动填充技能、职责与要求。',
      '列表操作可切换岗位状态（上线/下线）、编辑、复制；复制会生成「（副本）」草稿，技能同步复制。',
      '岗位详情页可查看岗位画像与投递情况。',
      '「招聘流程配置」按阶段设置轮次与面试方式，保存时版本号递增，历史版本保留。'
    ],
    tips: ['仅草稿岗位可删除，删除会先清理技能关联。', '编辑不会改变岗位当前状态。', 'AI 解析结果需人工确认后再保存。']
  },
  {
    id: 'jobs-import', group: '招聘', title: '岗位导入与草稿', route: '/enterprise/jobs/import',
    keywords: '导入 草稿 文件 批量',
    summary: '通过文件批量导入岗位，统一在草稿箱中完善后发布。',
    steps: [
      '进入「岗位导入与草稿」，上传岗位文件后系统逐条解析并生成草稿。',
      '解析结果逐条展示成功或失败原因，失败项可单独重试。',
      '在草稿箱中打开草稿补充薪资、部门等信息后发布。',
      '草稿可批量删除，删除前会先清理技能关联，避免外键冲突。'
    ],
    tips: ['导入不会直接上线岗位，必须人工核对后发布。', '文件格式与字段要求以页面提示为准。']
  },
  {
    id: 'candidates', group: '招聘', title: '候选人管理', route: '/enterprise/candidates',
    keywords: '候选人 投递 批量 状态 标签 聊天',
    summary: '按投递维度管理候选人，支持批量流转、批量打标签与即时沟通。',
    steps: [
      '列表按岗位、状态筛选，展示候选人、岗位、阶段与最近动态。',
      '勾选候选人后可批量更新投递状态（含终止原因）或批量加标签；未勾选时批量栏自动隐藏。',
      '点击「聊天」跳转消息中心并自动建立与该候选人的会话，未绑定账号的候选人会给出提示。',
      '点击候选人可查看投递详情：简历快照、评分记录、面试记录。',
      '「候选人流程」页聚合基本信息、完整简历与历史面试，可直接发起下一阶段排期。'
    ],
    tips: ['状态 3（已淘汰）、4（已录用）为终态，不能再向前流转。', '所有状态变更都会写入状态变更日志，可追溯。']
  },
  {
    id: 'screening', group: '招聘', title: 'AI 评分与复核', route: '/enterprise/resume-screening',
    keywords: '评分 报告 复核 人工 结论',
    summary: '对投递简历发起 AI 评分并查看评分报告，支持人工复核。',
    steps: [
      '在投递详情中选择简历，点击发起评分；系统异步生成评分结果。',
      '「AI 评分详情」展示维度得分、优势、风险与推荐结论。',
      '可人工调整分数并填写评语，人工评分优先于 AI 结果展示。',
      '评分结论可作为进入面试环节的依据，不通过则按淘汰处理。'
    ],
    tips: ['评分任务为异步执行，结果未生成时可稍后刷新。', '同一投递重复发起评分会复用已有结果，避免重复计费。']
  },
  {
    id: 'talent', group: '招聘', title: '人才库', route: '/enterprise/talent',
    keywords: '人才 筛选 邀约 简历 PDF',
    summary: '沉淀候选人简历，支持筛选、查看与发起面试邀约。',
    steps: [
      '按投递岗位与流程状态筛选人才，选择条件后立即查询。',
      '点击人才查看简历详情与原件 PDF。',
      '发起邀约时选择面试官、阶段与时间，创建预约并自动回写候选人状态为「面试中」。',
      '无合适面试官或时间冲突时，系统会给出明确提示而不写入脏数据。'
    ],
    tips: ['面试官下拉仅展示本企业具备面试官角色的成员。', '发起邀约前请确认岗位与候选人归属同一企业。']
  },
  {
    id: 'interviews', group: '面试', title: '面试安排中心', route: '/enterprise/interviews',
    keywords: '面试 日历 改期 拖拽 空闲 提醒',
    summary: '以周视图管理面试安排，支持拖拽改期、空闲时段与提醒。',
    steps: [
      '日历展示本周场次，左侧「已排面试」列出本周全部面试与等待安排。',
      '拖拽面试块到新时段后仅标记为待调整，必须点击「确认调整」才批量落库。',
      '「调整」弹窗可修改时间、时长并通知面试官；「提醒」向候选人发送面试提醒。',
      '「设置我的空闲时间」按周保存可预约时段，刷新后仍生效。',
      '已结束场次可进入「面试评估」录入评价并触发后续流转。'
    ],
    tips: ['同一时段日历只显示最早一场，其余进入等待安排列表。', '拖拽后未确认离开页面，改动不会生效。']
  },
  {
    id: 'reschedule', group: '面试', title: '改期审批', route: '/enterprise/interviews/reschedule-review',
    keywords: '改期 审批 申请 驳回 候选人',
    summary: '处理候选人在求职端提交的面试改期申请。',
    steps: [
      '候选人提交申请后，侧边栏「面试与笔试」出现红点，「改期审批」显示待处理数量。',
      '列表按待审批/已通过/已驳回/全部筛选，展示原时间、申请时间与理由。',
      '点击「通过」按新时段改期，并通知候选人与面试官；点击「驳回」必须填写原因。',
      '「查看」展示申请详情、审批人与审批时间。'
    ],
    tips: [
      '仅未开始且未取消的面试可审批通过；原安排已变化时需驳回后让候选人重新申请。',
      '不能审批本人提交的申请；重复审批同一结果会幂等返回，不会重复改期。',
      'HR 在面试安排中心直接「调整」不受该审批流程限制。'
    ]
  },
  {
    id: 'exam', group: '面试', title: '笔试管理', route: '/enterprise/exam',
    keywords: '笔试 题库 试卷 安排 通知 成绩',
    summary: '维护题库与试卷，安排考试并在消息中心发送笔试链接。',
    steps: [
      '在题库中新增/编辑题目，支持客观题与主观题。',
      '组卷时从题库抽题并设置分值、时长与及格线。',
      '创建考试安排，设置有效时间窗口与通知配置。',
      '在消息中心选择试卷发送笔试链接；无有效安排时会自动创建 7 天有效期的新安排。',
      '考试结束后在笔试管理中查看成绩并批阅主观题。'
    ],
    tips: ['候选人需先完成双机位设备检测才能进入笔试。', '笔试链接为绝对路径，需正确配置候选人端地址。']
  },
  {
    id: 'proctor', group: '面试', title: '监考监控', route: '/enterprise/exam/proctor',
    keywords: '监考 双机位 画面 考试中',
    summary: '实时监控进行中的在线笔试。',
    steps: [
      '列表仅展示进行中的考试，每行显示候选人、试卷与开始时间。',
      '点击「进入监考」打开独立监考页，查看考试详情与双机位画面。',
      '发现异常可在监考页记录处理结果。'
    ],
    tips: ['主副机位画面延迟属正常现象，以实际考试状态为准。']
  },
  {
    id: 'survey', group: '面试', title: '满意度调研', route: '/enterprise/survey',
    keywords: '问卷 调研 模板 结果 统计',
    summary: '配置满意度问卷模板并查看回收结果。',
    steps: [
      '问卷分平台通用模板与企业自有模板，可按类别筛选。',
      '新建模板时设置触发场景（如投递简历后）、题目与选项。',
      '模板可启用/停用；触发场景仅作为标签，不会自动发送。',
      '「结果」页查看回收份数、各题分布与反馈明细。'
    ],
    tips: ['修改模板不影响已回收的历史结果。']
  },
  {
    id: 'offer', group: '录用', title: 'Offer 管理', route: '/enterprise/offer',
    keywords: 'offer 审批 通过 拒绝 发送 邮件 撤回',
    summary: '创建、审批、发送与撤回录用意向书。',
    steps: [
      '面试终面通过后可一键生成 Offer 草稿，也可在 Offer 管理手动创建。',
      '草稿提交审批后按企业审批配置生成节点，审批人依次通过或拒绝。',
      '全部节点通过后可发送 Offer，系统按邮件配置向候选人发送通知。',
      '已发送的 Offer 支持撤回，必须填写撤回原因，候选人会收到站内消息。'
    ],
    tips: ['仅草稿状态可提交审批，仅已发送状态可撤回。', '审批/撤回均按企业隔离，越权访问会返回业务错误。']
  },
  {
    id: 'conference', group: '录用', title: '视频面试与录制', route: '/enterprise/conference/active',
    keywords: '视频 会议 录制 回放 协同 接管',
    summary: '进行中的视频面试与录制回放管理。',
    steps: [
      '「正在进行的面试」展示当前场次，点击进入协同面试间。',
      '进入会议前完成摄像头、麦克风、扬声器与网络四项设备检测。',
      '会议中可发起/结束接管、共享屏幕、查看 AI 实时建议与字幕。',
      '录制由服务端执行，需至少一位真实参与者进入房间才会生成文件。',
      '「录制回放」按录制开始时间筛选，可播放、下载与删除录制。'
    ],
    tips: ['面试链接必须为完整绝对路径，发送前请确认候选人端地址配置正确。', '录制显示「处理中」时需等待服务端回填真实状态。']
  },
  {
    id: 'messages', group: '协作', title: '消息中心', route: '/enterprise/messages',
    keywords: '聊天 消息 图片 文件 岗位卡片 邀约 快捷回复',
    summary: '与候选人及面试官沟通，发送面试邀约、笔试链接与岗位卡片。',
    steps: [
      '左侧会话列表按未读排序，支持搜索候选人。',
      '支持发送文本、图片与文件；图片上传后按图片气泡展示。',
      '「发送面试链接」选择投递岗位与面试阶段，系统按阶段自动填充会议设置并可手动修改。',
      '「发送笔试」选择试卷后生成包含绝对路径的笔试链接。',
      '可使用快捷回复与 AI 建议提高回复效率。'
    ],
    tips: ['面试邀约创建后会生成新场次与随机 roomToken，不复用旧链接。', '重复发起面试会复用未结束场次，避免同一候选人产生多个活跃会议。']
  },
  {
    id: 'assistant', group: '协作', title: 'AI 助手', route: '/enterprise/assistant',
    keywords: 'AI 助手 对话 工具 任务',
    summary: '通过对话完成查询与业务操作，结果可追溯。',
    steps: [
      '点击右下角悬浮球展开助手面板，新建会话后输入问题。',
      '助手会按需调用受控工具（如查询岗位、候选人、面试安排），调用过程以工具标签展示。',
      '任务中断后重新进入会话可恢复执行进度。'
    ],
    tips: ['助手不会绕过权限直接改数据，涉及写操作需你在界面确认。']
  },
  {
    id: 'settings', group: '系统', title: '系统设置', route: '/enterprise/settings',
    keywords: '公司 部门 成员 通知模板 数据 导出 备份 清理',
    summary: '维护企业基础信息、组织架构、成员权限与数据管理。',
    steps: [
      '「公司信息」维护企业名称、Logo、邮箱等，企业邮箱用于 Offer 邮件发件。',
      '「部门管理」维护部门树，收起后仍可通过箭头展开。',
      '「成员管理」邀请成员并分配角色（企业管理员/招聘 HR/面试官）。',
      '「通知模板」维护站内信与邮件模板变量。',
      '「数据管理」支持简历导出、数据备份与历史数据清理，操作前请确认影响范围。'
    ],
    tips: ['删除成员会清理其会话与令牌，操作不可撤销。', '数据清理仅删除本企业数据，不会影响其他企业。']
  },
  {
    id: 'profile', group: '系统', title: '个人中心', route: '/enterprise/profile',
    keywords: '个人 资料 密码 偏好 通知',
    summary: '维护个人资料、登录安全与消息偏好。',
    steps: [
      '修改头像、姓名与联系方式，保存后同步到面试与消息展示。',
      '修改密码时会保留当前会话，其他端会话自动失效。',
      '设置消息通知偏好，控制站内提醒范围。'
    ],
    tips: ['忘记密码请联系企业管理员重置，重置后所有端需重新登录。']
  },
  {
    id: 'faq', group: '帮助', title: '常见问题', route: '',
    keywords: '问题 FAQ 权限 菜单 空白 登录 过期',
    summary: '使用过程中最常见的问题与处理方式。',
    steps: [
      '看不到某个菜单：菜单按角色权限展示，请联系企业管理员确认角色（企业管理员/招聘 HR/面试官）。',
      '登录提示状态已过期：刷新令牌失效，需要重新登录；重新登录后会自动回到企业端首页。',
      '页面数据为空：先确认筛选条件，再刷新；接口无数据时页面展示空态而非演示数据。',
      '改期审批与面试安排的「调整」有何区别：前者处理候选人申请并需审批，后者是 HR 主动改期，立即生效。',
      '录制列表没有新增记录：需至少一位参与者进入会议房间，服务端才会生成录制文件。',
      'AI 评分结果一直未生成：评分为异步任务，可稍后刷新；多次失败请联系管理员查看模型服务。',
      '发送的面试链接无法点击：确认部署时已配置候选人端完整地址，链接必须是 http/https 绝对路径。',
      '页面局部显示异常：先 Ctrl+F5 强制刷新；仍异常时截图并联系管理员。'
    ],
    tips: ['遇到无法自行解决的问题，请提供页面名称、操作步骤与截图，便于快速定位。']
  }
]

const filtered = computed(() => {
  const k = keyword.value.trim().toLowerCase()
  if (!k) return MODULES
  return MODULES.filter(m => (m.title + m.summary + m.keywords).toLowerCase().includes(k))
})

const active = computed(() => MODULES.find(m => m.id === activeId.value) || MODULES[0])

const visible = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v)
})

function pick(id) {
  activeId.value = id
}

function go() {
  if (!active.value.route) return
  visible.value = false
  router.push(active.value.route)
}
</script>

<template>
  <el-dialog v-model="visible" width="900px" class="guide-dialog" :close-on-click-modal="true" append-to-body>
    <template #header>
      <div class="guide-head">
        <div>
          <h3>企业端使用指南</h3>
          <p>按左侧模块查看操作步骤，或在右上角搜索关键词</p>
        </div>
        <input v-model="keyword" class="guide-search" placeholder="搜索功能，如：改期、Offer、录制" />
      </div>
    </template>

    <div class="guide-body">
      <aside class="guide-nav">
        <template v-for="group in ['入门', '招聘', '面试', '录用', '协作', '系统', '帮助']" :key="group">
          <div v-if="filtered.some(m => m.group === group)" class="guide-group">{{ group }}</div>
          <button
            v-for="m in filtered.filter(x => x.group === group)"
            :key="m.id"
            class="guide-item"
            :class="{ active: activeId === m.id }"
            @click="pick(m.id)"
          >{{ m.title }}</button>
        </template>
        <div v-if="!filtered.length" class="guide-empty">没有匹配的功能，换个关键词试试</div>
      </aside>

      <section class="guide-main">
        <h2>{{ active.title }}</h2>
        <p class="summary">{{ active.summary }}</p>
        <ol class="steps">
          <li v-for="(s, i) in active.steps" :key="i">{{ s }}</li>
        </ol>
        <div v-if="active.tips && active.tips.length" class="tips">
          <b>注意事项</b>
          <p v-for="(t, i) in active.tips" :key="i">{{ t }}</p>
        </div>
        <div class="guide-actions">
          <button v-if="active.route" class="btn sm primary" @click="go">前往该功能</button>
          <button class="btn sm" @click="visible = false">关闭</button>
        </div>
      </section>
    </div>
  </el-dialog>
</template>

<style scoped>
.guide-head { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; }
.guide-head h3 { font-size: 18px; }
.guide-head p { margin-top: 5px; color: var(--muted); font-size: 12px; }
.guide-search { width: 260px; height: 36px; padding: 0 12px; border: 1px solid #dce4ee; border-radius: 9px; outline: none; font-size: 13px; }
.guide-search:focus { border-color: var(--primary); box-shadow: 0 0 0 3px rgba(37,99,235,.09); }
.guide-body { display: grid; grid-template-columns: 190px 1fr; gap: 20px; height: 480px; margin-top: 6px; }
.guide-nav { border-right: 1px solid var(--line); padding-right: 14px; overflow-y: auto; }
.guide-group { margin: 10px 0 6px; font-size: 11px; color: var(--subtle); letter-spacing: .5px; }
.guide-group:first-child { margin-top: 0; }
.guide-item { display: block; width: 100%; text-align: left; border: 0; background: transparent; color: #4a5a76; font-size: 13px; padding: 8px 10px; border-radius: 8px; }
.guide-item:hover { background: #f2f6fc; }
.guide-item.active { background: var(--primary-soft); color: var(--primary); font-weight: 600; }
.guide-empty { color: var(--subtle); font-size: 12px; padding: 12px 8px; }
.guide-main { overflow-y: auto; padding-right: 6px; }
.guide-main h2 { font-size: 18px; }
.summary { margin: 8px 0 14px; color: var(--muted); font-size: 13px; line-height: 1.7; }
.steps { margin: 0; padding-left: 20px; display: grid; gap: 9px; font-size: 13px; line-height: 1.75; color: #37455f; }
.tips { margin-top: 16px; padding: 12px 14px; border-radius: 10px; background: #fff8ec; border: 1px solid #fde4bb; }
.tips b { font-size: 12px; color: #b45309; }
.tips p { margin-top: 6px; font-size: 12px; line-height: 1.7; color: #7c5a1e; }
.guide-actions { display: flex; gap: 10px; margin-top: 18px; }
</style>
