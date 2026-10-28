<template>
  <div class="app-shell">
    <AgentTopbar active="jobs" />
    <main class="main-content">
      <section class="page-header">
        <div>
          <p class="eyebrow">ROLE DISCOVERY</p>
          <h1>岗位浏览</h1>
          <p class="page-intro">从真实招聘岗位中筛选机会，查看详情后选择简历完成投递。</p>
        </div>
      </section>

      <section class="search-panel" aria-label="岗位搜索和筛选">
        <form class="search-row" @submit.prevent="loadJobs">
          <label class="search-box" for="jobSearch">
            <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.8" /><path d="m16 16 4.3 4.3" /></svg>
            <input id="jobSearch" v-model.trim="keyword" type="search" placeholder="搜索岗位名称、公司或技能关键词" autocomplete="off" />
            <button v-if="keyword" class="clear-search" type="button" aria-label="清除搜索" @click="keyword = ''; loadJobs()">×</button>
          </label>
          <button class="search-submit" type="submit">
            <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.8" /><path d="m16 16 4.3 4.3" /></svg>
            搜索
          </button>
        </form>

        <div class="filter-strip">
          <button class="filter-trigger city-trigger" type="button" :class="{ active: filters.city }" @click="togglePanel('city')">
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>
            <span>{{ filters.city || '工作城市' }}</span><i />
          </button>
          <button class="filter-trigger" type="button" :class="{ active: filters.positionLabel }" @click="togglePanel('position')">
            <span>{{ filters.positionLabel || '职位类型' }}</span><i />
          </button>
          <button class="filter-trigger" type="button" :class="{ active: filters.employmentType }" @click="togglePanel('employment')">
            <span>{{ employmentLabel || '求职类型' }}</span><i />
          </button>
          <button class="filter-trigger" type="button" :class="{ active: filters.salaryRange }" @click="togglePanel('salary')">
            <span>{{ salaryLabel }}</span><i />
          </button>
          <button class="filter-trigger" type="button" :class="{ active: filters.experienceMin }" @click="togglePanel('experience')">
            <span>{{ filters.experienceMin || '工作经验' }}</span><i />
          </button>
          <button class="filter-trigger" type="button" :class="{ active: filters.education }" @click="togglePanel('education')">
            <span>{{ educationLabel }}</span><i />
          </button>
          <button class="filter-trigger" type="button" :class="{ active: filters.industry }" @click="togglePanel('industry')">
            <span>{{ filters.industry || '公司行业' }}</span><i />
          </button>
          <button class="filter-trigger" type="button" :class="{ active: filters.companySize }" @click="togglePanel('companySize')">
            <span>{{ filters.companySize || '公司规模' }}</span><i />
          </button>
        </div>

        <div v-if="activePanel === 'city'" class="filter-popover city-popover">
          <button class="option-item" :class="{ selected: !filters.city }" type="button" @click="selectSimpleFilter('city', '')">不限城市</button>
          <button v-for="city in displayCityOptions" :key="city" class="option-item" :class="{ selected: filters.city === city }" type="button" @click="selectSimpleFilter('city', city)">{{ city }}</button>
        </div>

        <div v-if="activePanel === 'employment'" class="filter-popover">
          <button class="option-item" :class="{ selected: !filters.employmentType }" type="button" @click="selectSimpleFilter('employmentType', '')">不限类型</button>
          <button v-for="type in employmentTypeOptions" :key="type.value" class="option-item" :class="{ selected: filters.employmentType === type.value }" type="button" @click="selectSimpleFilter('employmentType', type.value)">{{ type.label }}</button>
        </div>

        <div v-if="activePanel === 'salary'" class="filter-popover">
          <button v-for="option in salaryOptions" :key="option.value" class="option-item" :class="{ selected: filters.salaryRange === option.value }" type="button" @click="selectSalary(option)">{{ option.label }}</button>
        </div>

        <div v-if="activePanel === 'experience'" class="filter-popover">
          <button class="option-item" :class="{ selected: !filters.experienceMin }" type="button" @click="selectSimpleFilter('experienceMin', '')">经验不限</button>
          <button v-for="experience in experienceOptions" :key="experience" class="option-item" :class="{ selected: filters.experienceMin === experience }" type="button" @click="selectSimpleFilter('experienceMin', experience)">{{ experience }}</button>
        </div>

        <div v-if="activePanel === 'education'" class="filter-popover">
          <button class="option-item" :class="{ selected: !filters.education }" type="button" @click="selectSimpleFilter('education', '')">学历不限</button>
          <button v-for="education in educationOptions" :key="education.value" class="option-item" :class="{ selected: String(filters.education) === education.value }" type="button" @click="selectSimpleFilter('education', education.value)">{{ education.label }}</button>
        </div>

        <div v-if="activePanel === 'companySize'" class="filter-popover">
          <button class="option-item" :class="{ selected: !filters.companySize }" type="button" @click="selectSimpleFilter('companySize', '')">规模不限</button>
          <button v-for="size in filterOptions.companySizes" :key="size" class="option-item" :class="{ selected: filters.companySize === size }" type="button" @click="selectSimpleFilter('companySize', size)">{{ size }}</button>
          <span v-if="!filterOptions.companySizes.length" class="option-empty">暂无已发布岗位规模信息</span>
        </div>

        <div v-if="activePanel === 'position'" class="large-filter-panel position-panel">
          <div class="panel-heading">
            <div>
              <strong>选择职位类型</strong>
              <span>按岗位分类浏览真实发布岗位</span>
            </div>
            <label class="panel-search">
              <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.8" /><path d="m16 16 4.3 4.3" /></svg>
              <input v-model.trim="positionSearch" type="search" placeholder="请输入职位关键词" />
            </label>
          </div>
          <div class="position-body">
            <aside class="position-groups">
              <button v-for="group in positionGroups" :key="group.key" type="button" :class="{ selected: selectedPositionGroup === group.key }" @click="selectedPositionGroup = group.key">{{ group.label }}</button>
            </aside>
            <div class="position-options">
              <button class="position-option all-option" type="button" :class="{ selected: !filters.category && !filters.positionLabel }" @click="selectPosition({ label: '职位类型', value: '', source: 'all' })">全部职位</button>
              <template v-if="selectedPositionGroup === 'published'">
                <button v-for="categoryItem in filteredCategories" :key="categoryItem" class="position-option" type="button" :class="{ selected: filters.category === categoryItem }" @click="selectPosition({ label: categoryItem, value: categoryItem, source: 'category' })">
                  <span class="plus-icon">＋</span>{{ categoryItem }}
                </button>
                <span v-if="!filteredCategories.length" class="option-empty">暂无符合条件的已发布岗位分类</span>
              </template>
              <template v-else>
                <section v-for="section in filteredRoleSections" :key="section.title" class="position-section">
                  <h3>{{ section.title }}</h3>
                  <div class="position-section-list">
                    <button v-for="role in section.items" :key="role" class="position-option" type="button" @click="selectPosition({ label: role, value: role, source: 'keyword' })">
                      <span class="plus-icon">＋</span>{{ role }}
                    </button>
                  </div>
                </section>
                <span v-if="!filteredRoleSections.length" class="option-empty">没有匹配的职位关键词</span>
              </template>
            </div>
          </div>
        </div>

        <div v-if="activePanel === 'industry'" class="large-filter-panel industry-panel">
          <div class="panel-heading compact-heading">
            <div>
              <strong>选择公司行业</strong>
              <span>行业选项来自已发布岗位关联企业</span>
            </div>
          </div>
          <div class="industry-grid">
            <button class="industry-option all-industry" type="button" :class="{ selected: !filters.industry }" @click="selectSimpleFilter('industry', '')">不限行业</button>
            <section v-for="group in displayIndustryGroups" :key="group.title" class="industry-section">
              <h3>{{ group.title }}</h3>
              <button v-for="industry in group.items" :key="`${group.title}-${industry}`" class="industry-option" type="button" :class="{ selected: filters.industry === industry }" @click="selectSimpleFilter('industry', industry)">{{ industry }}</button>
            </section>
          </div>
        </div>

        <div class="search-result-row">
          <div class="result-count">共找到 <span>{{ visibleJobs.length }}</span> 个匹配岗位</div>
          <div class="result-hint">岗位数据来自企业端已发布岗位</div>
        </div>
        <div class="active-filters" v-if="activeFilterLabels.length">
          <span class="active-filter-label">已选条件</span>
          <button v-for="item in activeFilterLabels" :key="item.key" type="button" class="active-filter" @click="clearFilter(item.key)">{{ item.label }} ×</button>
          <button class="clear-all" type="button" @click="clearAllFilters">清空筛选</button>
        </div>
        <div class="hot-tags">
          <span class="hot-label">试试：</span>
          <button v-for="tag in hotTags" :key="tag" class="hot-tag" type="button" @click="keyword = tag; loadJobs()">{{ tag }}</button>
        </div>
      </section>

      <section>
        <div class="list-toolbar">
          <div>
            <h2 class="list-title">{{ savedOnly ? '收藏的岗位' : keyword || hasFilters ? '搜索结果' : '推荐岗位' }}</h2>
            <p class="list-subtitle">{{ errorMessage || '岗位数据来自招聘数据库，可直接进入详情和投递流程' }}</p>
          </div>
          <div class="list-controls">
            <label class="sort-control">
              <span>排序</span>
              <select v-model="sort" class="sort-select" aria-label="岗位排序" @change="loadJobs">
                <option value="match">匹配度优先</option>
                <option value="latest">最新发布</option>
                <option value="salary">薪资优先</option>
              </select>
            </label>
            <button class="saved-filter" type="button" :class="{ active: savedOnly }" :aria-pressed="savedOnly" @click="savedOnly = !savedOnly">
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg>
              <span>收藏</span><span class="saved-count">{{ savedJobs.size }}</span>
            </button>
            <div class="view-toggle">
              <button :class="{ active: !gridMode }" type="button" aria-label="列表视图" @click="gridMode = false"><svg viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h16" /></svg></button>
              <button :class="{ active: gridMode }" type="button" aria-label="网格视图" @click="gridMode = true"><svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" /><rect x="14" y="4" width="6" height="6" /><rect x="4" y="14" width="6" height="6" /><rect x="14" y="14" width="6" height="6" /></svg></button>
            </div>
          </div>
        </div>

        <div v-if="loading" class="empty-state visible"><strong>正在加载岗位</strong><span>正在读取最新岗位数据，请稍候。</span></div>
        <div v-else-if="visibleJobs.length" class="jobs-list" :class="{ 'grid-mode': gridMode }">
          <article v-for="job in visibleJobs" :key="job.id" class="job-card" @click="openJob(job.id)">
            <div class="job-main">
              <div class="job-card-head">
                <div class="company-logo">{{ companyMark(job.companyName) }}</div>
                <div class="job-heading">
                  <a class="job-title" :href="`/agent/job-detail?id=${job.id}`" @click.stop>{{ job.title }}</a>
                  <div class="job-company">{{ job.companyName }}</div>
                  <div class="job-location"><svg viewBox="0 0 24 24"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>{{ job.workCity || '地点不限' }}</div>
                </div>
              </div>
              <div class="tag-row">
                <span class="job-tag job-tag-primary">{{ job.statusText }}</span>
                <span v-if="job.category" class="job-tag">{{ job.category }}</span>
                <span v-if="job.skills?.[0]" class="job-tag">{{ job.skills[0] }}</span>
                <span class="job-tag">{{ job.educationText }}</span>
                <span v-if="job.experienceRequired" class="job-tag">{{ job.experienceRequired }}</span>
              </div>
              <div class="job-meta">
                <span v-if="job.responsibilities?.[0]"><svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h16" /></svg>{{ job.responsibilities[0] }}</span>
                <span v-if="job.skills?.length"><svg viewBox="0 0 24 24"><path d="M12 3v18M3 12h18" /></svg>{{ job.skills.slice(0, 3).join(' · ') }}</span>
              </div>
            </div>
            <div class="job-side">
              <div class="job-side-top"><div class="job-salary">{{ job.salaryText }}</div><div class="job-posted">{{ formatDate(job.publishedAt) }}</div></div>
              <div class="feedback" :class="{ progress: job.appliedFlag }">{{ job.appliedFlag ? '已投递，可查看进度' : '欢迎投递' }}</div>
              <div class="card-actions">
                <button class="save-button" type="button" :class="{ saved: isSaved(job.id) }" @click.stop="toggleSaved(job.id)">
                  <svg viewBox="0 0 24 24"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg><span>{{ isSaved(job.id) ? '已收藏' : '收藏岗位' }}</span>
                </button>
                <button class="contact-button" type="button" @click.stop="startConversation(job)">联系 HR</button>
                <button class="apply-button" type="button" @click.stop="applyJob(job)">{{ job.appliedFlag ? '查看投递' : '投递简历' }}</button>
              </div>
            </div>
          </article>
        </div>
        <div v-else class="empty-state visible">
          <strong>{{ errorMessage ? '岗位加载失败' : (savedOnly ? '还没有符合条件的收藏岗位' : '没有找到匹配岗位') }}</strong>
          <span>{{ errorMessage || '换一个岗位名称、公司或筛选条件试试。' }}</span>
          <button v-if="errorMessage" class="search-submit" type="button" @click="loadJobs">重新加载</button>
        </div>
      </section>
    </main>
  </div>
  <div class="toast" :class="{ show: toastVisible }" role="status"><span>✓</span><span>{{ toastMessage }}</span></div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { listJobFilterOptions, listJobs } from '@/api/agent/job'

