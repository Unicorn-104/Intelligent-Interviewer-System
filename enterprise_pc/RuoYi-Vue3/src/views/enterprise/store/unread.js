// 未读消息总数共享模块（消息中心与侧边栏角标联动），数据来自后端 IM 接口
import { ref } from 'vue'
import { unreadCount } from '@/api/system/im'

export const totalUnread = ref(0)

export async function refreshUnread() {
  try {
    const res = await unreadCount()
    totalUnread.value = res.count || 0
  } catch {
    // 接口异常时保留当前值
  }
}
