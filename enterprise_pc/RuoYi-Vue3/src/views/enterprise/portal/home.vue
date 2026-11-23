<template>
  <div class="home">
    <section class="hero">
      <div class="hero-inner">
        <div class="hero-copy">
          <p class="eyebrow">企业招聘管理平台</p>
          <h1>让企业招聘更智能、更高效</h1>
          <p class="desc">
            从岗位发布、AI 简历筛选到面试安排、在线笔试与人才沉淀，一站式完成企业招聘全流程。
          </p>
          <div class="hero-actions">
            <router-link class="btn primary lg" to="/enterprise/register">企业入驻注册</router-link>
            <router-link class="btn lg" to="/enterprise/login">登录企业中心</router-link>
          </div>
          <p class="hero-tip">提交入驻申请后由平台审核，审核通过即可使用完整招聘功能。</p>
        </div>
        <div class="hero-panel">
          <div class="panel-head">
            <span class="dot"></span>
            <span>招聘工作台</span>
          </div>
          <div class="panel-row">
            <span>岗位管理</span>
            <strong>发布 / 编辑 / 下架</strong>
          </div>
          <div class="panel-row">
            <span>AI 简历筛选</span>
            <strong>自动评分与排序</strong>
          </div>
          <div class="panel-row">
            <span>面试安排</span>
            <strong>日程与面试官协同</strong>
          </div>
          <div class="panel-row">
            <span>在线笔试</span>
            <strong>组卷 / 监考 / 阅卷</strong>
          </div>
          <div class="panel-row">
            <span>人才库</span>
            <strong>候选人长期沉淀</strong>
          </div>
        </div>
      </div>
    </section>

    <section class="section">
      <div class="section-head">
        <h2>覆盖招聘全流程</h2>
        <p>面向 HR、面试官与招聘负责人，统一管理职位、候选人与面试进度。</p>
      </div>
      <div class="feature-grid">
        <div v-for="item in features" :key="item.title" class="feature-card">
          <span class="feature-index">{{ item.index }}</span>
          <h3>{{ item.title }}</h3>
          <p>{{ item.desc }}</p>
        </div>
      </div>
      <div class="section-more">
        <router-link class="link" to="/enterprise/portal/features">了解全部平台能力 →</router-link>
      </div>
    </section>

    <section class="section workflow">
      <div class="section-head">
        <h2>企业入驻流程</h2>
        <p>四步完成入驻，审核通过后即可进入企业招聘中心。</p>
      </div>
      <div class="steps">
        <div v-for="(step, i) in steps" :key="step.title" class="step">
          <span class="step-no">{{ i + 1 }}</span>
          <h3>{{ step.title }}</h3>
          <p>{{ step.desc }}</p>
        </div>
      </div>
      <div class="section-more">
        <router-link class="link" to="/enterprise/portal/onboarding">查看入驻材料与常见问题 →</router-link>
      </div>
    </section>

    <section class="cta">
      <div class="cta-inner">
        <div>
          <h2>开始搭建您的企业招聘工作台</h2>
          <p>注册企业账号，提交入驻申请，平台审核通过后即可使用。</p>
        </div>
        <div class="cta-actions">
          <router-link class="btn primary lg" to="/enterprise/register">立即注册</router-link>
          <router-link class="btn lg" to="/enterprise/login">已有账号登录</router-link>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup>
const features = [
  { index: '01', title: '岗位管理', desc: '集中发布、编辑与下架职位，维护岗位职责、要求与招聘流程配置。' },
  { index: '02', title: 'AI 简历筛选', desc: '按岗位要求自动解析简历并给出匹配评分，帮助 HR 快速定位合适候选人。' },
  { index: '03', title: '面试安排', desc: '统一管理面试日程、面试官与候选人时间，支持改期审批与面试提醒。' },
  { index: '04', title: '在线笔试', desc: '灵活组卷、在线监考与自动阅卷，笔面结果统一沉淀到候选人档案。' },
  { index: '05', title: '人才库', desc: '沉淀历史候选人与面试评价，支持标签检索，为后续岗位复用人才。' },
  { index: '06', title: '招聘数据看板', desc: '实时查看岗位、候选人、面试与 Offer 进展，掌握招聘整体效率。' }
]

const steps = [
  { title: '提交企业注册', desc: '填写企业名称、联系人与登录账号，提交入驻申请。' },
  { title: '平台审核', desc: '平台核验企业信息，审核通过后绑定企业账号。' },
  { title: '配置招聘流程', desc: '创建部门与成员，配置岗位流程、消息模板与面试集成。' },
  { title: '开始招聘', desc: '发布岗位、筛选简历、安排面试与笔试，推进候选人至 Offer。' }
]
</script>