const jobs = ref([])
const keyword = ref('')
const sort = ref('match')
const loading = ref(false)
const errorMessage = ref('')
const savedOnly = ref(false)
const gridMode = ref(false)
const activePanel = ref('')
const positionSearch = ref('')
const selectedPositionGroup = ref('all')
const savedJobs = ref(new Set(readSavedJobs()))
const toastVisible = ref(false)
const toastMessage = ref('')
const filters = reactive({
  city: '',
  category: '',
  positionLabel: '',
  employmentType: '',
  salaryRange: '',
  salaryMin: '',
  salaryMax: '',
  experienceMin: '',
  education: '',
  industry: '',
  companySize: ''
})
const filterOptions = reactive({
  categories: [],
  cities: [],
  employmentTypes: [],
  experiences: [],
  educations: [],
  industries: [],
  companySizes: []
})
let toastTimer

const hotTags = ['AI 产品经理', 'React', '大模型应用', '用户增长', '杭州']
const salaryOptions = [
  { value: 'under-5', label: '5K以下', min: '', max: 5000 },
  { value: '5-10', label: '5-10K', min: 5000, max: 10000 },
  { value: '10-15', label: '10-15K', min: 10000, max: 15000 },
  { value: '15-25', label: '15-25K', min: 15000, max: 25000 },
  { value: '25-50', label: '25-50K', min: 25000, max: 50000 },
  { value: 'over-50', label: '50K以上', min: 50000, max: '' }
]
const positionGroups = [
  { key: 'all', label: '全部职位' },
  { key: 'published', label: '已发布岗位' },
  { key: 'internet', label: '互联网/AI' },
  { key: 'hardware', label: '电子/电气/通信' },
  { key: 'product', label: '产品' },
  { key: 'operation', label: '客服/运营' },
  { key: 'market', label: '市场' },
  { key: 'sales', label: '销售' },
  { key: 'design', label: '设计' },
  { key: 'ecommerce', label: '电商' },
  { key: 'media', label: '传媒' },
  { key: 'live', label: '直播' },
  { key: 'education', label: '教育培训' },
  { key: 'hr', label: '人力/行政/法务' },
  { key: 'financeAudit', label: '财务/审计/税务' },
  { key: 'supply', label: '采购/贸易/物流' },
  { key: 'realEstate', label: '房地产/建筑' },
  { key: 'auto', label: '汽车' },
  { key: 'finance', label: '金融' },
  { key: 'service', label: '生活服务' },
  { key: 'manufacturing', label: '生产制造' },
  { key: 'worker', label: '技工/普工' },
  { key: 'medical', label: '医疗健康' },
  { key: 'hotel', label: '旅游/酒店' },
  { key: 'dining', label: '餐饮/生活服务' },
  { key: 'government', label: '政府/非营利组织' },
  { key: 'senior', label: '高级管理' },
  { key: 'trainee', label: '管培生/储备干部' },
  { key: 'other', label: '其他职位' }
]
const roleCatalog = {
  internet: [
    { title: '后端开发', items: ['Java', 'C++', 'PHP', 'Python', 'Golang', 'Node.js', 'C#/.NET', 'Ruby', 'Rust', '后端开发', '全栈工程师', '架构师', '高性能计算', '区块链工程师', 'GIS工程师', '其他后端开发'] },
    { title: '前端/移动开发', items: ['前端开发', 'Web前端', 'HTML5', 'JavaScript', 'TypeScript', 'Vue', 'React', 'Angular', '小程序开发', 'Android', 'iOS', '鸿蒙开发', '移动开发', 'Flutter', '移动App开发', 'SDK开发'] },
    { title: '人工智能/算法', items: ['算法工程师', '机器学习', '深度学习', 'NLP算法', 'CV算法', '语音算法', '推荐算法', '搜索算法', '广告算法', '大模型算法', 'AI训练师', 'AI产品经理', '数据标注', '其他算法职位'] },
    { title: '数据', items: ['数据分析师', '数据开发', '数据仓库', '数据挖掘', 'BI工程师', '数据治理', '数据库管理员', '数据架构师', '大数据工程师', '数据产品经理'] },
    { title: '测试/运维/支持', items: ['测试工程师', '自动化测试', '测试开发', '软件测试', '运维工程师', 'DevOps', 'SRE', '网络工程师', '系统工程师', '数据库工程师', '技术支持', '技术文档工程师', '安全工程师', '网络安全', '信息安全'] },
    { title: '项目管理/技术咨询', items: ['项目经理', '技术项目经理', '实施工程师', '实施顾问', '实施项目经理', '需求分析师', 'IT咨询顾问', '售前技术支持', '售后技术支持', '销售技术支持'] },
    { title: '高端技术职位', items: ['技术总监', '研发总监', 'CTO', '架构总监', '技术专家', '首席科学家', '技术合伙人'] }
  ],
  hardware: [
    { title: '电子/硬件研发', items: ['电子工程师', '硬件工程师', '嵌入式软件工程师', '嵌入式开发', 'FPGA开发', '单片机', '驱动开发工程师', 'PCB工程师', '电路设计', '电源工程师', '电池工程师', '电声工程师', '光学工程师', 'DSP开发', '射频工程师'] },
    { title: '芯片/半导体', items: ['集成电路IC设计', '数字IC设计', '模拟IC设计', '数字IC验证工程师', '模拟版图设计工程师', '芯片测试工程师', 'DFT工程师', '半导体工程师', '芯片工艺工程师', 'FAE', '封装工程师'] },
    { title: '通信/网络', items: ['通信技术工程师', '通信研发工程师', '通信项目经理', '通信项目专员', '数据通信工程师', '光网络工程师', '核心网工程师', '无线/天线工程师', '网络规划设计', '宽带装维', '通信标准化工程师'] },
    { title: '智能硬件/其他', items: ['智能硬件产品经理', '物联网工程师', '自动驾驶工程师', '机器人算法工程师', '电子维修技术员', '硬件项目经理', '硬件测试', '系统集成工程师'] }
  ],
  product: [
    { title: '产品经理', items: ['产品经理', '产品专员/助理', '高级产品经理', '产品总监', '产品负责人', 'B端产品经理', 'C端产品经理', '商业产品经理', '策略产品经理', '需求分析工程师'] },
    { title: '产品方向', items: ['数据产品经理', 'AI产品经理', '后台产品经理', '移动产品经理', '电商产品经理', '用户产品经理', '游戏产品经理', '金融产品经理', '硬件产品经理', '跨境电商产品开发', '化妆品产品经理'] },
    { title: '用户研究/产品设计', items: ['用户研究', '用户体验设计', '产品运营', '产品市场', '产品培训师', '产品助理'] }
  ],
  operation: [
    { title: '运营', items: ['运营专员', '产品运营', '用户运营', '内容运营', '活动运营', '社群运营', '新媒体运营', '短视频运营', '直播运营', '游戏运营', '社区运营', '增长运营', '策略运营', '商业化运营'] },
    { title: '搜索/市场增长', items: ['SEO', 'SEM', 'ASO', '投放运营', '用户增长', '数据运营', '私域运营', '海外运营', '平台运营', '互联网运营'] },
    { title: '客服/客户成功', items: ['客服专员', '在线客服', '电话客服', '售后客服', '客服主管', '客服经理', '客户成功', '客户关系', '呼叫中心客服', '售前客服'] }
  ],
  market: [
    { title: '市场营销', items: ['市场营销', '市场策划', '市场推广', '品牌营销', '品牌公关', '整合营销', '内容营销', '活动策划', '市场调研', '用户研究'] },
    { title: '广告/媒介/会展', items: ['广告创意', '广告文案', '媒介策划', '媒介投放', '广告优化师', '公关媒介', '会展活动策划', '会务会展', '商务公关'] },
    { title: '市场管理', items: ['市场经理', '市场总监', '品牌经理', '公关经理', '营销总监', '市场专员/助理'] }
  ],
  ecommerce: [
    { title: '电商运营', items: ['电商运营', '淘宝运营', '天猫运营', '京东运营', '拼多多运营', '跨境电商运营', '直播电商运营', '电商产品经理', '电商招商主管', '电商店长'] },
    { title: '电商业务', items: ['电商客服', '电商美工', '选品专员', '电商采购', '网店运营', '供应链运营', '商品运营', '平台招商'] },
    { title: '电商设计/直播', items: ['电商设计', '视觉设计', '直播选品', '直播投放', '直播中控', '场控', '带货主播'] }
  ],
  sales: [
    { title: '销售', items: ['销售专员', '销售顾问', '电话销售', '网络销售', '渠道销售', '大客户销售', '区域销售', '销售经理', '销售总监'] },
    { title: '市场/商务', items: ['市场营销', '市场策划', '品牌公关', '商务拓展', '商务经理', '广告销售', '媒介投放', '会展活动'] }
  ],
  design: [
    { title: '视觉/交互', items: ['UI设计师', 'UX设计师', '交互设计师', '视觉设计师', '平面设计师', '网页设计师', '品牌设计师', '用户体验设计师', '设计师助理'] },
    { title: '产品/工业设计', items: ['产品设计师', '工业设计', '结构设计师', '包装设计', '珠宝设计', '服装设计', '鞋类设计', '家具设计', '室内设计', '建筑设计'] },
    { title: '创意内容', items: ['3D设计师', '动画设计', '插画师', '原画师', '游戏特效', '游戏动作', '设计经理', '设计总监'] }
  ],
  dining: [
    { title: '餐饮服务', items: ['服务员', '收银员', '迎宾/接待', '传菜员', '餐饮学徒', '餐饮店长', '餐饮管理'] },
    { title: '餐饮后厨', items: ['厨师', '后厨', '配菜/打荷', '洗碗工', '面点师', '咖啡师', '调酒师'] }
  ],
  hotel: [
    { title: '酒店服务', items: ['酒店前台', '前厅经理', '客房服务', '酒店管理', '礼宾员', '预订专员', '收益管理'] },
    { title: '旅游服务', items: ['旅游顾问', '导游', '签证专员', '票务专员', '旅行社计调', '景区运营', '旅游产品经理'] }
  ],
  media: [
    { title: '传媒内容', items: ['文案策划', '文案编辑', '编辑', '记者', '编导', '摄影师', '剪辑师', '后期制作', '主播', '短视频编导', '内容审核', '自媒体运营'] },
    { title: '影视/动画', items: ['影视制作', '制片人', '导演/编导', '影视策划', '影视后期', '三维动画师', '分镜师', '艺人经纪', '影视发行'] },
    { title: '出版/广告', items: ['广告创意', '广告文案', '媒介策划', '媒介投放', '直播中控', '出版编辑', '校对', '发行专员'] }
  ],
  live: [
    { title: '直播岗位', items: ['主播', '带货主播', '娱乐主播', '直播运营', '直播策划', '直播中控', '场控', '直播助理'] },
    { title: '内容与增长', items: ['短视频运营', '短视频编导', '视频剪辑', '直播选品', '直播投放', '粉丝运营'] }
  ],
  education: [
    { title: '教师', items: ['教师', '英语教师', '数学教师', '语文教师', '物理教师', '化学教师', '生物教师', '历史教师', '地理教师', '政治教师', '高中教师', '初中教师', '小学教师', '职业技术教师'] },
    { title: '幼儿与素质教育', items: ['幼教', '早教老师', '保育员', '感统训练教师', '美术老师', '音乐老师', '书法老师', '体育老师', '舞蹈老师', '乐高老师', '机器人老师', '托管老师'] },
    { title: '教育行政/培训', items: ['教务管理', '校长/副校长', '班主任/辅导员', '教学管理', '课程顾问', '培训师', '教研员', '课程设计', '招生顾问', '教育产品经理', '留学顾问', '教育咨询师'] }
  ],
  realEstate: [
    { title: '房地产', items: ['房地产销售', '房产经纪人', '置业顾问', '房地产策划', '房地产评估', '招商主管', '物业管理'] },
    { title: '建筑工程', items: ['建筑设计', '结构设计', '土木/土建工程师', '工程管理', '施工员', '监理工程师', '造价工程师', '招投标专员', '装修装饰'] }
  ],
  auto: [
    { title: '汽车服务', items: ['汽车销售', '汽车维修', '汽车美容', '汽车钣金', '汽车喷漆', '4S店服务顾问', '汽车配件'] },
    { title: '汽车研发制造', items: ['汽车设计', '汽车电子工程师', '新能源研发', '电池工程师', '智能驾驶', '整车工程师'] }
  ],
  finance: [
    { title: '银行/证券/基金', items: ['银行', '银行客户经理', '信贷管理', '投资顾问', '证券/期货', '基金', '基金经理', '资产管理', '投行业务', '量化交易'] },
    { title: '保险/财富管理', items: ['保险', '保险经纪人', '保险顾问', '精算师', '财富管理', '私人银行', '理财顾问', '信托', '融资专员'] },
    { title: '互联网金融/风控', items: ['互联网金融', '金融产品经理', '风控', '反欺诈', '催收', '金融数据分析', '合规风控', '支付清算'] }
  ],
  hr: [
    { title: '人力行政', items: ['人力资源', '招聘', 'HRBP', '薪酬绩效', '培训', '员工关系', '行政专员', '行政经理', '前台'] },
    { title: '法务', items: ['法务专员', '律师', '合规', '知识产权', '合同管理'] }
  ],
  financeAudit: [
    { title: '财务/审计/税务', items: ['会计', '出纳', '财务主管', '财务经理', '审计', '税务', '成本会计', '结算', '风控合规'] }
  ],
  supply: [
    { title: '采购/贸易', items: ['采购专员', '采购经理', '采购工程师', '战略采购', '供应商管理', '外贸业务员', '外贸经理', '进出口贸易', '跟单员', '单证员', '报关员'] },
    { title: '供应链/物流', items: ['供应链专员', '供应链经理', '供应链产品经理', '计划专员', '物流专员', '物流经理', '运输调度', '仓储管理', '仓库管理员', '货运代理'] },
    { title: '配送/司机', items: ['调度员', '货运司机', '网约车司机', '配送员', '快递员', '搬运工', '押运员'] }
  ],
  service: [
    { title: '餐饮/旅游/生活服务', items: ['服务员', '厨师', '咖啡师', '店员', '收银员', '导游', '酒店前台', '美容师', '健身教练', '家政服务'] }
  ],
  manufacturing: [
    { title: '生产制造', items: ['生产经理', '生产计划', '质量管理', '质检员', '工艺工程师', '机械工程师', '电气工程师', '自动化工程师'] }
  ],
  worker: [
    { title: '技工/普工', items: ['普工', '操作工', '电工', '焊工', '钳工', '车工', '铣工', '叉车工', '维修工', '包装工'] }
  ],
  medical: [
    { title: '医疗临床', items: ['医生', '护士', '护理主任', '医师助理', '药剂师', '检验科医师', '影像科医师', '麻醉医师', '临床研究', '医学编辑'] },
    { title: '医药/医疗器械', items: ['医药代表', '医药销售', '医疗器械销售', '医疗器械研发', '药品研发', '生物制药', '临床项目经理', '注册专员', '医学专员'] },
    { title: '健康服务', items: ['健康管理师', '康复治疗师', '营养师', '心理咨询师', '宠物医生', '护理员', '医美咨询', '医疗运营'] }
  ],
  government: [
    { title: '政府/公共事业', items: ['公务员', '事业单位人员', '公共事务', '政府关系', '政策研究', '项目申报', '社区服务', '志愿者管理'] },
    { title: '非营利/科研', items: ['非营利组织', '基金会项目专员', '学术研究', '科研助理', '实验室研究员', '高校行政', '公共管理'] }
  ],
  senior: [
    { title: '企业管理', items: ['CEO/总裁/总经理', '副总裁/VP', '事业部负责人', '运营总监', '市场总监', '销售总监', '人力资源总监', '财务总监/CFO'] },
    { title: '职能管理', items: ['行政总监', '法务总监', '供应链总监', '采购总监', '项目总监', '区域负责人', '分公司负责人', '合伙人'] }
  ],
  trainee: [
    { title: '管培生', items: ['管理培训生', '运营管培生', '营销管培生', '产品管培生', '技术管培生', '供应链管培生', '财务管培生'] },
    { title: '储备干部/校招', items: ['储备干部', '储备店长', '应届生', '实习生', '校园大使', '校招职位'] }
  ],
  other: [
    { title: '其他职位', items: ['翻译', '法律顾问', '知识产权顾问', '猎头顾问', '招聘专员', '摄影师', '司机', '保安', '保洁', '宠物美容', '农艺师', '其他职位'] }
  ]
}
const defaultCityOptions = ['全国', '北京', '上海', '广州', '深圳', '杭州', '天津', '西安', '苏州', '武汉', '厦门', '长沙', '成都', '郑州', '重庆', '南京', '合肥', '青岛', '宁波', '东莞', '佛山', '无锡', '济南', '福州']
const experienceOptions = ['在校生', '应届生', '经验不限', '1年以内', '1-3年', '3-5年', '5-10年', '10年以上']
const defaultEmploymentTypes = [
  { value: '1', label: '全职' },
  { value: '3', label: '兼职' },
  { value: '2', label: '实习' }
]
const defaultEducationOptions = [
  { value: '初中及以下', label: '初中及以下' },
  { value: '中专/中技', label: '中专/中技' },
  { value: '高中', label: '高中' },
  { value: '大专', label: '大专' },
  { value: '本科', label: '本科' },
  { value: '硕士', label: '硕士' },
  { value: '博士', label: '博士' }
]
const industryCatalog = [
  { title: '互联网/AI', items: ['互联网', '互联网/科技', '电子商务', '计算机软件', '人工智能', 'SaaS/企业服务', '企业服务', '社交网络与媒体', '云计算', '在线教育', '计算机服务', '大数据', '数据服务', '广告营销', '物联网', '新零售', '游戏', '信息安全', '区块链', '互联网医疗'] },
  { title: '电子/通信/半导体', items: ['电子/半导体/集成电路', '半导体/芯片', '集成电路设计', '芯片制造', '电子/硬件开发', '通信/网络设备', '通信服务', '智能硬件/消费电子', '物联网设备', '运营商/增值服务', '计算机/通信/其他电子设备'] },
  { title: '汽车/出行/新能源', items: ['汽车生产', '汽车零部件', '新能源汽车', '智能汽车', '汽车经销商', '汽车后市场', '自动驾驶', '共享出行', '网约车/出租车', '能源/电池'] },
  { title: '服务业', items: ['餐饮', '美容', '美发', '酒店/民宿', '休闲/娱乐', '运动/健身', '保健/养生', '家政服务', '旅游/景区', '婚庆/摄影', '宠物服务', '回收/维修', '其他生活服务'] },
  { title: '消费品/批发/零售', items: ['批发/零售', '进出口贸易', '食品/饮料/烟酒', '服装/纺织', '鞋服箱包', '家具/家居', '家用电器', '日化', '母婴用品', '珠宝/饰品', '玩具/礼品', '商超/便利店', '奢侈品', '美妆/个护'] },
  { title: '制造业', items: ['机械设备/机电/重工', '自动化设备', '仪器仪表/工业自动化', '化学原料/化学制品', '化工', '印刷/包装/造纸', '新材料', '原材料及加工/模具', '铁路/船舶/航空/航天制造', '汽车生产', '汽车零部件', '家电生产', '工业机器人', '其他制造业'] },
  { title: '专业服务', items: ['咨询', '财务/审计/税务', '人力资源服务', '法律', '检测/认证/知识产权', '翻译', '广告/公关/会展', '猎头/招聘', '工程咨询', '企业管理咨询', '其他专业服务'] },
  { title: '制药/医疗/健康', items: ['医疗服务', '医美服务', '医疗器械', '生物制药', '医药批发/零售', '医疗健康', '互联网医疗', '医疗研发', '医学检验', '健康管理', '宠物医疗'] },
  { title: '能源/环保/农业', items: ['电力/热力/燃气/水利', '石油/石化', '矿产/地质', '采掘/冶炼', '新能源', '光伏/风电', '环保', '节能服务', '农林/牧/渔', '农业科技', '其他能源'] },
  { title: '金融', items: ['互联网金融', '银行', '投资/融资', '证券/期货', '基金', '保险', '租赁/拍卖/典当/担保', '信托', '财富管理', '支付/结算', '金融科技', '其他金融业'] },
  { title: '房地产/建筑', items: ['房地产开发', '房地产中介', '物业管理', '建筑设计', '工程施工', '工程咨询', '装饰装修', '园林景观', '城市规划', '建材家居'] },
  { title: '交通/物流', items: ['物流/仓储', '快递/配送', '货运代理', '交通运输', '航空/铁路/船舶', '港口/码头', '供应链服务', '网约车/出租车'] },
  { title: '教育/文化/传媒', items: ['教育培训', '学校/学术', '文化艺术', '影视/传媒', '体育', '出版/印刷', '广告营销', '网络直播', '数字内容', '博物馆/展览'] },
  { title: '政府/非营利组织/其他', items: ['政府/公共事业', '非营利组织', '学术/科研', '公共管理', '社会组织', '宗教/公益', '其他行业'] }
]
const employmentTypeOptions = computed(() => mergeOptionObjects(defaultEmploymentTypes, filterOptions.employmentTypes.map(value => {
  const labels = { 1: '全职', 2: '实习', 3: '兼职' }
  return { value: String(value), label: labels[value] || `类型 ${value}` }
})))
const educationOptions = computed(() => {
  const labels = { 1: '学历不限', 2: '大专', 3: '本科', 4: '硕士', 5: '博士' }
  return mergeOptionObjects(defaultEducationOptions, filterOptions.educations.map(value => ({ value: labels[value] || '学历不限', label: labels[value] || '学历不限' })))
})
const displayCityOptions = computed(() => uniqueValues([...defaultCityOptions, ...filterOptions.cities]))
const filteredCategories = computed(() => filterOptions.categories.filter(item => !positionSearch.value || item.toLowerCase().includes(positionSearch.value.toLowerCase())))
const filteredRoleSections = computed(() => roleSectionsForSelectedGroup().map(section => ({
  ...section,
  items: section.items.filter(item => !positionSearch.value || item.toLowerCase().includes(positionSearch.value.toLowerCase()))
})).filter(section => section.items.length))
const displayIndustryGroups = computed(() => {
  const catalogValues = new Set(industryCatalog.flatMap(group => group.items))
  const published = filterOptions.industries.filter(item => item && !catalogValues.has(item))
  return published.length ? [{ title: '已发布企业行业', items: published }, ...industryCatalog] : industryCatalog
})
const visibleJobs = computed(() => savedOnly.value ? jobs.value.filter(job => savedJobs.value.has(String(job.id))) : jobs.value)
const hasFilters = computed(() => Boolean(
  filters.city
  || filters.category
  || filters.positionLabel
  || filters.employmentType
  || filters.salaryRange
  || filters.experienceMin
  || filters.education
  || filters.industry
  || filters.companySize
))
const employmentLabel = computed(() => employmentTypeOptions.value.find(item => item.value === String(filters.employmentType))?.label || '')
const educationLabel = computed(() => educationOptions.value.find(item => item.value === String(filters.education))?.label || '学历要求')
const educationQueryValue = computed(() => {
  const values = { 初中及以下: 1, '中专/中技': 1, 高中: 1, 大专: 2, 本科: 3, 硕士: 4, 博士: 5, 学历不限: '' }
  return values[filters.education] || ''
})
const salaryLabel = computed(() => salaryOptions.find(item => item.value === filters.salaryRange)?.label || '薪资待遇')
const activeFilterLabels = computed(() => {
  const items = []
  if (filters.city) items.push({ key: 'city', label: filters.city })
  if (filters.positionLabel) items.push({ key: 'position', label: filters.positionLabel })
  if (employmentLabel.value) items.push({ key: 'employmentType', label: employmentLabel.value })
  if (filters.salaryRange) items.push({ key: 'salaryRange', label: salaryLabel.value })
  if (filters.experienceMin) items.push({ key: 'experienceMin', label: filters.experienceMin })
  if (filters.education) items.push({ key: 'education', label: educationLabel.value })
  if (filters.industry) items.push({ key: 'industry', label: filters.industry })
  if (filters.companySize) items.push({ key: 'companySize', label: filters.companySize })
  return items
})

