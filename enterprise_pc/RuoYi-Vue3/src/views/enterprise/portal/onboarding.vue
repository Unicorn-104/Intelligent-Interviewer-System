<template>
  <div class="onboarding-page">
    <section class="page-head">
      <h1>企业入驻流程</h1>
      <p>提交企业注册信息后，平台会核验企业信息，审核通过即可登录企业招聘中心。</p>
    </section>

    <section class="timeline">
      <div v-for="(step, i) in steps" :key="step.title" class="timeline-item">
        <div class="timeline-no">{{ i + 1 }}</div>
        <div class="timeline-body">
          <h2>{{ step.title }}</h2>
          <p>{{ step.desc }}</p>
        </div>
      </div>
    </section>

    <section class="two-col">
      <div class="panel">
        <h2>注册所需信息</h2>
        <ul>
          <li>企业全称（与营业执照一致）</li>
          <li>统一社会信用代码（选填）</li>
          <li>所属行业、所在城市与企业规模</li>
          <li>联系人姓名与手机号</li>
          <li>登录账号与密码</li>
        </ul>
      </div>
      <div class="panel">
        <h2>审核说明</h2>
        <ul>
          <li>注册提交后企业与账号均为待审核状态</li>
          <li>平台审核通过后账号自动激活</li>
          <li>审核驳回时会给出原因，可修正后重新联系平台</li>
          <li>审核期间可先浏览平台能力与入驻说明</li>
        </ul>
      </div>
    </section>

    <section class="faq">
      <h2>常见问题</h2>
      <el-collapse v-model="activeFaq">
        <el-collapse-item title="注册后可以立即登录使用吗？" name="1">
          不可以。注册后企业与账号处于待审核状态，需平台审核通过后才能使用企业招聘中心的完整功能。
        </el-collapse-item>
        <el-collapse-item title="审核需要多久？" name="2">
          审核由平台管理员处理，具体时间以平台通知为准。审核状态可在登录后的入驻审核页查看。
        </el-collapse-item>
        <el-collapse-item title="企业名称重复怎么办？" name="3">
          同一企业名称只能注册一次。如提示已注册，请联系平台管理员核实企业归属。
        </el-collapse-item>
        <el-collapse-item title="审核被驳回后如何处理？" name="4">
          登录后可在入驻审核页查看驳回原因，修正企业信息后联系平台管理员重新审核。
        </el-collapse-item>
      </el-collapse>
    </section>

    <section class="bottom-cta">
      <div>
        <h2>开始提交企业入驻申请</h2>
        <p>填写企业与联系人信息，创建企业管理员账号。</p>
      </div>
      <router-link class="btn primary" to="/enterprise/register">企业入驻注册</router-link>
    </section>
  </div>
</template>

<script setup>
import { ref } from 'vue'

const activeFaq = ref(['1'])

const steps = [
  { title: '提交企业注册', desc: '填写企业名称、联系人与登录账号，提交入驻申请。' },
  { title: '平台审核', desc: '平台核验企业信息，审核通过后将企业账号绑定到企业。' },
  { title: '登录企业中心', desc: '使用注册账号登录，进入入驻审核页查看审核结果。' },
  { title: '配置并开始招聘', desc: '审核通过后配置部门、成员与招聘流程，发布岗位开始招聘。' }
]
</script>

<style lang="scss" scoped>
.onboarding-page {
  max-width: 980px;
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
.timeline {
  display: flex;
  flex-direction: column;
  gap: 14px;
  margin-bottom: 32px;
}
.timeline-item {
  display: grid;
  grid-template-columns: 44px 1fr;
  gap: 16px;
  background: #fff;
  border: 1px solid #e8ecf2;
  border-radius: 12px;
  padding: 20px 22px;
}
.timeline-no {
  width: 34px;
  height: 34px;
  border-radius: 50%;
  background: #2f6bff;
  color: #fff;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
}
.timeline-body {
  h2 {
    margin: 0 0 6px;
    font-size: 17px;
  }
  p {
    margin: 0;
    color: #6b7688;
    font-size: 14px;
    line-height: 1.7;
  }
}
.two-col {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}
.panel {
  background: #fff;
  border: 1px solid #e8ecf2;
  border-radius: 12px;
  padding: 22px;
  h2 {
    margin: 0 0 12px;
    font-size: 17px;
  }
  ul {
    margin: 0;
    padding-left: 18px;
    color: #5a6577;
    font-size: 14px;
    line-height: 1.9;
  }
}
.faq {
  margin-top: 32px;
  background: #fff;
  border: 1px solid #e8ecf2;
  border-radius: 12px;
  padding: 8px 22px 16px;
  h2 {
    margin: 16px 0 8px;
    font-size: 17px;
  }
}
.bottom-cta {
  margin-top: 32px;
  background: #eef3ff;
  border-radius: 14px;
  padding: 30px 32px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 20px;
  h2 {
    margin: 0 0 8px;
    font-size: 20px;
  }
  p {
    margin: 0;
    color: #5a6577;
    font-size: 14px;
  }
}
.btn {
  padding: 11px 24px;
  border-radius: 8px;
  font-size: 14px;
  text-decoration: none;
  color: #2f6bff;
  border: 1px solid #c8d7ff;
  background: #fff;
  flex-shrink: 0;
  &.primary {
    background: #2f6bff;
    border-color: #2f6bff;
    color: #fff;
  }
}
@media (max-width: 760px) {
  .two-col {
    grid-template-columns: 1fr;
  }
  .bottom-cta {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
