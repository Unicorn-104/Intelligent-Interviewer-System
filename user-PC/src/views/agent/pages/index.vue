<template>
<div class="app-shell">
    <AgentTopbar active="index" />

    <main class="main-content" id="dashboard">
      <section class="welcome-row" aria-labelledby="pageTitle">
        <div>
          <p class="eyebrow">TUESDAY · 2024年6月18日</p>
          <h1 id="pageTitle">早上好，晓雨</h1>
          <p class="welcome-subtitle">AI 已为你匹配今日 <strong>18 个新机会</strong>，其中 6 个与您的经历高度契合。</p>
        </div>
        <div class="search-box">
          <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.8" /><path d="m16 16 4.3 4.3" /></svg>
          <input id="jobSearch" type="search" placeholder="搜索职位、公司或关键词" aria-label="搜索职位、公司或关键词" />
          <button class="search-clear" id="searchClear" aria-label="清除搜索">×</button>
        </div>
      </section>

      <section class="dashboard-grid" aria-label="工作台摘要">
        <article class="panel application-panel" id="applications">
          <div class="panel-header">
            <div><h2 class="panel-title">我的投递进度摘要</h2><p class="panel-caption">持续跟进每一个值得期待的机会</p></div>
            <button class="text-button" id="viewAllApplications">查看全部 →</button>
          </div>
          <div class="application-overview">
            <div class="progress-ring" aria-label="进行中的投递 8 个">
              <svg viewBox="0 0 92 92" aria-hidden="true"><circle class="track" cx="46" cy="46" r="34" /><circle class="value" cx="46" cy="46" r="34" /></svg>
              <div class="progress-ring-label">8<small>进行中</small></div>
            </div>
            <div class="stat-copy">
              <strong>8 个投递</strong>
              <span>过去 30 天，你一共投递了 12 个岗位</span>
              <div class="stat-chips"><span class="stat-chip"><strong>2</strong>面试中</span><span class="stat-chip"><strong>4</strong>待反馈</span><span class="stat-chip"><strong>2</strong>已入库</span></div>
            </div>
          </div>
          <div class="latest-application">
            <p class="latest-label">最新进展</p>
            <div class="latest-main">
              <div class="company-logo">极氪</div>
              <div class="job-basic"><div class="job-title">高级产品经理 · 智能座舱</div><div class="job-company">极氪智能科技 · 杭州</div></div>
              <span class="status-pill">面试邀约</span>
            </div>
            <div class="latest-footer"><span class="time-note">更新于 6月17日 15:40</span><button class="outline-button" id="detailButton">查看详情</button></div>
          </div>
        </article>

        <article class="panel activity-panel">
          <div class="panel-header"><div><h2 class="panel-title">关注企业动态</h2><p class="panel-caption">你关注的企业有了新消息</p></div><button class="text-button" id="manageFollow">管理关注 →</button></div>
          <ul class="activity-list">
            <li class="activity-item"><span class="activity-dot"></span><div class="activity-body"><div class="activity-company">极氪智能科技 <span>招聘团队</span></div><p class="activity-content">发布了 3 个产品岗位，正在寻找热爱智能出行的产品人。</p><div class="activity-time">2 小时前</div></div></li>
            <li class="activity-item"><span class="activity-dot"></span><div class="activity-body"><div class="activity-company">阿里巴巴集团 <span>企业动态</span></div><p class="activity-content">杭州团队开放日即将开始，欢迎关注电商与 AI 方向的新机会。</p><div class="activity-time">昨天 18:20</div></div></li>
            <li class="activity-item"><span class="activity-dot"></span><div class="activity-body"><div class="activity-company">小红书 <span>招聘团队</span></div><p class="activity-content">为提升求职者体验，面试流程全面接入 AI 面试准备助手。</p><div class="activity-time">6月15日</div></div></li>
          </ul>
        </article>
      </section>

      <section class="jobs-section" id="jobs" aria-labelledby="jobsHeading">
        <div class="section-heading">
          <div><h2 id="jobsHeading">为你推荐的岗位</h2><p>基于你的经历、偏好与近期浏览行为智能匹配</p></div>
          <div class="jobs-controls"><select class="filter-select" id="jobFilter" aria-label="岗位排序"><option value="match">按匹配度排序</option><option value="salary">按薪资排序</option><option value="latest">按最新发布排序</option></select><button class="text-button" id="refreshJobs">换一批 ↻</button></div>
        </div>

        <div class="jobs-grid" id="jobsGrid">
          <article class="job-card" data-keywords="高级产品经理 极氪 智能座舱 杭州 汽车">
            <div class="job-card-top"><div class="company-logo">极氪</div><button class="bookmark-button" aria-label="收藏高级产品经理岗位" title="收藏岗位"><svg viewBox="0 0 24 24"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg></button></div>
            <h3>高级产品经理 · 智能座舱</h3><div class="job-card-company">极氪智能科技 · 杭州</div>
            <div class="job-card-meta"><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>3-5年</span><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h16" /></svg>本科</span></div>
            <div class="job-card-tags"><span class="match-tag">96%匹配</span><span class="urgent-tag">急招</span></div><div class="job-card-footer"><span class="salary">25-40K <small>· 14薪</small></span><button class="apply-button">立即投递</button></div>
          </article>

          <article class="job-card" data-keywords="产品负责人 阿里巴巴 AI 电商 杭州">
            <div class="job-card-top"><div class="company-logo orange">阿里</div><button class="bookmark-button" aria-label="收藏产品负责人岗位" title="收藏岗位"><svg viewBox="0 0 24 24"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg></button></div>
            <h3>产品负责人 · AI 电商</h3><div class="job-card-company">阿里巴巴集团 · 杭州</div>
            <div class="job-card-meta"><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>5-8年</span><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h16" /></svg>本科</span></div>
            <div class="job-card-tags"><span class="match-tag">94%匹配</span></div><div class="job-card-footer"><span class="salary">35-55K <small>· 16薪</small></span><button class="apply-button">立即投递</button></div>
          </article>

          <article class="job-card" data-keywords="用户增长负责人 小红书 社区 上海 运营">
            <div class="job-card-top"><div class="company-logo green">小红书</div><button class="bookmark-button" aria-label="收藏用户增长负责人岗位" title="收藏岗位"><svg viewBox="0 0 24 24"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg></button></div>
            <h3>用户增长负责人 · 社区</h3><div class="job-card-company">小红书 · 上海</div>
            <div class="job-card-meta"><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>3-5年</span><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h16" /></svg>本科</span></div>
            <div class="job-card-tags"><span class="match-tag">92%匹配</span><span class="urgent-tag">急招</span></div><div class="job-card-footer"><span class="salary">28-45K <small>· 15薪</small></span><button class="apply-button">立即投递</button></div>
          </article>

          <article class="job-card" data-keywords="体验设计负责人 网易 设计 杭州 用户体验">
            <div class="job-card-top"><div class="company-logo">网易</div><button class="bookmark-button" aria-label="收藏体验设计负责人岗位" title="收藏岗位"><svg viewBox="0 0 24 24"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg></button></div>
            <h3>体验设计负责人 · 游戏事业群</h3><div class="job-card-company">网易 · 杭州</div>
            <div class="job-card-meta"><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>5-8年</span><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h16" /></svg>本科</span></div>
            <div class="job-card-tags"><span class="match-tag">89%匹配</span></div><div class="job-card-footer"><span class="salary">30-50K <small>· 15薪</small></span><button class="apply-button">立即投递</button></div>
          </article>

          <article class="job-card" data-keywords="商业产品经理 字节跳动 抖音 北京 商业化">
            <div class="job-card-top"><div class="company-logo orange">字节</div><button class="bookmark-button" aria-label="收藏商业产品经理岗位" title="收藏岗位"><svg viewBox="0 0 24 24"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg></button></div>
            <h3>商业产品经理 · 抖音电商</h3><div class="job-card-company">字节跳动 · 北京</div>
            <div class="job-card-meta"><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>3-5年</span><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h16" /></svg>本科</span></div>
            <div class="job-card-tags"><span class="match-tag">87%匹配</span><span class="urgent-tag">急招</span></div><div class="job-card-footer"><span class="salary">30-45K <small>· 15薪</small></span><button class="apply-button">立即投递</button></div>
          </article>

          <article class="job-card" data-keywords="策略产品经理 美团 本地生活 北京 策略">
            <div class="job-card-top"><div class="company-logo green">美团</div><button class="bookmark-button" aria-label="收藏策略产品经理岗位" title="收藏岗位"><svg viewBox="0 0 24 24"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg></button></div>
            <h3>策略产品经理 · 本地生活</h3><div class="job-card-company">美团 · 北京</div>
            <div class="job-card-meta"><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>3-5年</span><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h16" /></svg>本科</span></div>
            <div class="job-card-tags"><span class="match-tag">85%匹配</span></div><div class="job-card-footer"><span class="salary">25-38K <small>· 15薪</small></span><button class="apply-button">立即投递</button></div>
          </article>
          <div class="empty-state" id="emptyState">暂未找到匹配的岗位，换个关键词试试吧。</div>
        </div>
      </section>
    </main>
  </div>

  <div class="modal-backdrop" id="detailModal" role="presentation">
    <section class="detail-modal" role="dialog" aria-modal="true" aria-labelledby="modalTitle">
      <div class="modal-head"><div class="modal-title-wrap"><div class="company-logo">极氪</div><div><h2 class="modal-title" id="modalTitle">高级产品经理 · 智能座舱</h2><div class="modal-company">极氪智能科技 · 杭州</div></div></div><button class="modal-close" id="modalClose" aria-label="关闭详情">×</button></div>
      <div class="modal-body"><div class="status-pill">当前状态：面试邀约</div><div class="progress-track"><div class="progress-step done"><div class="step-dot">✓</div><span>已投递</span></div><div class="progress-step done"><div class="step-dot">✓</div><span>简历筛选</span></div><div class="progress-step current"><div class="step-dot">3</div><span>面试邀约</span></div><div class="progress-step"><div class="step-dot">4</div><span>面试完成</span></div></div><p class="modal-note">招聘团队已于 6月17日发来面试邀请，请在 6月20日前选择合适的时间段。AI 面试准备助手已为你生成专属练习题。</p></div>
    </section>
  </div>

  <div class="toast" id="toast" role="status"><span>✓</span><span id="toastMessage">操作成功</span></div>