function uniqueValues(values) {
  return [...new Set(values.filter(Boolean))]
}

function mergeOptionObjects(...groups) {
  const seen = new Set()
  return groups.flat().filter(item => {
    if (!item?.value || seen.has(item.value)) return false
    seen.add(item.value)
    return true
  })
}

function roleSectionsForSelectedGroup() {
  if (selectedPositionGroup.value === 'all') {
    return Object.values(roleCatalog).flat()
  }
  return roleCatalog[selectedPositionGroup.value] || []
}

async function loadJobs() {
  loading.value = true
  errorMessage.value = ''
  try {
    const response = await listJobs({
      keyword: keyword.value || undefined,
      category: filters.category || undefined,
      city: filters.city || undefined,
      employmentType: filters.employmentType || undefined,
      salaryMin: filters.salaryMin || undefined,
      salaryMax: filters.salaryMax || undefined,
      experienceMin: filters.experienceMin || undefined,
      education: educationQueryValue.value || undefined,
      industry: filters.industry || undefined,
      companySize: filters.companySize || undefined,
      sort: sort.value,
      page: 1,
      size: 50
    })
    jobs.value = response.data?.items || []
  } catch (error) {
    errorMessage.value = error?.message || '岗位数据暂时无法读取，请稍后重试'
  } finally {
    loading.value = false
  }
}

