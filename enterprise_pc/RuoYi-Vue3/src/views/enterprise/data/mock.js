export const jobs = [
  { id: 1, pos_id: 1001, name: '高级前端工程师', pos_title: '高级前端工程师', dept: '产品研发部', pos_department: '产品研发部', city: '杭州', pos_work_city: '杭州', salary: '25-35K · 14薪', pos_salary_min: 25000, pos_salary_max: 35000, date: '06-18', count: 2, active: true, status: '招聘中', pos_status: 1, tone: 'green', skills: ['Vue 3', 'TypeScript', '微前端', '性能优化'], pos_skills: [{ psk_name: 'Vue 3', psk_required: 1 }, { psk_name: 'TypeScript', psk_required: 1 }] },
  { id: 2, name: '产品经理', dept: '产品中心', city: '上海', salary: '20-30K · 16薪', date: '06-16', count: 1, active: true, status: '招聘中', tone: 'green', skills: ['B端产品', 'Axure', '数据分析'] },
  { id: 3, name: 'UI / UX 设计师', dept: '设计中心', city: '深圳', salary: '18-24K · 14薪', date: '06-12', count: 2, active: false, status: '已暂停', tone: 'gray', skills: ['Figma', '设计系统', '用户研究'] },
  { id: 4, name: '数据分析师', dept: '数据平台部', city: '北京', salary: '22-28K · 14薪', date: '06-10', count: 1, active: true, status: '招聘中', tone: 'green', skills: ['Python', 'SQL', 'Tableau'] },
  { id: 5, name: '招聘专家（HRBP）', dept: '人力资源部', city: '北京', salary: '20-30K · 15薪', date: '06-08', count: 2, active: false, status: '已暂停', tone: 'gray', skills: ['人才盘点', '雇主品牌', '招聘策略'] }
]

export const candidates = [
  { userId: 104, name: '李强', role: '高级前端工程师', match: 92, stage: 'HR 终审与薪酬沟通', tone: 'purple', color: '#635bff' },
  { userId: 107, name: '王芳', role: '高级前端工程师', match: 90, stage: '专业技术面', tone: 'blue', color: '#1d8cf8' },
  { userId: 114, name: '张敏', role: 'UI设计师', match: 88, stage: 'AI 结构化预面', tone: 'blue', color: '#2667ff' },
  { userId: 117, name: '陈晨', role: '高级前端工程师', match: 85, stage: '初筛通过待面试', tone: 'orange', color: '#f59e0b' },
  { userId: 110, name: '赵磊', role: '产品经理', match: 82, stage: '已淘汰', tone: 'red', color: '#ef4444' }
]

// 面试块状态：pending=待确认(橙) confirmed=已确认(蓝) completed=已完成(灰) conflict=冲突(红框) cancelled=已取消(浅灰删除线)
// 通知状态 notify：unsent=未发送(灰铃) sending=发送中(加载) failed=发送失败(红叹号) sent=已送达(不显示)
// startMin: 从09:00开始的分钟偏移；durMin: 面试时长分钟数（日历总范围09:00-18:00=540分钟）
export const schedule = [
  // 周一
  { id:1, day:0, startMin:60, durMin:45, candidate:'高嘉怡', position:'前端开发', interviewer:'陈静', stage:'技术面', status:'confirmed', notify:'sent', time:'10:00-10:45' },
  { id:2, day:0, startMin:360, durMin:45, candidate:'周俊杰', position:'后端开发', interviewer:'王磊', stage:'技术面', status:'pending', notify:'unsent', time:'15:00-15:45' },
  // 周二
  { id:3, day:1, startMin:30, durMin:45, candidate:'孙瑞峰', position:'前端开发', interviewer:'陈静', stage:'技术面', status:'confirmed', notify:'sent', time:'09:30-10:15' },
  { id:4, day:1, startMin:120, durMin:45, candidate:'吴宇航', position:'测试工程师', interviewer:'赵敏', stage:'技术面', status:'confirmed', notify:'sent', time:'11:00-11:45' },
  { id:5, day:1, startMin:420, durMin:45, candidate:'郑欣怡', position:'UI设计师', interviewer:'李薇', stage:'作品集面', status:'pending', notify:'failed', time:'16:00-16:45' },
  // 周三（今天，场次最多）
  { id:6, day:2, startMin:0, durMin:45, candidate:'高翔', position:'后端开发', interviewer:'王磊', stage:'技术面', status:'confirmed', notify:'sent', time:'09:00-09:45' },
  { id:7, day:2, startMin:75, durMin:45, candidate:'王一诺', position:'UI设计师', interviewer:'李薇', stage:'作品集面', status:'pending', notify:'unsent', time:'10:15-11:00' },
  { id:8, day:2, startMin:135, durMin:45, candidate:'林晓晴', position:'产品经理', interviewer:'刘洋', stage:'业务面', status:'confirmed', notify:'sent', time:'11:15-12:00' },
  { id:9, day:2, startMin:300, durMin:45, candidate:'张雨桐', position:'前端开发', interviewer:'陈静', stage:'技术面', status:'pending', notify:'unsent', time:'14:00-14:45' },
  { id:10, day:2, startMin:375, durMin:45, candidate:'周嘉懿', position:'数据分析师', interviewer:'赵峰', stage:'SQL面', status:'confirmed', notify:'sent', time:'15:15-16:00' },
  // 周四
  { id:11, day:3, startMin:0, durMin:45, candidate:'李明轩', position:'后端开发', interviewer:'王磊', stage:'项目深挖', status:'confirmed', notify:'sent', time:'09:00-09:45' },
  { id:12, day:3, startMin:90, durMin:45, candidate:'顾承宇', position:'前端开发', interviewer:'陈静', stage:'技术面', status:'confirmed', notify:'sent', time:'10:30-11:15' },
  { id:13, day:3, startMin:270, durMin:45, candidate:'许安昊', position:'产品经理', interviewer:'刘洋', stage:'业务面', status:'confirmed', notify:'sent', time:'13:30-14:15' },
  { id:14, day:3, startMin:360, durMin:45, candidate:'赵可欣', position:'UI设计师', interviewer:'李薇', stage:'作品集面', status:'conflict', notify:'unsent', time:'15:00-15:45' },
  // 周五
  { id:15, day:4, startMin:330, durMin:45, candidate:'顾言', position:'后端开发', interviewer:'王磊', stage:'技术面', status:'confirmed', notify:'sent', time:'14:30-15:15' },
  { id:16, day:4, startMin:420, durMin:45, candidate:'程曦', position:'测试工程师', interviewer:'赵敏', stage:'技术面', status:'completed', notify:'sent', time:'16:00-16:45' },
  // 周六
  { id:17, day:5, startMin:60, durMin:45, candidate:'夏沫', position:'前端开发', interviewer:'陈静', stage:'技术面', status:'pending', notify:'unsent', time:'10:00-10:45' },
  { id:18, day:5, startMin:330, durMin:45, candidate:'白一帆', position:'产品经理', interviewer:'刘洋', stage:'业务面', status:'confirmed', notify:'sent', time:'14:30-15:15' },
  // 周日
  { id:19, day:6, startMin:300, durMin:45, candidate:'邱雨', position:'数据分析师', interviewer:'赵峰', stage:'SQL面', status:'confirmed', notify:'sent', time:'14:00-14:45' }
]