</template>

<script setup>
import { onMounted } from 'vue'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'


onMounted(() => {
  // 页面交互：通知面板、岗位搜索、收藏、投递和投递详情弹窗
      const toast = document.getElementById('toast');
      const toastMessage = document.getElementById('toastMessage');
      let toastTimer;
  
      function showToast(message) {
        toastMessage.textContent = message;
        toast.classList.add('show');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => toast.classList.remove('show'), 2600);
      }
  
  
      // 搜索过滤岗位卡片
      const searchInput = document.getElementById('jobSearch');
      const searchClear = document.getElementById('searchClear');
      const jobCards = [...document.querySelectorAll('.job-card')];
      const emptyState = document.getElementById('emptyState');
  
      function filterJobs() {
        const keyword = searchInput.value.trim().toLowerCase();
        let visibleCount = 0;
        jobCards.forEach((card) => {
          const matched = !keyword || card.dataset.keywords.toLowerCase().includes(keyword);
          card.classList.toggle('hidden', !matched);
          if (matched) visibleCount += 1;
        });
        emptyState.classList.toggle('visible', visibleCount === 0);
        searchClear.classList.toggle('visible', Boolean(keyword));
      }
  
      searchInput.addEventListener('input', filterJobs);
      searchClear.addEventListener('click', () => { searchInput.value = ''; filterJobs(); searchInput.focus(); });
  
      // 收藏与立即投递按钮的状态反馈
      document.querySelectorAll('.bookmark-button').forEach((button) => {
        button.addEventListener('click', () => {
          const saved = button.classList.toggle('saved');
          button.setAttribute('aria-label', saved ? '取消收藏岗位' : '收藏岗位');
          showToast(saved ? '已收藏该岗位' : '已取消收藏');
        });
      });
  
      const recommendedJobIds = ['ai-product', 'ai-commerce', 'growth', 'experience-design', 'commercial', 'strategy'];
      jobCards.forEach((card,index)=>{
        const jobId=recommendedJobIds[index];
        card.dataset.jobId=jobId;card.setAttribute('tabindex','0');card.setAttribute('role','link');card.setAttribute('aria-label',`查看${card.querySelector('h3').textContent}详情`);
        const openDetail=()=>{window.__agentNavigate(`/agent/job-detail?id=${encodeURIComponent(jobId)}`)};
        card.addEventListener('click',(event)=>{if(!event.target.closest('button,a'))openDetail()});
        card.addEventListener('keydown',(event)=>{if((event.key==='Enter'||event.key===' ')&&!event.target.closest('button,a')){event.preventDefault();openDetail()}});
      });
      document.querySelectorAll('.apply-button').forEach((button, index) => {
        button.addEventListener('click', () => { window.__agentNavigate(`/agent/resume-select?job=${recommendedJobIds[index]}`); });
      });
  
      const detailModal = document.getElementById('detailModal');
      const closeModal = () => detailModal.classList.remove('open');
      document.getElementById('detailButton').addEventListener('click', () => detailModal.classList.add('open'));
      document.getElementById('modalClose').addEventListener('click', closeModal);
      detailModal.addEventListener('click', (event) => { if (event.target === detailModal) closeModal(); });
      document.addEventListener('keydown', (event) => { if (event.key === 'Escape') closeModal(); });
  
      document.getElementById('viewAllApplications').addEventListener('click', () => { window.__agentNavigate('/agent/applications'); });
      document.getElementById('manageFollow').addEventListener('click', () => showToast('关注企业管理已准备好'));
      document.getElementById('refreshJobs').addEventListener('click', () => showToast('已刷新推荐岗位'));
      document.getElementById('jobFilter').addEventListener('change', (event) => showToast(`已切换为${event.target.options[event.target.selectedIndex].text}`));
})
</script>