async function loadFilterOptions() {
  try {
    const response = await listJobFilterOptions()
    const data = response.data || {}
    Object.keys(filterOptions).forEach(key => {
      filterOptions[key] = Array.isArray(data[key]) ? data[key] : []
    })
  } catch {
    Object.keys(filterOptions).forEach(key => { filterOptions[key] = [] })
  }
}

function togglePanel(panel) {
  activePanel.value = activePanel.value === panel ? '' : panel
  if (panel === 'position') {
    positionSearch.value = ''
    selectedPositionGroup.value = filters.category ? 'published' : 'all'
  }
}

function selectSimpleFilter(key, value) {
  filters[key] = key === 'city' && value === '全国' ? '' : value
  activePanel.value = ''
  loadJobs()
}

function selectSalary(option) {
  filters.salaryRange = option.value
  filters.salaryMin = option.min
  filters.salaryMax = option.max
  activePanel.value = ''
  loadJobs()
}

function selectPosition(item) {
  filters.positionLabel = item.value ? item.label : ''
  filters.category = item.source === 'category' ? item.value : ''
  if (item.source === 'keyword') keyword.value = item.value
  if (item.source === 'all') {
    keyword.value = ''
    filters.category = ''
  }
  activePanel.value = ''
  loadJobs()
}

