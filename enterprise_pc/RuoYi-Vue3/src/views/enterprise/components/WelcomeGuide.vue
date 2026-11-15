<script setup>
import { ref, watch } from 'vue'
import useUserStore from '@/store/modules/user'
import HelpGuideDialog from '@/views/enterprise/components/HelpGuideDialog.vue'

const userStore = useUserStore()
const visible = ref(false)
const guideOpen = ref(false)

function key() {
  return `talentflow_guide_seen_${userStore.id || 'guest'}`
}

watch(
  () => userStore.id,
  (id) => {
    if (!id) return
    visible.value = localStorage.getItem(key()) !== '1'
  },
  { immediate: true }
)

function close() {
  localStorage.setItem(key(), '1')
  visible.value = false
}

function openGuide() {
  close()
  guideOpen.value = true
}
</script>

<template>
  <el-dialog v-model="visible" width="660px" class="welcome-dialog" :show-close="true" append-to-body @close="close">
    <div class="welcome">
      <div class="welcome-head">
        <span class="badge">首次登录引导</span>
        <h2>欢迎使用 TalentFlow 企业招聘工作台</h2>
        <p>这里是招聘全流程的操作中心。花一分钟了解基础用法，之后随时可以在左下角「需要帮助？」里查看完整指南。</p>
      </div>

      <div class="flow">
        <div class="flow-step">
          <b>1</b>
          <div><h4>完善企业与成员</h4><p>在「系统设置」维护公司信息、部门与成员角色，面试官角色用于后续排期邀请。</p></div>
        </div>
        <div class="flow-step">
          <b>2</b>
          <div><h4>发布岗位</h4><p>「岗位管理」新建岗位，可粘贴 JD 让 AI 自动解析；批量岗位可用「岗位导入与草稿」。</p></div>
        </div>
        <div class="flow-step">
          <b>3</b>
          <div><h4>查看候选人与评分</h4><p>「候选人管理」按投递查看简历，可发起 AI 评分、批量改状态与批量打标签。</p></div>
        </div>
        <div class="flow-step">
          <b>4</b>
          <div><h4>安排面试到发放 Offer</h4><p>「面试与笔试」完成排期、改期审批、笔试与监考；终面通过后进入「Offer 管理」审批并发送。</p></div>
        </div>
      </div>

      <div class="quick">
        <p><b>右侧</b>：右上角铃铛为消息提醒，右侧头像可进入个人中心。</p>
        <p><b>左侧</b>：导航按角色权限展示，看不到的菜单请联系企业管理员分配角色。</p>
        <p><b>右下角</b>：AI 助手悬浮球可按对话完成查询；<b>左下角</b>「需要帮助？」打开完整使用指南。</p>
      </div>
    </div>

    <template #footer>
      <div class="welcome-foot">
        <button class="btn sm" @click="openGuide">查看完整使用指南</button>
        <button class="btn sm primary" @click="close">开始使用</button>
      </div>
    </template>
  </el-dialog>

  <HelpGuideDialog v-model="guideOpen" />
</template>

<style scoped>
.welcome-head .badge { display: inline-block; padding: 3px 9px; border-radius: 999px; background: var(--primary-soft); color: var(--primary); font-size: 11px; }
.welcome-head h2 { margin: 10px 0 6px; font-size: 20px; }
.welcome-head p { color: var(--muted); font-size: 13px; line-height: 1.7; }
.flow { display: grid; gap: 10px; margin-top: 16px; }
.flow-step { display: flex; gap: 12px; padding: 12px 14px; border: 1px solid var(--line); border-radius: 10px; background: #fbfdff; }
.flow-step > b { flex: none; width: 22px; height: 22px; border-radius: 50%; background: var(--primary-soft); color: var(--primary); font-size: 12px; display: grid; place-items: center; }
.flow-step h4 { font-size: 13px; color: var(--text); }
.flow-step p { margin-top: 3px; font-size: 12px; line-height: 1.7; color: var(--muted); }
.quick { margin-top: 14px; padding: 12px 14px; border-radius: 10px; background: #f5f8fe; }
.quick p { font-size: 12px; line-height: 1.8; color: #4a5a76; }
.welcome-foot { display: flex; justify-content: flex-end; gap: 10px; }
</style>
