<template>
  <div class="features-page">
    <section class="page-head">
      <h1>平台能力</h1>
      <p>面向企业招聘团队的一体化能力，覆盖从岗位发布到 Offer 发放的完整链路。</p>
    </section>

    <section class="capability-list">
      <article v-for="item in capabilities" :key="item.title" class="capability">
        <div class="capability-index">{{ item.index }}</div>
        <div class="capability-body">
          <h2>{{ item.title }}</h2>
          <p>{{ item.desc }}</p>
          <ul>
            <li v-for="point in item.points" :key="point">{{ point }}</li>
          </ul>
        </div>
      </article>
    </section>

    <section class="bottom-cta">
      <div>
        <h2>准备好开始了吗？</h2>
        <p>注册企业账号并提交入驻申请，审核通过后即可使用全部能力。</p>
      </div>
      <div class="bottom-actions">
        <router-link class="btn primary" to="/enterprise/register">企业入驻注册</router-link>
        <router-link class="btn" to="/enterprise/login">登录企业中心</router-link>
      </div>
    </section>
  </div>
</template>

<script setup>
const capabilities = [
  {
    index: '01',
    title: '岗位管理',
    desc: '集中维护企业对外职位，统一管理岗位状态与招聘流程。',
    points: ['创建、编辑、下架岗位', '配置岗位职责、任职要求与技能标签', '按岗位配置招聘流程与筛选规则']
  },
  {
    index: '02',
    title: 'AI 简历筛选',
    desc: '基于岗位要求自动解析简历，输出匹配评分并排序。',
    points: ['批量解析候选人简历', '按岗位自动评分与推荐', '人工复核与筛选结论留痕']
  },
  {
    index: '03',
    title: '面试安排与协同',
    desc: '统一管理面试官、候选人与日程，减少反复沟通。',
    points: ['面试日程与面试官排期', '候选人改期申请与审批', '面试评价与结果汇总']
  },
  {
    index: '04',
    title: '在线笔试',
    desc: '灵活组卷、在线监考与自动阅卷，笔面结果统一沉淀。',
    points: ['随机组卷与手工选题', '在线监考与作答记录', '自动阅卷与成绩统计']
  },
  {
    index: '05',
    title: '人才库',
    desc: '沉淀历史候选人与面试评价，为后续岗位复用人才。',
    points: ['候选人标签与检索', '历史投递与面试记录', '人才跟进状态管理']
  },
  {
    index: '06',
    title: '组织与数据看板',
    desc: '管理企业成员与部门权限，实时掌握招聘进展。',
    points: ['部门与成员权限管理', '岗位、候选人、面试数据看板', '通知模板与消息配置']
  }
]
</script>

<style lang="scss" scoped>
.features-page {
  max-width: 1180px;
  margin: 0 auto;
  padding: 44px 20px 60px;
}
.page-head {
  margin-bottom: 30px;
  h1 {
    margin: 0 0 12px;
    font-size: 30px;
  }
  p {
    margin: 0;
    color: #6b7688;
    font-size: 15px;
  }
}
.capability-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.capability {
  display: grid;
  grid-template-columns: 64px 1fr;
  gap: 20px;
  background: #fff;
  border: 1px solid #e8ecf2;
  border-radius: 12px;
  padding: 24px;
}
.capability-index {
  width: 48px;
  height: 48px;
  border-radius: 10px;
  background: #eef3ff;
  color: #2f6bff;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
}
.capability-body {
  h2 {
    margin: 0 0 8px;
    font-size: 18px;
  }
  p {
    margin: 0 0 12px;
    color: #5a6577;
    font-size: 14px;
  }
  ul {
    margin: 0;
    padding-left: 18px;
    color: #6b7688;
    font-size: 14px;
    line-height: 1.9;
  }
}
.bottom-cta {
  margin-top: 36px;
  background: #eef3ff;
  border-radius: 14px;
  padding: 32px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
  h2 {
    margin: 0 0 8px;
    font-size: 21px;
  }
  p {
    margin: 0;
    color: #5a6577;
    font-size: 14px;
  }
}
.bottom-actions {
  display: flex;
  gap: 12px;
  flex-shrink: 0;
}
.btn {
  padding: 10px 22px;
  border-radius: 8px;
  font-size: 14px;
  text-decoration: none;
  color: #2f6bff;
  border: 1px solid #c8d7ff;
  background: #fff;
  &.primary {
    background: #2f6bff;
    border-color: #2f6bff;
    color: #fff;
  }
}
@media (max-width: 760px) {
  .capability {
    grid-template-columns: 1fr;
  }
  .bottom-cta {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