function clearFilter(key) {
  if (key === 'position') {
    filters.category = ''
    filters.positionLabel = ''
  } else if (key === 'salaryRange') {
    filters.salaryRange = ''
    filters.salaryMin = ''
    filters.salaryMax = ''
  } else {
    filters[key] = ''
  }
  loadJobs()
}

function clearAllFilters() {
  Object.assign(filters, {
    city: '', category: '', positionLabel: '', employmentType: '', salaryRange: '',
    salaryMin: '', salaryMax: '', experienceMin: '', education: '', industry: '', companySize: ''
  })
  keyword.value = ''
  activePanel.value = ''
  loadJobs()
}

function readSavedJobs() {
  try {
    const saved = JSON.parse(localStorage.getItem('zhipin-ai-saved-jobs') || '[]')
    return Array.isArray(saved) ? saved.map(String) : []
  } catch {
    return []
  }
}

function persistSavedJobs() {
  try {
    localStorage.setItem('zhipin-ai-saved-jobs', JSON.stringify([...savedJobs.value]))
  } catch {
    // 隐私模式下保留当前页面状态。
  }
}

function isSaved(id) {
  return savedJobs.value.has(String(id))
}

function toggleSaved(id) {
  const next = new Set(savedJobs.value)
  const key = String(id)
  if (next.has(key)) {
    next.delete(key)
    showToast('已取消收藏')
  } else {
    next.add(key)
    showToast('已收藏该岗位')
  }
  savedJobs.value = next
  persistSavedJobs()
}

