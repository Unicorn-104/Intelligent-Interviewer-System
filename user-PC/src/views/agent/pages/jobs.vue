<template>
<div class="app-shell">
    <header class="topbar">
      <div class="topbar-inner">
        <a class="brand" href="/agent/index" aria-label="返回智聘 AI 首页"><span class="brand-mark">智</span><span class="brand-name">智聘 AI</span><span class="brand-tag">求职者工作台</span></a>
        <nav class="main-nav" aria-label="主导航">
          <a class="nav-link" href="/agent/index">首页</a>
          <a class="nav-link active" href="/agent/jobs" aria-current="page">岗位浏览</a>
          <a class="nav-link" href="/agent/applications">投递跟踪</a>
          <a class="nav-link" href="/agent/messages">消息通知 <span class="nav-badge" data-unread-badge>3</span></a>
          <a class="nav-link" href="/agent/profile">个人中心</a>
        </nav>
        <div class="topbar-actions">
          <NotificationBell />
          <button class="profile-chip" aria-label="打开个人中心"><span class="avatar">林</span><span class="profile-meta"><span class="profile-name">林晓雨</span><span class="profile-role">产品经理</span></span><svg class="profile-chevron" viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" /></svg></button>
        </div>
      </div>
    </header>

    <main class="main-content">
      <section class="page-header" aria-labelledby="pageTitle">
        <div><p class="eyebrow">ROLE DISCOVERY</p><h1 id="pageTitle">岗位浏览</h1><p class="page-intro">AI 根据你的经历和偏好，持续筛选值得关注的机会。<strong>今天有 18 个新岗位</strong></p></div>
      </section>

      <section class="search-panel" aria-label="岗位搜索">
        <form class="search-row" id="searchForm" role="search">
          <label class="search-box" for="jobSearch"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.8" /><path d="m16 16 4.3 4.3" /></svg><input id="jobSearch" type="search" aria-label="搜索岗位名称、公司或技能关键词" placeholder="搜索岗位名称、公司或技能关键词" autocomplete="off" /><button class="clear-search" id="clearSearch" type="button" aria-label="清除搜索">×</button></label>
          <button class="search-submit" type="submit"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.8" /><path d="m16 16 4.3 4.3" /></svg>搜索</button>
          <select class="filter-select" id="sortSelect" aria-label="岗位排序"><option value="match">按匹配度排序</option><option value="latest">按最新发布排序</option><option value="salary">按薪资范围排序</option></select>
        </form>
        <div class="search-result-row"><div class="result-count" aria-live="polite" aria-atomic="true">共找到 <span id="resultCount">8</span> 个匹配岗位</div><div class="result-hint">支持岗位名、公司、技能和城市模糊搜索</div></div>
        <div class="hot-tags" aria-label="推荐搜索示例"><span class="hot-label">试试：</span><button class="hot-tag" type="button" data-keyword="AI 产品经理">AI 产品经理</button><button class="hot-tag" type="button" data-keyword="React">React</button><button class="hot-tag" type="button" data-keyword="大模型应用">大模型应用</button><button class="hot-tag" type="button" data-keyword="用户增长">用户增长</button><button class="hot-tag" type="button" data-keyword="杭州">杭州</button></div>
      </section>

      <section aria-labelledby="listTitle">
        <div class="list-toolbar"><div><h2 class="list-title" id="listTitle">推荐岗位</h2><p class="list-subtitle" id="listSubtitle">优先展示与你的经历和求职偏好匹配的职位</p></div><div class="list-controls"><button class="saved-filter" id="savedFilter" type="button" aria-pressed="false"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg><span>收藏</span><span class="saved-count" id="savedCount">0</span></button><div class="view-toggle" aria-label="视图切换"><button class="active" type="button" aria-label="列表视图" aria-pressed="true"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h16" /></svg></button><button type="button" aria-label="网格视图" aria-pressed="false"><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="4" width="6" height="6" /><rect x="14" y="4" width="6" height="6" /><rect x="4" y="14" width="6" height="6" /><rect x="14" y="14" width="6" height="6" /></svg></button></div></div></div>

        <div class="jobs-list" id="jobsList">
          <article class="job-card" data-id="ai-product" data-title="高级产品经理 AI 招聘方向" data-search="高级产品经理 ai产品经理 大模型应用 极氪智能科技 杭州 智能招聘 agent 产品经理">
            <a class="job-card-link" href="/agent/job-detail?id=ai-product" aria-label="查看高级产品经理 AI 招聘方向详情"></a>
            <div class="job-main"><div class="job-card-head"><div class="company-logo">极氪</div><div class="job-heading"><a class="job-title" href="/agent/job-detail?id=ai-product">高级产品经理（AI 招聘方向）</a><div class="job-company">极氪智能科技有限公司</div><div class="job-location"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>上海 · 静安区</div></div></div><div class="tag-row"><span class="job-tag urgent">急招</span><span class="job-tag primary">大模型应用</span><span class="job-tag">本科</span><span class="job-tag">3-5年</span></div><div class="job-meta"><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" /></svg>负责 AI 招聘 Agent 产品规划</span><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v18M3 12h18" /></svg>产品策略 · 用户研究</span></div></div>
            <div class="job-side"><div class="job-side-top"><div class="job-salary">25-40K <small>· 15薪</small></div><div class="job-posted">发布于 06-12</div></div><div class="feedback progress">简历已查看</div><div class="card-actions"><button class="save-button" type="button" aria-label="收藏高级产品经理岗位"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg><span>收藏岗位</span></button><button class="apply-button" type="button">投递简历</button></div></div>
          </article>

          <article class="job-card" data-id="frontend-react" data-title="前端开发工程师 React" data-search="前端开发 前端工程师 react 杭州 云杉网络 技术开发 本科">
            <a class="job-card-link" href="/agent/job-detail?id=frontend-react" aria-label="查看前端开发工程师 React 详情"></a>
            <div class="job-main"><div class="job-card-head"><div class="company-logo orange">云杉</div><div class="job-heading"><a class="job-title" href="/agent/job-detail?id=frontend-react">前端开发工程师（React）</a><div class="job-company">杭州云杉网络技术有限公司</div><div class="job-location"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>杭州 · 西湖区</div></div></div><div class="tag-row"><span class="job-tag">招聘中</span><span class="job-tag primary">前端开发</span><span class="job-tag">本科</span><span class="job-tag">3-5年</span></div><div class="job-meta"><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" /></svg>负责企业级 Web 应用开发</span><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v18M3 12h18" /></svg>React · TypeScript</span></div></div>
            <div class="job-side"><div class="job-side-top"><div class="job-salary">18-28K <small>· 14薪</small></div><div class="job-posted">发布于 06-14</div></div><div class="feedback new">等待简历筛选</div><div class="card-actions"><button class="save-button" type="button" aria-label="收藏前端开发工程师岗位"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg><span>收藏岗位</span></button><button class="apply-button" type="button">投递简历</button></div></div>
          </article>

          <article class="job-card" data-id="nlp-algorithm" data-title="算法工程师 NLP 方向" data-search="算法工程师 nlp 大模型应用 北京 智谱科技 机器学习 本科">
            <a class="job-card-link" href="/agent/job-detail?id=nlp-algorithm" aria-label="查看算法工程师 NLP 方向详情"></a>
            <div class="job-main"><div class="job-card-head"><div class="company-logo purple">智谱</div><div class="job-heading"><a class="job-title" href="/agent/job-detail?id=nlp-algorithm">算法工程师（NLP 方向）</a><div class="job-company">北京智谱华章科技有限公司</div><div class="job-location"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>北京 · 海淀区</div></div></div><div class="tag-row"><span class="job-tag primary">大模型应用</span><span class="job-tag">硕士</span><span class="job-tag">3-5年</span></div><div class="job-meta"><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" /></svg>负责大模型预训练与 RAG</span><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v18M3 12h18" /></svg>Python · PyTorch</span></div></div>
            <div class="job-side"><div class="job-side-top"><div class="job-salary">30-50K <small>· 16薪</small></div><div class="job-posted">发布于 06-10</div></div><div class="feedback new">新增岗位</div><div class="card-actions"><button class="save-button" type="button" aria-label="收藏算法工程师岗位"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg><span>收藏岗位</span></button><button class="apply-button" type="button">投递简历</button></div></div>
          </article>

          <article class="job-card" data-id="saas-ux" data-title="UI UX 设计师 企业级 SaaS" data-search="ui ux 设计师 企业级 saas 深圳 蓝色光标 设计 本科">
            <a class="job-card-link" href="/agent/job-detail?id=saas-ux" aria-label="查看 UI UX 设计师 企业级 SaaS 详情"></a>
            <div class="job-main"><div class="job-card-head"><div class="company-logo green">蓝标</div><div class="job-heading"><a class="job-title" href="/agent/job-detail?id=saas-ux">UI/UX 设计师（企业级 SaaS）</a><div class="job-company">深圳蓝色光标数据科技有限公司</div><div class="job-location"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>深圳 · 南山区</div></div></div><div class="tag-row"><span class="job-tag">独角兽</span><span class="job-tag primary">企业服务</span><span class="job-tag">本科</span><span class="job-tag">1-3年</span></div><div class="job-meta"><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" /></svg>负责企业端产品体验设计</span><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v18M3 12h18" /></svg>Figma · 设计系统</span></div></div>
            <div class="job-side"><div class="job-side-top"><div class="job-salary">16-25K <small>· 13薪</small></div><div class="job-posted">发布于 06-09</div></div><div class="feedback">暂无反馈</div><div class="card-actions"><button class="save-button" type="button" aria-label="收藏 UI UX 设计师岗位"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg><span>收藏岗位</span></button><button class="apply-button" type="button">投递简历</button></div></div>
          </article>

          <article class="job-card" data-id="growth" data-title="用户增长负责人 社区" data-search="用户增长 运营 小红书 社区 上海 本科 3-5年">
            <a class="job-card-link" href="/agent/job-detail?id=growth" aria-label="查看用户增长负责人 社区详情"></a>
            <div class="job-main"><div class="job-card-head"><div class="company-logo green">小红书</div><div class="job-heading"><a class="job-title" href="/agent/job-detail?id=growth">用户增长负责人 · 社区</a><div class="job-company">小红书科技有限公司</div><div class="job-location"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>上海 · 黄浦区</div></div></div><div class="tag-row"><span class="job-tag urgent">急招</span><span class="job-tag primary">用户增长</span><span class="job-tag">本科</span><span class="job-tag">3-5年</span></div><div class="job-meta"><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" /></svg>负责社区用户增长策略</span><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v18M3 12h18" /></svg>增长实验 · 数据分析</span></div></div>
            <div class="job-side"><div class="job-side-top"><div class="job-salary">28-45K <small>· 15薪</small></div><div class="job-posted">发布于 06-15</div></div><div class="feedback progress">已进入沟通</div><div class="card-actions"><button class="save-button" type="button" aria-label="收藏用户增长负责人岗位"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg><span>收藏岗位</span></button><button class="apply-button" type="button">投递简历</button></div></div>
          </article>

          <article class="job-card" data-id="commercial" data-title="商业产品经理 抖音电商" data-search="商业产品经理 抖音电商 字节跳动 北京 商业化 AI产品经理 本科">
            <a class="job-card-link" href="/agent/job-detail?id=commercial" aria-label="查看商业产品经理 抖音电商详情"></a>
            <div class="job-main"><div class="job-card-head"><div class="company-logo orange">字节</div><div class="job-heading"><a class="job-title" href="/agent/job-detail?id=commercial">商业产品经理 · 抖音电商</a><div class="job-company">字节跳动科技有限公司</div><div class="job-location"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>北京 · 海淀区</div></div></div><div class="tag-row"><span class="job-tag urgent">急招</span><span class="job-tag primary">AI产品经理</span><span class="job-tag">本科</span><span class="job-tag">3-5年</span></div><div class="job-meta"><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" /></svg>负责商业化产品增长</span><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v18M3 12h18" /></svg>商业策略 · 业务协同</span></div></div>
            <div class="job-side"><div class="job-side-top"><div class="job-salary">30-45K <small>· 15薪</small></div><div class="job-posted">发布于 06-16</div></div><div class="feedback new">新增岗位</div><div class="card-actions"><button class="save-button" type="button" aria-label="收藏商业产品经理岗位"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg><span>收藏岗位</span></button><button class="apply-button" type="button">投递简历</button></div></div>
          </article>

          <article class="job-card" data-id="model-app" data-title="大模型应用产品经理" data-search="大模型应用 AI产品经理 产品经理 百度 北京 生成式AI 3-5年">
            <a class="job-card-link" href="/agent/job-detail?id=model-app" aria-label="查看大模型应用产品经理详情"></a>
            <div class="job-main"><div class="job-card-head"><div class="company-logo">百度</div><div class="job-heading"><a class="job-title" href="/agent/job-detail?id=model-app">大模型应用产品经理</a><div class="job-company">百度在线网络技术有限公司</div><div class="job-location"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>北京 · 海淀区</div></div></div><div class="tag-row"><span class="job-tag primary">大模型应用</span><span class="job-tag">本科</span><span class="job-tag">3-5年</span></div><div class="job-meta"><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" /></svg>探索生成式 AI 落地场景</span><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v18M3 12h18" /></svg>用户需求 · 产品设计</span></div></div>
            <div class="job-side"><div class="job-side-top"><div class="job-salary">28-42K <small>· 15薪</small></div><div class="job-posted">发布于 06-17</div></div><div class="feedback new">新增岗位</div><div class="card-actions"><button class="save-button" type="button" aria-label="收藏大模型应用产品经理岗位"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg><span>收藏岗位</span></button><button class="apply-button" type="button">投递简历</button></div></div>
          </article>

          <article class="job-card" data-id="strategy" data-title="策略产品经理 本地生活" data-search="策略产品经理 本地生活 美团 北京 产品经理 数据分析 本科">
            <a class="job-card-link" href="/agent/job-detail?id=strategy" aria-label="查看策略产品经理 本地生活详情"></a>
            <div class="job-main"><div class="job-card-head"><div class="company-logo green">美团</div><div class="job-heading"><a class="job-title" href="/agent/job-detail?id=strategy">策略产品经理 · 本地生活</a><div class="job-company">美团科技有限公司</div><div class="job-location"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>北京 · 朝阳区</div></div></div><div class="tag-row"><span class="job-tag">招聘中</span><span class="job-tag primary">策略产品</span><span class="job-tag">本科</span><span class="job-tag">3-5年</span></div><div class="job-meta"><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" /></svg>负责本地生活业务策略</span><span><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v18M3 12h18" /></svg>用户洞察 · 数据分析</span></div></div>
            <div class="job-side"><div class="job-side-top"><div class="job-salary">25-38K <small>· 15薪</small></div><div class="job-posted">发布于 06-11</div></div><div class="feedback">暂无反馈</div><div class="card-actions"><button class="save-button" type="button" aria-label="收藏策略产品经理岗位"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg><span>收藏岗位</span></button><button class="apply-button" type="button">投递简历</button></div></div>
          </article>
        </div>
        <div class="empty-state" id="emptyState"><strong id="emptyTitle">没有找到匹配岗位</strong><span id="emptyHint">换一个岗位名称、公司或技能关键词试试。</span></div>
      </section>
    </main>
  </div>

  <div class="toast" id="toast" role="status"><span>✓</span><span id="toastMessage">操作成功</span></div>
