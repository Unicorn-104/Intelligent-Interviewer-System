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

export const schedule = [
  { day: 0, top: 72, duration: 48, name: '高嘉怡', time: '10:00-10:45', level: 1 },
  { day: 0, top: 345, duration: 48, name: '周俊杰', time: '15:00-15:45', level: 1 },
  { day: 1, top: 32, duration: 48, name: '孙瑞峰', time: '09:30-10:15', level: 1 },
  { day: 1, top: 126, duration: 48, name: '吴宇航', time: '11:00-11:45', level: 1 },
  { day: 1, top: 428, duration: 48, name: '郑欣怡', time: '16:00-16:45', level: 1 },
  { day: 2, top: 8, duration: 48, name: '高翔', time: '09:00-09:45', level: 3 },
  { day: 2, top: 80, duration: 48, name: '王一诺', time: '10:15-11:00', level: 3 },
  { day: 2, top: 140, duration: 48, name: '林晓晴', time: '11:15-12:00', level: 3 },
  { day: 2, top: 300, duration: 48, name: '张雨桐', time: '14:00-14:45', level: 3 },
  { day: 2, top: 365, duration: 48, name: '周嘉懿', time: '15:15-16:00', level: 3 },
  { day: 3, top: 8, duration: 48, name: '李明轩', time: '09:00-09:45', level: 2 },
  { day: 3, top: 90, duration: 48, name: '顾承宇', time: '10:30-11:15', level: 2 },
  { day: 3, top: 275, duration: 48, name: '许安昊', time: '13:30-14:15', level: 2 },
  { day: 3, top: 350, duration: 48, name: '赵可欣', time: '15:00-15:45', level: 2 },
  { day: 4, top: 312, duration: 48, name: '顾言', time: '14:30-15:15', level: 2 },
  { day: 4, top: 420, duration: 48, name: '程曦', time: '16:00-16:45', level: 2 },
  { day: 5, top: 72, duration: 48, name: '夏沫', time: '10:00-10:45', level: 1 },
  { day: 5, top: 312, duration: 48, name: '白一帆', time: '14:30-15:15', level: 1 },
  { day: 6, top: 290, duration: 48, name: '邱雨', time: '14:00-14:45', level: 1 }
]