function openJob(id) {
  window.__agentNavigate(`/agent/job-detail?id=${encodeURIComponent(id)}`)
}

function applyJob(job) {
  if (job.appliedFlag && job.applicationId) {
    window.__agentNavigate(`/agent/application-detail?id=${encodeURIComponent(job.applicationId)}`)
  } else {
    window.__agentNavigate(`/agent/resume-select?job=${encodeURIComponent(job.id)}`)
  }
}

function startConversation(job) {
  const publisherId = Number(job?.publisherId)
  if (!Number.isInteger(publisherId) || publisherId <= 0) {
    showToast('该岗位暂未配置 HR 联系人')
    return
  }
  const peerName = `${job.companyName || '企业'} HR`
  window.__agentNavigate(`/agent/messages?peerId=${encodeURIComponent(publisherId)}&peerName=${encodeURIComponent(peerName)}&jobId=${encodeURIComponent(job.id)}`)
}

function companyMark(name) {
  return (name || '企业').slice(0, 2)
}

function formatDate(value) {
  return value ? `发布于 ${String(value).slice(5, 10)}` : '最新发布'
}

function showToast(message) {
  toastMessage.value = message
  toastVisible.value = true
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => { toastVisible.value = false }, 2400)
}

function closePanelOnEscape(event) {
  if (event.key === 'Escape') activePanel.value = ''
}

onMounted(async () => {
  window.addEventListener('keydown', closePanelOnEscape)
  await loadFilterOptions()
  await loadJobs()
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', closePanelOnEscape)
  clearTimeout(toastTimer)
})
</script>