<style lang="scss" scoped>
.hero {
  background: linear-gradient(135deg, #1e3fae 0%, #2f6bff 55%, #6b9bff 100%);
  color: #fff;
  padding: 64px 20px 72px;
}
.hero-inner {
  max-width: 1180px;
  margin: 0 auto;
  display: grid;
  grid-template-columns: 1.15fr 0.85fr;
  gap: 48px;
  align-items: center;
}
.eyebrow {
  margin: 0 0 14px;
  font-size: 13px;
  letter-spacing: 2px;
  color: rgba(255, 255, 255, 0.75);
}
.hero-copy h1 {
  margin: 0 0 18px;
  font-size: 38px;
  line-height: 1.3;
}
.desc {
  margin: 0 0 28px;
  font-size: 16px;
  line-height: 1.8;
  color: rgba(255, 255, 255, 0.86);
  max-width: 560px;
}
.hero-actions {
  display: flex;
  gap: 14px;
  flex-wrap: wrap;
}
.hero-tip {
  margin: 18px 0 0;
  font-size: 13px;
  color: rgba(255, 255, 255, 0.66);
}
.hero-panel {
  background: rgba(255, 255, 255, 0.12);
  border: 1px solid rgba(255, 255, 255, 0.22);
  border-radius: 14px;
  padding: 20px 22px;
  backdrop-filter: blur(6px);
}
.panel-head {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  padding-bottom: 14px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.18);
  .dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #7ef0b2;
  }
}
.panel-row {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  padding: 13px 0;
  font-size: 14px;
  border-bottom: 1px dashed rgba(255, 255, 255, 0.14);
  &:last-child {
    border-bottom: none;
  }
  span {
    color: rgba(255, 255, 255, 0.75);
  }
  strong {
    font-weight: 500;
    color: #fff;
  }
}
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 9px 20px;
  border-radius: 8px;
  font-size: 14px;
  text-decoration: none;
  color: #2f6bff;
  border: 1px solid #c8d7ff;
  background: #fff;
  &.primary {
    background: #fff;
    border-color: #fff;
    color: #2f6bff;
    font-weight: 600;
  }
  &.lg {
    padding: 12px 26px;
    font-size: 15px;
  }
}
.hero .btn:not(.primary) {
  background: transparent;
  border-color: rgba(255, 255, 255, 0.5);
  color: #fff;
}
.section {
  max-width: 1180px;
  margin: 0 auto;
  padding: 56px 20px 12px;
}
.section-head {
  margin-bottom: 26px;
  h2 {
    margin: 0 0 10px;
    font-size: 24px;
  }
  p {
    margin: 0;
    color: #6b7688;
    font-size: 14px;
  }
}
.feature-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 18px;
}
.feature-card {
  background: #fff;
  border: 1px solid #e8ecf2;
  border-radius: 12px;
  padding: 22px;
  .feature-index {
    display: inline-block;
    font-size: 13px;
    font-weight: 700;
    color: #2f6bff;
    background: #eef3ff;
    border-radius: 6px;
    padding: 3px 8px;
    margin-bottom: 14px;
  }
  h3 {
    margin: 0 0 8px;
    font-size: 17px;
  }
  p {
    margin: 0;
    color: #6b7688;
    font-size: 14px;
    line-height: 1.7;
  }
}
.section-more {
  margin-top: 18px;
  text-align: right;
  .link {
    color: #2f6bff;
    text-decoration: none;
    font-size: 14px;
  }
}
.workflow {
  padding-bottom: 56px;
}
.steps {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}
.step {
  background: #fff;
  border: 1px solid #e8ecf2;
  border-radius: 12px;
  padding: 20px;
  .step-no {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 30px;
    height: 30px;
    border-radius: 50%;
    background: #2f6bff;
    color: #fff;
    font-size: 14px;
    font-weight: 600;
    margin-bottom: 14px;
  }
  h3 {
    margin: 0 0 8px;
    font-size: 16px;
  }
  p {
    margin: 0;
    color: #6b7688;
    font-size: 13px;
    line-height: 1.7;
  }
}
.cta {
  background: #eef3ff;
  padding: 48px 20px;
}
.cta-inner {
  max-width: 1180px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
  h2 {
    margin: 0 0 10px;
    font-size: 24px;
  }
  p {
    margin: 0;
    color: #5a6577;
    font-size: 14px;
  }
}
.cta-actions {
  display: flex;
  gap: 12px;
  flex-shrink: 0;
  .btn {
    padding: 11px 24px;
  }
  .btn.primary {
    background: #2f6bff;
    border-color: #2f6bff;
    color: #fff;
  }
}
@media (max-width: 960px) {
  .hero-inner {
    grid-template-columns: 1fr;
  }
  .steps {
    grid-template-columns: repeat(2, 1fr);
  }
  .cta-inner {
    flex-direction: column;
    align-items: flex-start;
  }
}
@media (max-width: 560px) {
  .steps {
    grid-template-columns: 1fr;
  }
  .hero-copy h1 {
    font-size: 30px;
  }
}
</style>