</template>

<script setup>
import { onMounted } from 'vue'
import NotificationBell from '@/components/agent/NotificationBell.vue'

onMounted(() => {
  // 岗位数据和交互均为前端模拟，不依赖后端接口。
      const searchInput = document.getElementById('jobSearch');
      const clearSearch = document.getElementById('clearSearch');
      const resultCount = document.getElementById('resultCount');
      const jobsList = document.getElementById('jobsList');
      const jobCards = [...document.querySelectorAll('.job-card')];
      const emptyState = document.getElementById('emptyState');
      const emptyTitle = document.getElementById('emptyTitle');
      const emptyHint = document.getElementById('emptyHint');
      const sortSelect = document.getElementById('sortSelect');
      const hotTags = [...document.querySelectorAll('.hot-tag')];
      const searchForm = document.getElementById('searchForm');
      const savedFilter = document.getElementById('savedFilter');
      const savedCount = document.getElementById('savedCount');
      const listTitle = document.getElementById('listTitle');
      const listSubtitle = document.getElementById('listSubtitle');
      const toast = document.getElementById('toast');
      const toastMessage = document.getElementById('toastMessage');
      const savedStorageKey = 'zhipin-ai-saved-jobs';
      let savedOnly = false;
      let savedJobs = new Set();
      let toastTimer;
  
      try { const availableJobIds = new Set(jobCards.map((card) => card.dataset.id)); savedJobs = new Set(JSON.parse(localStorage.getItem(savedStorageKey) || '[]').filter((id) => availableJobIds.has(id))); } catch (error) { savedJobs = new Set(); }
  
      function showToast(message) {
        toastMessage.textContent = message;
        toast.classList.add('show');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => toast.classList.remove('show'), 2500);
      }
  
      // 搜索词按空格和标点拆分，支持中英文大小写以及多关键词组合匹配。
      function normalize(value) { return value.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim(); }
  
      function getTerms(value) { return normalize(value).split(/\s+/).filter(Boolean); }
  
      function syncSavedUI() {
        jobCards.forEach((card) => {
          const button = card.querySelector('.save-button');
          const saved = savedJobs.has(card.dataset.id);
          button.classList.toggle('saved', saved);
          button.setAttribute('aria-pressed', String(saved));
          button.setAttribute('aria-label', saved ? '取消收藏岗位' : '收藏岗位');
          button.querySelector('span').textContent = saved ? '已收藏' : '收藏岗位';
        });
        savedCount.textContent = savedJobs.size;
      }
  
      function saveFavorites() {
        try { localStorage.setItem(savedStorageKey, JSON.stringify([...savedJobs])); } catch (error) { /* 隐私模式下仍保留当前页面状态 */ }
      }
  
      function filterJobs() {
        const terms = getTerms(searchInput.value);
        let visibleCount = 0;
        jobCards.forEach((card) => {
          const corpus = normalize(`${card.dataset.title} ${card.dataset.search} ${card.textContent}`);
          const matchedSearch = terms.length === 0 || terms.every((term) => corpus.includes(term));
          const matchedSaved = !savedOnly || savedJobs.has(card.dataset.id);
          const visible = matchedSearch && matchedSaved;
          card.hidden = !visible;
          if (visible) visibleCount += 1;
        });
        resultCount.textContent = visibleCount;
        emptyState.classList.toggle('visible', visibleCount === 0);
        clearSearch.classList.toggle('visible', terms.length > 0);
        hotTags.forEach((tag) => tag.classList.toggle('active', normalize(tag.dataset.keyword) === normalize(searchInput.value)));
        listTitle.textContent = savedOnly ? '收藏的岗位' : terms.length ? '搜索结果' : '推荐岗位';
        listSubtitle.textContent = savedOnly ? `已收藏 ${savedJobs.size} 个岗位，可继续输入关键词筛选` : terms.length ? `正在显示与“${searchInput.value.trim()}”相关的岗位` : '优先展示与你的经历和求职偏好匹配的职位';
        emptyTitle.textContent = savedOnly ? '还没有符合条件的收藏岗位' : '没有找到匹配岗位';
        emptyHint.textContent = savedOnly ? '取消搜索条件，或先收藏感兴趣的岗位再回来查看。' : '试试“AI 产品经理”或“React”，也可以搜索公司和城市。';
        savedFilter.setAttribute('aria-label', `${savedOnly ? '取消仅看' : '仅看'}收藏岗位，共 ${savedJobs.size} 个`);
        return visibleCount;
      }
  
      searchInput.addEventListener('input', filterJobs);
      clearSearch.addEventListener('click', () => { searchInput.value = ''; filterJobs(); searchInput.focus(); });
      hotTags.forEach((tag) => tag.addEventListener('click', () => { searchInput.value = tag.dataset.keyword; filterJobs(); }));
      searchForm.addEventListener('submit', (event) => { event.preventDefault(); const count = filterJobs(); showToast(searchInput.value.trim() ? `已找到 ${count} 个匹配岗位` : `当前共有 ${count} 个岗位`); jobsList.scrollIntoView({ behavior: 'smooth', block: 'start' }); });
      savedFilter.addEventListener('click', () => { savedOnly = !savedOnly; savedFilter.classList.toggle('active', savedOnly); savedFilter.setAttribute('aria-pressed', String(savedOnly)); const count = filterJobs(); showToast(savedOnly ? `正在查看 ${count} 个收藏岗位` : '已返回全部岗位'); });
  
      // 下拉排序只调整当前卡片顺序，用前端占位数据模拟真实岗位列表。
      sortSelect.addEventListener('change', () => {
        const cards = [...jobsList.querySelectorAll('.job-card')];
        if (sortSelect.value === 'latest') cards.sort((a, b) => b.dataset.id.localeCompare(a.dataset.id));
        if (sortSelect.value === 'salary') cards.sort((a, b) => b.querySelector('.job-salary').textContent.localeCompare(a.querySelector('.job-salary').textContent, 'zh-CN', { numeric: true }));
        if (sortSelect.value === 'match') cards.sort((a, b) => jobCards.indexOf(a) - jobCards.indexOf(b));
        cards.forEach((card) => jobsList.appendChild(card));
        showToast(`已切换为${sortSelect.options[sortSelect.selectedIndex].text}`);
      });
  
      // 卡片覆盖链接负责跳转详情，按钮阻止冒泡后保留当前页面操作。
      document.querySelectorAll('.save-button').forEach((button) => button.addEventListener('click', (event) => {
        event.stopPropagation();
        const card = button.closest('.job-card');
        const saved = !savedJobs.has(card.dataset.id);
        if (saved) savedJobs.add(card.dataset.id); else savedJobs.delete(card.dataset.id);
        saveFavorites();
        syncSavedUI();
        filterJobs();
        showToast(saved ? '已收藏该岗位' : '已取消收藏');
      }));
  
      document.querySelectorAll('.apply-button').forEach((button) => button.addEventListener('click', (event) => {
        event.stopPropagation();
        const card = button.closest('.job-card');
        window.__agentNavigate(`/agent/resume-select?job=${encodeURIComponent(card.dataset.id)}`);
      }));
  
      jobCards.forEach((card) => card.addEventListener('click', (event) => {
        if (event.target.closest('button, a')) return;
        card.querySelector('.job-card-link').click();
      }));
      document.querySelector('.profile-chip').addEventListener('click', () => { window.__agentNavigate('/agent/profile'); });
  
      // 列表 / 网格仅提供轻量视觉切换，保持同一组岗位数据。
      const viewButtons = [...document.querySelectorAll('.view-toggle button')];
      viewButtons.forEach((button, index) => button.addEventListener('click', () => {
        viewButtons.forEach((item, itemIndex) => { const active = itemIndex === index; item.classList.toggle('active', active); item.setAttribute('aria-pressed', String(active)); });
        jobsList.style.gridTemplateColumns = index === 1 ? 'repeat(2, minmax(0, 1fr))' : '';
        jobsList.classList.toggle('grid-mode', index === 1);
      }));
  
      syncSavedUI();
      filterJobs();
})
</script>

