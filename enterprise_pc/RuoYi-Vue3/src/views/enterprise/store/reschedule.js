// 待审批改期申请数量共享模块（面试安排页与侧边栏角标联动）
import { ref } from 'vue'
import { listRescheduleRequests } from '@/api/interview'

export const pendingRescheduleCount = ref(0)

export async function refreshPendingReschedule() {
  try {
    const res = await listRescheduleRequests({ status: 'pending', pageNum: 1, pageSize: 1 })
    pendingRescheduleCount.value = Number(res.total) || 0
  } catch {
    // 接口异常时保留当前值，不阻塞页面
  }
}