<style scoped>
:global(*){box-sizing:border-box}:global(body){margin:0;color:#172b4d;background:#f5f7fa;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif}.main-content{width:min(1240px,calc(100% - 48px));margin:0 auto;padding:34px 0 56px}.page-header{margin-bottom:22px}.eyebrow{margin:0 0 7px;color:#2b7fff;font-size:11px;font-weight:800;letter-spacing:1px}.page-header h1{margin:0;color:#1a3c6e;font-size:28px}.page-intro{margin:8px 0 0;color:#6b7a90;font-size:13px}.search-panel{position:relative;padding:18px 20px;border:1px solid #e6ebf2;border-radius:10px;background:#fff;box-shadow:0 5px 18px rgba(26,60,110,.045)}.search-row{display:flex;gap:10px}.search-box{position:relative;display:flex;align-items:center;flex:1;height:42px;border:1px solid #dce4ee;border-radius:8px;background:#fff}.search-box svg,.panel-search svg{width:18px;margin:0 11px;color:#96a3b5;stroke:currentColor;fill:none;stroke-width:1.8}.search-box input,.panel-search input{width:100%;height:100%;border:0;outline:0;color:#172b4d;background:transparent}.clear-search{width:28px;height:28px;margin-right:5px;border:0;border-radius:6px;color:#6b7a90;background:transparent;font-size:18px}.search-submit{display:inline-flex;align-items:center;justify-content:center;gap:6px;min-width:84px;height:42px;padding:0 14px;border:0;border-radius:7px;color:#fff;background:#2b7fff;font-size:12px;font-weight:800;cursor:pointer}.search-submit svg{width:16px;stroke:currentColor;fill:none;stroke-width:1.8}.filter-strip{display:flex;flex-wrap:wrap;gap:10px;margin-top:16px;padding:12px 0 2px;border-top:1px solid #f0f3f7}.filter-trigger{display:inline-flex;align-items:center;gap:9px;height:40px;padding:0 14px;border:1px solid transparent;border-radius:7px;color:#394c66;background:#f7f9fc;font-size:13px;cursor:pointer}.filter-trigger:hover,.filter-trigger.active{border-color:#a9c9f5;color:#1774e8;background:#edf5ff}.filter-trigger svg{width:17px;color:#10a8ac;stroke:currentColor;fill:none;stroke-width:1.8}.filter-trigger i{width:0;height:0;border-left:5px solid transparent;border-right:5px solid transparent;border-top:6px solid #9aa8b9}.filter-trigger.active i{transform:rotate(180deg);border-top-color:#2b7fff}.filter-popover{position:absolute;top:124px;left:20px;z-index:15;display:flex;flex-wrap:wrap;gap:6px;max-width:430px;padding:12px;border:1px solid #e6ebf2;border-radius:8px;background:#fff;box-shadow:0 14px 30px rgba(26,60,110,.15)}.city-popover{max-width:650px}.option-item{min-width:88px;padding:8px 10px;border:0;border-radius:5px;color:#52647d;background:#fff;text-align:left;font-size:12px;cursor:pointer}.option-item:hover,.option-item.selected{color:#0fa5a8;background:#eafafa}.option-empty{display:block;width:100%;padding:10px;color:#9aa8b9;font-size:12px}.large-filter-panel{position:absolute;top:124px;left:20px;right:20px;z-index:14;overflow:hidden;border:1px solid #e6ebf2;border-radius:10px;background:#fff;box-shadow:0 18px 40px rgba(26,60,110,.18)}.panel-heading{display:flex;align-items:center;justify-content:space-between;gap:24px;padding:18px 20px;border-bottom:1px solid #eff3f7}.panel-heading strong{display:block;color:#182e4f;font-size:18px}.panel-heading span{display:block;margin-top:5px;color:#96a3b5;font-size:11px}.panel-search{display:flex;align-items:center;width:min(420px,45%);height:40px;border:1px solid #dce4ee;border-radius:7px;background:#fff}.position-body{display:grid;grid-template-columns:220px minmax(0,1fr);min-height:260px;max-height:430px}.position-groups{overflow:auto;padding:10px 0;background:#f8fafc;border-right:1px solid #edf1f6}.position-groups button{display:block;width:100%;padding:13px 18px;border:0;color:#52647d;background:transparent;text-align:left;font-size:13px;cursor:pointer}.position-groups button:hover,.position-groups button.selected{color:#09a4a7;background:#e5f8f8;font-weight:800}.position-options{display:grid;grid-template-columns:repeat(3,minmax(140px,1fr));align-content:start;gap:6px 10px;overflow:auto;padding:18px 22px}.position-option{display:flex;align-items:center;gap:7px;min-height:38px;padding:7px 9px;border:0;border-radius:6px;color:#354a66;background:#fff;text-align:left;font-size:13px;cursor:pointer}.position-option:hover,.position-option.selected{color:#0aa3a6;background:#f0fbfb}.all-option{grid-column:1/-1;color:#0aa3a6;background:#f3fbfb;font-weight:800}.plus-icon{color:#b4becb;font-size:18px}.industry-panel{max-height:430px}.compact-heading{padding-bottom:14px}.industry-grid{display:grid;grid-template-columns:repeat(4,minmax(140px,1fr));gap:5px 12px;max-height:320px;overflow:auto;padding:16px 22px 22px}.industry-option{min-height:40px;padding:8px 11px;border:0;border-radius:6px;color:#354a66;background:#fff;text-align:left;font-size:13px;cursor:pointer}.industry-option:hover,.industry-option.selected{color:#0aa3a6;background:#f0fbfb}.search-result-row,.list-toolbar,.list-controls,.card-actions,.job-side-top{display:flex;align-items:center;justify-content:space-between;gap:12px}.search-result-row{margin-top:15px;color:#6b7a90;font-size:11px}.result-count span,.saved-count{color:#2b7fff;font-weight:800}.result-hint{color:#a0abba}.active-filters{display:flex;flex-wrap:wrap;align-items:center;gap:7px;margin-top:12px}.active-filter-label{color:#96a3b5;font-size:11px}.active-filter,.clear-all{padding:5px 9px;border:1px solid #dce9f9;border-radius:5px;color:#2b7fff;background:#f3f8ff;font-size:11px;cursor:pointer}.clear-all{border-color:transparent;color:#8291a4;background:transparent}.hot-tags{display:flex;flex-wrap:wrap;align-items:center;gap:7px;margin-top:12px}.hot-label{color:#96a3b5;font-size:11px}.hot-tag{padding:5px 9px;border:1px solid #e0e8f3;border-radius:5px;color:#52647d;background:#f8fafd;font-size:11px;cursor:pointer}.hot-tag:hover{border-color:#b9d0f1;color:#2b7fff;background:#eaf2ff}.list-toolbar{margin:24px 0 13px}.list-title{margin:0;color:#1a3c6e;font-size:17px}.list-subtitle{margin:4px 0 0;color:#6b7a90;font-size:11px}.list-controls{justify-content:flex-end}.sort-control{display:flex;align-items:center;gap:5px;color:#8291a4;font-size:11px}.sort-select{height:34px;padding:0 8px;border:1px solid #dde6f1;border-radius:7px;color:#52647d;background:#fff;font-size:11px}.saved-filter{display:inline-flex;align-items:center;gap:6px;height:34px;padding:0 10px;border:1px solid #dde6f1;border-radius:7px;color:#52647d;background:#fff;font-size:11px;cursor:pointer}.saved-filter svg{width:15px;stroke:currentColor;fill:none;stroke-width:1.7}.saved-filter.active{color:#2b7fff;background:#eaf2ff;border-color:#bfd5f2}.view-toggle{display:flex;border:1px solid #dde6f1;border-radius:7px;overflow:hidden;background:#fff}.view-toggle button{width:34px;height:32px;border:0;color:#96a3b5;background:#fff;cursor:pointer}.view-toggle button+button{border-left:1px solid #dde6f1}.view-toggle button.active{color:#2b7fff;background:#eaf2ff}.view-toggle svg{width:16px;margin:auto;stroke:currentColor;fill:none;stroke-width:1.8}.jobs-list{display:grid;gap:13px}.jobs-list.grid-mode{grid-template-columns:repeat(2,minmax(0,1fr))}.job-card{display:grid;grid-template-columns:minmax(0,1fr) 260px;gap:22px;padding:18px 20px;border:1px solid #e6ebf2;border-radius:10px;background:#fff;box-shadow:0 5px 18px rgba(26,60,110,.045);cursor:pointer;transition:.18s}.job-card:hover{border-color:#bfd5f2;box-shadow:0 10px 24px rgba(26,60,110,.09);transform:translateY(-1px)}.job-card-head{display:flex;gap:12px}.company-logo{width:42px;height:42px;display:grid;place-items:center;flex:0 0 auto;border-radius:9px;color:#fff;background:#2b7fff;font-size:12px;font-weight:800}.job-heading{min-width:0}.job-title{display:block;overflow:hidden;color:#1a3c6e;font-size:15px;font-weight:800;text-decoration:none;text-overflow:ellipsis;white-space:nowrap}.job-company{margin-top:3px;color:#6b7a90;font-size:12px}.job-location{display:flex;align-items:center;gap:5px;margin-top:6px;color:#96a3b5;font-size:11px}.job-location svg{width:14px;stroke:currentColor;fill:none;stroke-width:1.7}.tag-row{display:flex;flex-wrap:wrap;gap:7px;margin-top:15px}.job-tag{padding:4px 8px;border-radius:5px;color:#5c708a;background:#f1f4f8;font-size:10px}.job-tag.primary{color:#2b7fff;background:#eaf2ff}.job-meta{display:flex;flex-wrap:wrap;gap:8px 16px;margin-top:14px;color:#52647d;font-size:11px}.job-meta span{display:flex;align-items:flex-start;gap:5px}.job-meta svg{width:14px;flex:0 0 auto;margin-top:2px;stroke:#96a3b5;fill:none;stroke-width:1.7}.job-side{display:flex;flex-direction:column;justify-content:space-between;min-width:0}.job-salary{color:#1a3c6e;font-size:17px;font-weight:800}.job-posted{color:#a0abba;font-size:10px}.feedback{align-self:flex-start;margin-top:18px;padding:5px 8px;border-radius:5px;color:#7c8b9d;background:#f3f6fa;font-size:10px}.feedback.progress{color:#16865f;background:#e8f7f1}.card-actions{justify-content:flex-end;margin-top:14px}.save-button{display:inline-flex;align-items:center;gap:5px;padding:0;border:0;color:#8291a4;background:transparent;font-size:10px;cursor:pointer}.save-button svg{width:16px;stroke:currentColor;fill:none;stroke-width:1.7}.save-button.saved{color:#2b7fff}.save-button.saved svg{fill:currentColor}.apply-button{min-height:32px;padding:0 12px;border:0;border-radius:6px;color:#fff;background:#2b7fff;font-size:11px;font-weight:800;cursor:pointer}.empty-state{display:none;padding:48px 20px;border:1px dashed #cbd9e8;border-radius:10px;color:#6b7a90;background:#fff;text-align:center}.empty-state.visible{display:grid;place-items:center;gap:8px}.empty-state strong{color:#1a3c6e;font-size:15px}.empty-state span{font-size:12px}.empty-state .search-submit{margin-top:8px}.toast{position:fixed;right:24px;bottom:24px;z-index:50;display:flex;gap:8px;padding:11px 15px;border:1px solid #cce9de;border-radius:8px;color:#176b50;background:#f2fbf7;box-shadow:0 10px 25px rgba(23,43,77,.1);font-size:12px;opacity:0;transform:translateY(8px);pointer-events:none;transition:.18s}.toast.show{opacity:1;transform:translateY(0)}@media(max-width:980px){.filter-strip{gap:8px}.filter-trigger{padding:0 11px}.large-filter-panel{left:0;right:0}.job-card{grid-template-columns:1fr}.job-side{gap:8px}.job-card .feedback{margin-top:4px}.jobs-list.grid-mode{grid-template-columns:1fr}}@media(max-width:700px){.main-content{width:calc(100% - 32px);padding-top:25px}.search-row{display:grid;grid-template-columns:1fr 84px}.filter-strip{padding-top:10px}.filter-trigger{flex:1;justify-content:center;min-width:calc(50% - 8px)}.filter-popover{top:180px;left:0;max-width:calc(100vw - 32px)}.large-filter-panel{top:180px}.panel-heading{display:block}.panel-search{width:100%;margin-top:14px}.position-body{grid-template-columns:128px;max-height:55vh}.position-options{grid-column:1/-1;grid-template-columns:repeat(2,minmax(120px,1fr));padding:12px}.position-groups{grid-column:1/-1;display:flex;overflow:auto;border-right:0;border-bottom:1px solid #edf1f6}.position-groups button{width:auto;flex:0 0 auto;padding:11px 13px;white-space:nowrap}.industry-grid{grid-template-columns:repeat(2,minmax(120px,1fr));padding:12px}.search-result-row{display:block}.result-hint{margin-top:5px}.list-toolbar{display:block}.list-controls{justify-content:flex-start;margin-top:12px;flex-wrap:wrap}.job-card{padding:15px}.job-title{white-space:normal}.card-actions{justify-content:space-between}}@media(max-width:440px){.filter-trigger{font-size:12px}.list-controls{gap:6px}.sort-control{width:100%}}
</style>

<style scoped>
.job-tag-primary{color:#2b7fff;background:#eaf2ff}
.search-box{width:auto;margin:0}
.search-box svg{position:static;top:auto;left:auto;flex:0 0 auto}
.search-box input{min-width:0;padding:0}
.job-card{min-height:0}
.job-side{align-items:flex-start;gap:12px;justify-content:flex-start}
.feedback{margin-top:0}
.card-actions{width:100%;margin-top:2px}
.position-section{grid-column:1/-1;padding-bottom:10px;border-bottom:1px solid #edf1f6}
.position-section:last-of-type{border-bottom:0}
.position-section h3,.industry-section h3{margin:0;padding:4px 9px 7px;color:#6c7b90;font-size:12px;font-weight:700}
.position-section-list{display:grid;grid-template-columns:repeat(3,minmax(140px,1fr));gap:6px 10px}
.industry-grid{display:block;max-height:430px}
.contact-button{min-height:32px;padding:0 12px;border:1px solid #bfd5f2;border-radius:6px;color:#2b7fff;background:#f5f9ff;font-size:11px;font-weight:800;cursor:pointer}
.all-industry{display:block;width:100%;margin-bottom:8px;color:#0aa3a6;background:#f3fbfb;font-weight:800}
.industry-section{display:grid;grid-template-columns:repeat(4,minmax(140px,1fr));gap:5px 12px;padding:8px 0;border-top:1px solid #edf1f6}
.industry-section h3{grid-column:1/-1}
.position-body{height:430px;min-height:0;grid-template-rows:minmax(0,1fr)}
.position-groups,.position-options{min-height:0;overscroll-behavior:contain}
@media(max-width:700px){
  .position-body{height:55vh;max-height:55vh;min-height:0;grid-template-rows:auto minmax(0,1fr)}
  .position-section-list{grid-template-columns:repeat(2,minmax(120px,1fr))}
  .industry-section{grid-template-columns:repeat(2,minmax(120px,1fr))}
}
</style>