<style>
:root {
      --primary: #1A3C6E;
      --primary-deep: #102D53;
      --interactive: #2B7FFF;
      --interactive-dark: #1B65D1;
      --interactive-soft: #EAF2FF;
      --bg: #F5F7FA;
      --card: #FFFFFF;
      --text: #172B4D;
      --muted: #6B7A90;
      --muted-light: #94A1B2;
      --line: #E6EBF2;
      --line-strong: #D8E1ED;
      --success: #1B9A72;
      --success-soft: #E7F7F1;
      --warning: #B36512;
      --warning-soft: #FFF4E5;
      --danger: #E2555F;
      --shadow: 0 8px 24px rgba(26, 60, 110, 0.06);
      --radius: 10px;
    }

    * { box-sizing: border-box; }
    html { scroll-behavior: smooth; }
    body { margin: 0; color: var(--text); background: var(--bg); font-family: "PingFang SC", "Microsoft YaHei", system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; font-size: 14px; line-height: 1.5; }
    button, input, select { font: inherit; }
    button, a, select { -webkit-tap-highlight-color: transparent; }
    button { cursor: pointer; }
    a { color: inherit; }
    .app-shell { min-height: 100vh; }

    /* 顶部导航：与首页保持相同的品牌和信息层级 */
    .topbar { position: sticky; top: 0; z-index: 20; height: 72px; display: flex; align-items: center; border-bottom: 1px solid rgba(230, 235, 242, .92); background: rgba(255, 255, 255, .97); backdrop-filter: blur(12px); }
    .topbar-inner { width: min(1240px, calc(100% - 48px)); margin: 0 auto; display: flex; align-items: center; gap: 32px; }
    .brand { display: inline-flex; align-items: center; gap: 10px; color: var(--primary); text-decoration: none; white-space: nowrap; }
    .brand-mark { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 9px; color: #fff; background: linear-gradient(145deg, #2B7FFF, #1A3C6E); box-shadow: 0 5px 12px rgba(43, 127, 255, .22); font-size: 17px; font-weight: 800; letter-spacing: -1px; }
    .brand-name { font-size: 18px; font-weight: 800; letter-spacing: .2px; }
    .brand-tag { margin-left: 2px; color: var(--muted); font-size: 11px; font-weight: 500; }
    .main-nav { display: flex; align-items: center; gap: 5px; height: 100%; }
    .nav-link { position: relative; height: 72px; display: inline-flex; align-items: center; padding: 0 15px; color: var(--muted); font-size: 14px; text-decoration: none; transition: color .2s ease; }
    .nav-link:hover, .nav-link.active { color: var(--primary); }
    .nav-link.active { font-weight: 700; }
    .nav-link.active::after { content: ""; position: absolute; right: 15px; bottom: 0; left: 15px; height: 3px; border-radius: 3px 3px 0 0; background: var(--interactive); }
    .nav-badge { min-width: 17px; height: 17px; margin-left: 6px; padding: 0 5px; display: inline-grid; place-items: center; border-radius: 99px; color: #fff; background: var(--danger); font-size: 10px; line-height: 1; }
    .topbar-actions { margin-left: auto; display: flex; align-items: center; gap: 18px; }
    .icon-button { position: relative; width: 40px; height: 40px; display: grid; place-items: center; border: 0; border-radius: 9px; color: var(--muted); background: transparent; transition: background .2s, color .2s; }
    .icon-button:hover, .icon-button:focus-visible { color: var(--primary); background: var(--interactive-soft); outline: none; }
    .icon-button svg { width: 19px; height: 19px; stroke: currentColor; fill: none; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
    .notification-dot { position: absolute; top: 7px; right: 7px; width: 7px; height: 7px; border: 2px solid #fff; border-radius: 50%; background: var(--danger); }
    .profile-chip { display: flex; align-items: center; gap: 9px; padding: 4px 0 4px 5px; border: 0; color: var(--text); background: transparent; }
    .avatar { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 50%; color: #fff; background: linear-gradient(135deg, #8EA9D1, #5377AE); font-size: 13px; font-weight: 700; }
    .profile-meta { text-align: left; line-height: 1.25; }
    .profile-name { display: block; font-weight: 700; }
    .profile-role { display: block; margin-top: 2px; color: var(--muted); font-size: 11px; }
    .profile-chevron { width: 15px; height: 15px; margin-left: 1px; color: var(--muted); }

    .main-content { width: min(1240px, calc(100% - 48px)); margin: 0 auto; padding: 32px 0 56px; }
    .page-header { display: flex; align-items: flex-end; justify-content: space-between; gap: 24px; margin-bottom: 22px; }
    .eyebrow { margin: 0 0 7px; color: var(--interactive); font-size: 11px; font-weight: 800; letter-spacing: .9px; }
    h1 { margin: 0; color: var(--primary); font-size: 28px; line-height: 1.25; letter-spacing: -.35px; }
    .page-intro { margin: 8px 0 0; color: var(--muted); font-size: 13px; }
    .page-intro strong { color: var(--primary); }

    /* 搜索区：结果统计与搜索控件处于同一条信息带 */
    .search-panel { padding: 20px 22px 18px; border: 1px solid var(--line); border-radius: var(--radius); background: var(--card); box-shadow: var(--shadow); }
    .search-row { display: flex; align-items: center; gap: 12px; }
    .search-box { position: relative; flex: 1; min-width: 0; }
    .search-box svg { position: absolute; top: 13px; left: 15px; width: 18px; height: 18px; color: var(--muted); stroke: currentColor; fill: none; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; pointer-events: none; }
    .search-box input { width: 100%; height: 44px; padding: 0 43px 0 42px; border: 1px solid var(--line-strong); border-radius: 8px; outline: none; color: var(--text); background: #FBFCFE; transition: border-color .2s, box-shadow .2s, background .2s; }
    .search-box input::placeholder { color: #9AA7B8; }
    .search-box input:focus { border-color: rgba(43, 127, 255, .78); background: #fff; box-shadow: 0 0 0 3px rgba(43, 127, 255, .12); }
    .clear-search { position: absolute; top: 7px; right: 8px; width: 30px; height: 30px; display: none; place-items: center; border: 0; border-radius: 6px; color: var(--muted); background: transparent; font-size: 18px; line-height: 1; }
    .clear-search.visible { display: grid; }
    .clear-search:hover { color: var(--primary); background: var(--interactive-soft); }
    .search-submit { height: 44px; min-width: 84px; padding: 0 16px; display: inline-flex; align-items: center; justify-content: center; gap: 7px; border: 1px solid var(--interactive); border-radius: 8px; color: #fff; background: var(--interactive); font-size: 12px; font-weight: 700; transition: background .2s, border-color .2s; }
    .search-submit:hover { border-color: var(--interactive-dark); background: var(--interactive-dark); }
    .search-submit svg { width: 15px; height: 15px; fill: none; stroke: currentColor; stroke-width: 1.9; stroke-linecap: round; stroke-linejoin: round; }
    .filter-select { height: 42px; min-width: 132px; padding: 0 30px 0 12px; border: 1px solid var(--line-strong); border-radius: 8px; color: var(--primary); background: #fff; font-size: 12px; }
    .search-result-row { display: flex; align-items: center; justify-content: space-between; gap: 16px; margin-top: 16px; }
    .result-count { color: var(--primary); font-size: 13px; font-weight: 700; }
    .result-count span { color: var(--interactive); font-size: 16px; font-variant-numeric: tabular-nums; }
    .result-hint { color: var(--muted-light); font-size: 11px; }
    .hot-tags { display: flex; flex-wrap: wrap; align-items: center; gap: 7px; margin-top: 13px; }
    .hot-label { margin-right: 2px; color: var(--muted-light); font-size: 11px; }
    .hot-tag { min-height: 28px; padding: 0 10px; border: 1px solid #DCE7F6; border-radius: 6px; color: var(--interactive); background: #F4F8FF; font-size: 11px; transition: color .2s, background .2s, border .2s; }
    .hot-tag:hover, .hot-tag.active { border-color: #B7D1F5; color: #fff; background: var(--interactive); }

    .list-toolbar { display: flex; align-items: center; justify-content: space-between; gap: 18px; margin: 25px 0 12px; }
    .list-title { margin: 0; color: var(--primary); font-size: 16px; font-weight: 800; }
    .list-subtitle { margin: 4px 0 0; color: var(--muted); font-size: 12px; }
    .list-controls { display: flex; align-items: center; gap: 9px; }
    .saved-filter { height: 36px; padding: 0 11px; display: inline-flex; align-items: center; gap: 7px; border: 1px solid var(--line-strong); border-radius: 7px; color: var(--primary); background: #fff; font-size: 12px; font-weight: 700; transition: color .2s, border-color .2s, background .2s; }
    .saved-filter:hover { border-color: #B8CCEA; color: var(--interactive); background: #F8FBFF; }
    .saved-filter.active { border-color: #AFCBF2; color: var(--interactive); background: var(--interactive-soft); }
    .saved-filter svg { width: 15px; height: 15px; fill: none; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
    .saved-filter.active svg { fill: currentColor; }
    .saved-count { min-width: 19px; height: 19px; padding: 0 5px; display: inline-grid; place-items: center; border-radius: 99px; color: var(--muted); background: #EEF2F7; font-size: 10px; font-variant-numeric: tabular-nums; }
    .saved-filter.active .saved-count { color: #fff; background: var(--interactive); }
    .view-toggle { display: inline-flex; align-items: center; gap: 2px; padding: 3px; border: 1px solid var(--line); border-radius: 7px; background: #fff; }
    .view-toggle button { width: 32px; height: 28px; display: grid; place-items: center; border: 0; border-radius: 4px; color: var(--muted-light); background: transparent; }
    .view-toggle button.active, .view-toggle button:hover { color: var(--interactive); background: var(--interactive-soft); }
    .view-toggle svg { width: 16px; height: 16px; stroke: currentColor; fill: none; stroke-width: 1.7; stroke-linecap: round; stroke-linejoin: round; }
    .search-submit:focus-visible, .saved-filter:focus-visible, .view-toggle button:focus-visible, .hot-tag:focus-visible { outline: 3px solid rgba(43, 127, 255, .22); outline-offset: 2px; }

    .jobs-list { display: grid; gap: 10px; }
    .job-card { position: relative; display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 18px; padding: 19px 22px 17px; border: 1px solid var(--line); border-radius: var(--radius); background: var(--card); box-shadow: 0 3px 13px rgba(26, 60, 110, .035); transition: border-color .2s, box-shadow .2s, transform .2s; }
    .job-card[hidden] { display: none; }
    .job-card:hover { border-color: #C6D9F1; box-shadow: 0 10px 22px rgba(26, 60, 110, .08); transform: translateY(-1px); }
    .job-card:focus-within { border-color: #B7D1F5; box-shadow: 0 0 0 3px rgba(43, 127, 255, .09); }
    .job-main { min-width: 0; }
    .job-card-head { display: flex; align-items: flex-start; gap: 12px; }
    .company-logo { width: 42px; height: 42px; display: grid; place-items: center; flex: 0 0 auto; border-radius: 9px; color: var(--primary); background: var(--interactive-soft); font-size: 12px; font-weight: 800; }
    .company-logo.orange { color: #985D13; background: #FFF0D8; }
    .company-logo.green { color: #147156; background: var(--success-soft); }
    .company-logo.purple { color: #5C48A5; background: #F0ECFF; }
    .job-heading { min-width: 0; }
    .job-title { display: inline-block; max-width: 100%; overflow: hidden; color: var(--primary); font-size: 15px; font-weight: 800; text-overflow: ellipsis; white-space: nowrap; text-decoration: none; }
    .job-title:hover { color: var(--interactive); }
    .job-company { margin-top: 4px; color: var(--muted); font-size: 12px; }
    .job-location { display: inline-flex; align-items: center; gap: 5px; margin-top: 9px; color: #52657E; font-size: 12px; }
    .job-location svg, .job-meta svg { width: 14px; height: 14px; color: #8998AA; stroke: currentColor; fill: none; stroke-width: 1.7; stroke-linecap: round; stroke-linejoin: round; }
    .tag-row { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 12px; }
    .job-tag { min-height: 23px; padding: 2px 8px; border-radius: 5px; color: #536985; background: #F1F5FA; font-size: 11px; line-height: 19px; }
    .job-tag.urgent { color: #A65E10; background: var(--warning-soft); }
    .job-tag.primary { color: var(--interactive); background: var(--interactive-soft); }
    .job-meta { display: flex; flex-wrap: wrap; gap: 8px 16px; margin-top: 13px; color: var(--muted); font-size: 12px; }
    .job-meta span { display: inline-flex; align-items: center; gap: 5px; }
    .job-side { min-width: 168px; display: flex; flex-direction: column; align-items: flex-end; justify-content: space-between; gap: 16px; }
    .job-salary { color: var(--primary); font-size: 16px; font-weight: 800; white-space: nowrap; }
    .job-salary small { color: var(--muted); font-size: 11px; font-weight: 400; }
    .job-posted { color: var(--muted-light); font-size: 11px; white-space: nowrap; }
    .feedback { display: inline-flex; align-items: center; gap: 5px; color: var(--muted); font-size: 11px; white-space: nowrap; }
    .feedback::before { content: ""; width: 6px; height: 6px; border-radius: 50%; background: #B4C0CE; }
    .feedback.new { color: var(--success); }
    .feedback.new::before { background: var(--success); }
    .feedback.progress { color: var(--interactive); }
    .feedback.progress::before { background: var(--interactive); }
    .card-actions { display: flex; align-items: center; gap: 8px; }
    .save-button, .apply-button { min-height: 36px; border-radius: 6px; font-size: 12px; font-weight: 700; transition: background .2s, border-color .2s, color .2s, transform .2s; }
    .save-button { display: inline-flex; align-items: center; gap: 6px; padding: 0 11px; border: 1px solid #C7D7EB; color: var(--interactive); background: #fff; }
    .save-button:hover, .save-button.saved { border-color: #A9C7F0; background: var(--interactive-soft); }
    .save-button svg { width: 15px; height: 15px; fill: none; stroke: currentColor; stroke-width: 1.7; stroke-linecap: round; stroke-linejoin: round; }
    .save-button.saved svg { fill: currentColor; }
    .apply-button { min-width: 85px; padding: 0 14px; border: 1px solid var(--interactive); color: #fff; background: var(--interactive); }
    .apply-button:hover { border-color: var(--interactive-dark); background: var(--interactive-dark); transform: translateY(-1px); }
    .apply-button.applied { border-color: #B8E3D3; color: var(--success); background: var(--success-soft); }
    .job-card-link { position: absolute; inset: 0; z-index: 0; border-radius: var(--radius); outline: none; }
    .job-card > *:not(.job-card-link) { position: relative; z-index: 1; }
    .job-card-link:focus-visible { box-shadow: inset 0 0 0 3px rgba(43, 127, 255, .35); }
    .empty-state { display: none; padding: 50px 24px; border: 1px dashed #C9D6E7; border-radius: var(--radius); color: var(--muted); background: #fff; text-align: center; }
    .empty-state.visible { display: block; }
    .empty-state strong { display: block; margin-bottom: 6px; color: var(--primary); font-size: 15px; }

    .notification-popover { position: fixed; z-index: 30; top: 63px; right: max(24px, calc((100vw - 1240px) / 2)); width: 320px; display: none; border: 1px solid var(--line); border-radius: 10px; background: #fff; box-shadow: 0 16px 38px rgba(23, 43, 77, .16); overflow: hidden; }
    .notification-popover.open { display: block; animation: popIn .16s ease-out; }
    @keyframes popIn { from { opacity: 0; transform: translateY(-5px); } to { opacity: 1; transform: translateY(0); } }
    .popover-head { display: flex; align-items: center; justify-content: space-between; padding: 15px 16px; border-bottom: 1px solid var(--line); }
    .popover-head strong { color: var(--primary); font-size: 14px; }
    .popover-head button { padding: 0; border: 0; color: var(--interactive); background: transparent; font-size: 11px; }
    .notification-item { display: flex; gap: 10px; padding: 13px 16px; border-bottom: 1px solid #F1F3F7; }
    .notification-icon { width: 28px; height: 28px; display: grid; place-items: center; flex: 0 0 auto; border-radius: 7px; color: var(--interactive); background: var(--interactive-soft); font-size: 12px; font-weight: 800; }
    .notification-item p { margin: 0; color: var(--text); font-size: 12px; line-height: 1.45; }
    .notification-item time { display: block; margin-top: 4px; color: var(--muted-light); font-size: 10px; }
    .toast { position: fixed; z-index: 60; right: 24px; bottom: 24px; display: flex; align-items: center; gap: 9px; max-width: calc(100vw - 48px); padding: 11px 15px; border: 1px solid #CCE9DE; border-radius: 8px; color: #176B50; background: #F2FBF7; box-shadow: 0 10px 25px rgba(23, 43, 77, .1); font-size: 12px; opacity: 0; transform: translateY(10px); pointer-events: none; transition: opacity .2s, transform .2s; }
    .toast.show { opacity: 1; transform: translateY(0); }
    @media (prefers-reduced-motion: reduce) { *, *::before, *::after { scroll-behavior: auto !important; transition-duration: .01ms !important; animation-duration: .01ms !important; } }

    @media (max-width: 980px) {
      .topbar-inner, .main-content { width: min(100% - 32px, 760px); }
      .topbar-inner { gap: 15px; }
      .brand-tag, .profile-meta, .profile-chevron { display: none; }
      .main-nav { margin-left: auto; }
      .nav-link { padding: 0 9px; }
      .nav-link.active::after { right: 9px; left: 9px; }
      .topbar-actions { margin-left: 0; }
      .job-card { grid-template-columns: 1fr; gap: 14px; }
      .job-side { min-width: 0; align-items: flex-start; gap: 12px; }
      .job-side-top { display: flex; align-items: center; gap: 14px; }
    }
    @media (max-width: 640px) {
      .topbar { height: 64px; }
      .topbar-inner, .main-content { width: calc(100% - 28px); }
      .topbar-inner { gap: 9px; }
      .brand-name { font-size: 16px; }
      .main-nav { gap: 0; }
      .nav-link { width: auto; height: 64px; padding: 0 4px; justify-content: center; font-size: 11px; }
      .nav-link.active::after { right: 7px; left: 7px; }
      .nav-badge { position: absolute; top: 14px; right: 1px; font-size: 9px; }
      .topbar-actions { gap: 2px; }
      .profile-chip { padding: 4px 0; }
      .main-content { padding-top: 25px; }
      .page-header { display: block; margin-bottom: 18px; }
      h1 { font-size: 25px; }
      .search-row { display: grid; grid-template-columns: 1fr auto; }
      .filter-select { width: 100%; grid-column: 1 / -1; }
      .search-submit { min-width: 76px; }
      .search-result-row { display: block; }
      .result-hint { display: block; margin-top: 4px; }
      .list-toolbar { align-items: flex-start; }
      .list-controls { flex-wrap: wrap; justify-content: flex-end; }
      .view-toggle { display: none; }
      .job-card { padding: 17px 16px; }
      .job-side-top { display: block; }
      .job-posted { display: block; margin-top: 5px; }
      .card-actions { width: 100%; }
      .save-button, .apply-button { flex: 1; justify-content: center; }
      .notification-popover { top: 57px; right: 14px; width: min(320px, calc(100vw - 28px)); }
    }
</style>