<style>
:root {
      --primary: #1A3C6E;
      --primary-deep: #102D53;
      --interactive: #2B7FFF;
      --interactive-soft: #EAF2FF;
      --bg: #F5F7FA;
      --card: #FFFFFF;
      --text: #172B4D;
      --muted: #6B7A90;
      --line: #E6EBF2;
      --success: #1B9A72;
      --success-soft: #E7F7F1;
      --warning: #D7811D;
      --warning-soft: #FFF4E5;
      --shadow: 0 8px 24px rgba(26, 60, 110, 0.07);
      --radius: 12px;
    }

    * { box-sizing: border-box; }

    html { scroll-behavior: smooth; }

    body {
      margin: 0;
      color: var(--text);
      background: var(--bg);
      font-family: "PingFang SC", "Microsoft YaHei", system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 14px;
      line-height: 1.5;
    }

    button, input { font: inherit; }

    button { cursor: pointer; }

    .app-shell { min-height: 100vh; }

    /* 顶部导航栏 */
    .topbar {
      position: sticky;
      top: 0;
      z-index: 20;
      height: 72px;
      display: flex;
      align-items: center;
      border-bottom: 1px solid rgba(230, 235, 242, 0.9);
      background: rgba(255, 255, 255, 0.96);
      backdrop-filter: blur(12px);
    }

    .topbar-inner {
      width: min(1240px, calc(100% - 48px));
      margin: 0 auto;
      display: flex;
      align-items: center;
      gap: 32px;
    }

    .brand {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      color: var(--primary);
      text-decoration: none;
      white-space: nowrap;
    }

    .brand-mark {
      width: 34px;
      height: 34px;
      display: grid;
      place-items: center;
      border-radius: 9px;
      color: #fff;
      background: linear-gradient(145deg, #2B7FFF, #1A3C6E);
      box-shadow: 0 5px 12px rgba(43, 127, 255, 0.22);
      font-size: 17px;
      font-weight: 800;
      letter-spacing: -1px;
    }

    .brand-name { font-weight: 800; font-size: 18px; letter-spacing: 0.2px; }
    .brand-tag { margin-left: 2px; color: var(--muted); font-size: 11px; font-weight: 500; }

    .main-nav { display: flex; align-items: center; gap: 5px; height: 100%; }

    .nav-link {
      position: relative;
      height: 72px;
      display: inline-flex;
      align-items: center;
      padding: 0 15px;
      border: 0;
      color: var(--muted);
      background: transparent;
      font-size: 14px;
      text-decoration: none;
      transition: color .2s ease;
    }

    .nav-link:hover, .nav-link.active { color: var(--primary); }
    .nav-link.active { font-weight: 700; }
    .nav-link.active::after {
      content: "";
      position: absolute;
      right: 15px;
      bottom: 0;
      left: 15px;
      height: 3px;
      border-radius: 3px 3px 0 0;
      background: var(--interactive);
    }

    .nav-badge { min-width: 17px; height: 17px; margin-left: 6px; padding: 0 5px; display: inline-grid; place-items: center; border-radius: 99px; color: #fff; background: #F05C63; font-size: 10px; line-height: 1; }

    .topbar-actions { margin-left: auto; display: flex; align-items: center; gap: 18px; }

    .icon-button {
      position: relative;
      width: 36px;
      height: 36px;
      display: grid;
      place-items: center;
      border: 0;
      border-radius: 9px;
      color: var(--muted);
      background: transparent;
      transition: background .2s, color .2s;
    }

    .icon-button:hover { color: var(--primary); background: var(--interactive-soft); }
    .icon-button svg { width: 19px; height: 19px; stroke: currentColor; fill: none; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
    .notification-dot { position: absolute; top: 6px; right: 6px; width: 7px; height: 7px; border: 2px solid #fff; border-radius: 50%; background: #F05C63; }

    .profile-chip { display: flex; align-items: center; gap: 9px; padding: 4px 0 4px 5px; border: 0; color: var(--text); background: transparent; }
    .avatar { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 50%; color: #fff; background: linear-gradient(135deg, #8EA9D1, #5377AE); font-size: 13px; font-weight: 700; }
    .profile-meta { text-align: left; line-height: 1.25; }
    .profile-name { display: block; font-weight: 700; }
    .profile-role { display: block; margin-top: 2px; color: var(--muted); font-size: 11px; }
    .profile-chevron { width: 15px; height: 15px; margin-left: 1px; color: var(--muted); }

    .main-content { width: min(1240px, calc(100% - 48px)); margin: 0 auto; padding: 34px 0 56px; }

    /* 页面问候区 */
    .welcome-row { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; margin-bottom: 26px; }
    .eyebrow { margin: 0 0 7px; color: var(--interactive); font-size: 12px; font-weight: 700; letter-spacing: .8px; }
    h1 { margin: 0; color: var(--primary); font-size: clamp(24px, 3vw, 30px); line-height: 1.25; letter-spacing: -.4px; }
    .welcome-subtitle { margin: 9px 0 0; color: var(--muted); font-size: 14px; }
    .welcome-subtitle strong { color: var(--primary); font-weight: 700; }

    .search-box { width: min(320px, 100%); height: 42px; position: relative; }
    .search-box input { width: 100%; height: 100%; padding: 0 42px 0 40px; border: 1px solid var(--line); border-radius: 9px; outline: 0; color: var(--text); background: var(--card); transition: border .2s, box-shadow .2s; }
    .search-box input:focus { border-color: rgba(43, 127, 255, .7); box-shadow: 0 0 0 3px rgba(43, 127, 255, .12); }
    .search-box svg { position: absolute; top: 12px; left: 14px; width: 18px; height: 18px; color: var(--muted); stroke: currentColor; fill: none; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; pointer-events: none; }
    .search-clear { display: none; position: absolute; top: 7px; right: 8px; width: 28px; height: 28px; border: 0; border-radius: 6px; color: var(--muted); background: transparent; }
    .search-clear.visible { display: block; }

    .dashboard-grid { display: grid; grid-template-columns: minmax(0, 1.06fr) minmax(0, .94fr); gap: 20px; margin-bottom: 25px; }

    .panel { border: 1px solid var(--line); border-radius: var(--radius); background: var(--card); box-shadow: var(--shadow); }
    .panel-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; padding: 22px 24px 18px; }
    .panel-title { margin: 0; color: var(--primary); font-size: 16px; font-weight: 800; }
    .panel-caption { margin: 5px 0 0; color: var(--muted); font-size: 12px; }
    .text-button { padding: 2px 0; border: 0; color: var(--interactive); background: transparent; font-size: 12px; font-weight: 700; white-space: nowrap; }
    .text-button:hover { color: var(--primary); }

    /* 投递摘要 */
    .application-panel { min-height: 280px; }
    .application-overview { display: flex; align-items: center; gap: 22px; padding: 1px 24px 18px; }
    .progress-ring { position: relative; width: 92px; height: 92px; flex: 0 0 auto; }
    .progress-ring svg { width: 100%; height: 100%; transform: rotate(-90deg); }
    .progress-ring circle { fill: none; stroke-width: 7; }
    .progress-ring .track { stroke: #EDF1F6; }
    .progress-ring .value { stroke: var(--interactive); stroke-linecap: round; stroke-dasharray: 213.6; stroke-dashoffset: 58.9; }
    .progress-ring-label { position: absolute; inset: 0; display: grid; place-items: center; color: var(--primary); font-size: 22px; font-weight: 800; }
    .progress-ring-label small { margin-top: -25px; color: var(--muted); font-size: 10px; font-weight: 500; }
    .stat-copy strong { display: block; color: var(--primary); font-size: 25px; line-height: 1.15; }
    .stat-copy span { display: block; margin-top: 5px; color: var(--muted); font-size: 12px; }
    .stat-chips { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 12px; }
    .stat-chip { padding: 5px 9px; border-radius: 6px; color: var(--muted); background: #F7F9FC; font-size: 11px; }
    .stat-chip strong { display: inline; margin-right: 3px; color: var(--primary); font-size: 12px; }

    .latest-application { margin: 0 24px 22px; padding: 15px 16px; border: 1px solid #E6ECF5; border-radius: 9px; background: #FBFCFE; }
    .latest-label { margin: 0 0 11px; color: var(--muted); font-size: 11px; font-weight: 700; letter-spacing: .4px; }
    .latest-main { display: flex; align-items: center; gap: 13px; }
    .company-logo { width: 40px; height: 40px; display: grid; place-items: center; flex: 0 0 auto; border-radius: 9px; color: var(--primary); background: #EAF2FF; font-size: 13px; font-weight: 800; }
    .company-logo.orange { color: #9A5810; background: #FFF0D8; }
    .company-logo.green { color: #147156; background: #E5F7F0; }
    .job-basic { min-width: 0; flex: 1; }
    .job-title { overflow: hidden; color: var(--primary); font-size: 14px; font-weight: 700; text-overflow: ellipsis; white-space: nowrap; }
    .job-company { margin-top: 3px; color: var(--muted); font-size: 12px; }
    .status-pill { flex: 0 0 auto; padding: 5px 9px; border-radius: 6px; color: var(--interactive); background: var(--interactive-soft); font-size: 11px; font-weight: 700; }
    .latest-footer { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-top: 13px; padding-top: 12px; border-top: 1px dashed #DCE4EF; }
    .time-note { color: var(--muted); font-size: 11px; }
    .outline-button { display: inline-flex; align-items: center; justify-content: center; min-height: 30px; padding: 0 12px; border: 1px solid #BCD1ED; border-radius: 6px; color: var(--interactive); background: #fff; font-size: 12px; font-weight: 700; transition: all .2s; }
    .outline-button:hover { border-color: var(--interactive); background: var(--interactive-soft); }

    /* 企业动态 */
    .activity-panel { min-height: 280px; }
    .activity-list { list-style: none; margin: 0; padding: 0 24px 17px; }
    .activity-item { display: flex; gap: 12px; padding: 0 0 16px; }
    .activity-item + .activity-item { padding-top: 16px; border-top: 1px solid #F0F2F6; }
    .activity-dot { position: relative; width: 9px; flex: 0 0 9px; margin-top: 5px; }
    .activity-dot::before { content: ""; position: absolute; left: 0; width: 9px; height: 9px; border-radius: 50%; background: var(--interactive); box-shadow: 0 0 0 4px var(--interactive-soft); }
    .activity-item:nth-child(2) .activity-dot::before { background: #35A77F; box-shadow: 0 0 0 4px var(--success-soft); }
    .activity-item:nth-child(3) .activity-dot::before { background: #E19A38; box-shadow: 0 0 0 4px var(--warning-soft); }
    .activity-body { min-width: 0; flex: 1; }
    .activity-company { color: var(--primary); font-size: 13px; font-weight: 700; }
    .activity-company span { margin-left: 6px; color: var(--muted); font-size: 11px; font-weight: 400; }
    .activity-content { margin: 4px 0 0; color: #4D5F78; font-size: 12px; line-height: 1.55; }
    .activity-time { margin-top: 6px; color: #9AA7B8; font-size: 11px; }

    /* 推荐岗位区域 */
    .jobs-section { margin-top: 3px; }
    .section-heading { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; margin: 0 0 15px; }
    .section-heading h2 { margin: 0; color: var(--primary); font-size: 18px; }
    .section-heading p { margin: 5px 0 0; color: var(--muted); font-size: 12px; }
    .jobs-controls { display: flex; align-items: center; gap: 10px; }
    .filter-select { height: 34px; padding: 0 28px 0 10px; border: 1px solid var(--line); border-radius: 7px; color: var(--muted); background: #fff; font-size: 12px; }
    .jobs-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }
    .job-card { position: relative; display: flex; min-height: 224px; flex-direction: column; padding: 18px; border: 1px solid var(--line); border-radius: 10px; background: var(--card); box-shadow: 0 4px 14px rgba(26, 60, 110, .04); transition: transform .2s ease, box-shadow .2s ease, border .2s; cursor: pointer; }
    .job-card:hover { transform: translateY(-2px); border-color: #D3E1F4; box-shadow: 0 10px 22px rgba(26, 60, 110, .09); }
    .job-card.hidden { display: none; }
    .job-card-top { display: flex; align-items: flex-start; justify-content: space-between; gap: 10px; }
    .job-card .company-logo { width: 42px; height: 42px; border-radius: 10px; }
    .bookmark-button { width: 30px; height: 30px; display: grid; place-items: center; border: 0; border-radius: 6px; color: #A7B2C1; background: transparent; }
    .bookmark-button:hover, .bookmark-button.saved { color: var(--interactive); background: var(--interactive-soft); }
    .bookmark-button svg { width: 17px; height: 17px; fill: currentColor; stroke: currentColor; stroke-width: 1.5; }
    .job-card h3 { overflow: hidden; margin: 14px 0 3px; color: var(--primary); font-size: 15px; text-overflow: ellipsis; white-space: nowrap; }
    .job-card-company { color: var(--muted); font-size: 12px; }
    .job-card-meta { display: flex; flex-wrap: wrap; gap: 7px 13px; margin-top: 13px; color: #4F617A; font-size: 12px; }
    .meta-item { display: inline-flex; align-items: center; gap: 5px; }
    .meta-item svg { width: 14px; height: 14px; color: #8C9BB0; stroke: currentColor; fill: none; stroke-width: 1.7; stroke-linecap: round; stroke-linejoin: round; }
    .job-card-tags { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 14px; }
    .match-tag { padding: 4px 7px; border-radius: 5px; color: var(--interactive); background: var(--interactive-soft); font-size: 11px; font-weight: 700; }
    .urgent-tag { padding: 4px 7px; border-radius: 5px; color: #B36512; background: var(--warning-soft); font-size: 11px; font-weight: 700; }
    .job-card-footer { display: flex; align-items: center; justify-content: space-between; gap: 10px; margin-top: auto; padding-top: 15px; }
    .salary { color: var(--primary); font-size: 13px; font-weight: 800; }
    .salary small { color: var(--muted); font-size: 11px; font-weight: 400; }
    .apply-button { min-width: 72px; height: 32px; padding: 0 12px; border: 0; border-radius: 6px; color: #fff; background: var(--interactive); font-size: 12px; font-weight: 700; transition: background .2s, transform .2s; }
    .apply-button:hover { background: #1769DB; transform: translateY(-1px); }
    .apply-button.applied { color: var(--success); background: var(--success-soft); }
    .empty-state { grid-column: 1 / -1; display: none; padding: 34px; border: 1px dashed #CDD9E8; border-radius: 10px; color: var(--muted); background: #fff; text-align: center; }
    .empty-state.visible { display: block; }

    /* 通知浮层和详情弹窗 */
    .notification-popover { position: fixed; z-index: 30; top: 63px; right: max(24px, calc((100vw - 1240px) / 2)); width: 320px; display: none; border: 1px solid var(--line); border-radius: 10px; background: #fff; box-shadow: 0 16px 38px rgba(23, 43, 77, .16); overflow: hidden; }
    .notification-popover.open { display: block; animation: popIn .16s ease-out; }
    @keyframes popIn { from { opacity: 0; transform: translateY(-5px); } to { opacity: 1; transform: translateY(0); } }
    .popover-head { display: flex; align-items: center; justify-content: space-between; padding: 15px 16px; border-bottom: 1px solid var(--line); }
    .popover-head strong { color: var(--primary); font-size: 14px; }
    .popover-head button { padding: 0; border: 0; color: var(--interactive); background: transparent; font-size: 11px; }
    .notification-item { display: flex; gap: 10px; padding: 13px 16px; border-bottom: 1px solid #F1F3F7; }
    .notification-icon { width: 28px; height: 28px; display: grid; place-items: center; flex: 0 0 auto; border-radius: 7px; color: var(--interactive); background: var(--interactive-soft); font-size: 13px; font-weight: 800; }
    .notification-item p { margin: 0; color: var(--text); font-size: 12px; line-height: 1.45; }
    .notification-item time { display: block; margin-top: 4px; color: #9AA7B8; font-size: 10px; }
    .modal-backdrop { position: fixed; z-index: 40; inset: 0; display: none; align-items: center; justify-content: center; padding: 22px; background: rgba(16, 45, 83, .32); }
    .modal-backdrop.open { display: flex; }
    .detail-modal { width: min(520px, 100%); border-radius: 12px; background: #fff; box-shadow: 0 22px 50px rgba(16, 45, 83, .2); overflow: hidden; }
    .modal-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; padding: 22px 24px; border-bottom: 1px solid var(--line); }
    .modal-title-wrap { display: flex; align-items: center; gap: 13px; }
    .modal-title { margin: 0; color: var(--primary); font-size: 17px; }
    .modal-company { margin-top: 3px; color: var(--muted); font-size: 12px; }
    .modal-close { width: 30px; height: 30px; display: grid; place-items: center; border: 0; border-radius: 6px; color: var(--muted); background: transparent; font-size: 20px; }
    .modal-close:hover { background: #F2F5F9; }
    .modal-body { padding: 21px 24px 24px; }
    .progress-track { display: flex; align-items: flex-start; justify-content: space-between; gap: 0; margin: 15px 0 24px; }
    .progress-step { position: relative; flex: 1; text-align: center; }
    .progress-step::before { content: ""; position: absolute; z-index: 0; top: 9px; right: 50%; left: -50%; height: 2px; background: #E5EAF2; }
    .progress-step:first-child::before { display: none; }
    .progress-step.done::before, .progress-step.current::before { background: var(--interactive); }
    .step-dot { position: relative; z-index: 1; width: 20px; height: 20px; display: grid; place-items: center; margin: 0 auto 8px; border: 3px solid #E5EAF2; border-radius: 50%; color: #fff; background: #fff; font-size: 10px; }
    .progress-step.done .step-dot, .progress-step.current .step-dot { border-color: var(--interactive); background: var(--interactive); }
    .progress-step span { color: var(--muted); font-size: 11px; }
    .progress-step.current span { color: var(--interactive); font-weight: 700; }
    .modal-note { margin: 0; padding: 12px 13px; border-radius: 7px; color: #53647B; background: #F7F9FC; font-size: 12px; line-height: 1.6; }

    .toast { position: fixed; z-index: 60; right: 24px; bottom: 24px; display: flex; align-items: center; gap: 9px; max-width: calc(100vw - 48px); padding: 11px 15px; border: 1px solid #CCE9DE; border-radius: 8px; color: #176B50; background: #F2FBF7; box-shadow: 0 10px 25px rgba(23, 43, 77, .1); font-size: 12px; opacity: 0; transform: translateY(10px); pointer-events: none; transition: opacity .2s, transform .2s; }
    .toast.show { opacity: 1; transform: translateY(0); }

    @media (max-width: 980px) {
      .topbar-inner, .main-content { width: min(100% - 32px, 760px); }
      .topbar-inner { gap: 15px; }
      .brand-tag, .profile-meta, .profile-chevron { display: none; }
      .main-nav { margin-left: auto; }
      .nav-link { padding: 0 9px; }
      .nav-link.active::after { right: 9px; left: 9px; }
      .topbar-actions { margin-left: 0; }
      .dashboard-grid { grid-template-columns: 1fr; }
      .jobs-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    }

    @media (max-width: 640px) {
      .topbar { height: 64px; }
      .topbar-inner, .main-content { width: calc(100% - 28px); }
      .topbar-inner { gap: 9px; }
      .brand-name { font-size: 16px; }
      .main-nav { gap: 0; }
      .nav-link { width: 38px; height: 64px; padding: 0; justify-content: center; font-size: 0; }
      .nav-link::before { font-size: 17px; }
      .nav-link:nth-child(1)::before { content: "⌂"; }
      .nav-link:nth-child(2)::before { content: "▣"; }
      .nav-link:nth-child(3)::before { content: "◷"; }
      .nav-link:nth-child(4)::before { content: "◎"; }
      .nav-link.active::after { right: 7px; left: 7px; }
      .nav-badge { position: absolute; top: 14px; right: 1px; font-size: 9px; }
      .topbar-actions { gap: 2px; }
      .profile-chip { padding: 4px 0; }
      .main-content { padding-top: 25px; }
      .welcome-row { display: block; }
      .search-box { width: 100%; margin-top: 18px; }
      .application-overview { gap: 15px; padding-right: 18px; padding-left: 18px; }
      .latest-application { margin-right: 18px; margin-left: 18px; }
      .panel-header { padding-right: 18px; padding-left: 18px; }
      .activity-list { padding-right: 18px; padding-left: 18px; }
      .section-heading { display: block; }
      .jobs-controls { margin-top: 12px; }
      .jobs-grid { grid-template-columns: 1fr; }
      .job-card { min-height: 210px; }
      .notification-popover { top: 57px; right: 14px; width: min(320px, calc(100vw - 28px)); }
    }
    .job-card:focus-visible{outline:3px solid rgba(43,127,255,.22);outline-offset:3px}.job-card .bookmark-button,.job-card .apply-button{cursor:pointer}
</style>
