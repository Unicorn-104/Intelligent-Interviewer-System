// 演示用 mock 数据层（无后端时的内存数据源，刷新页面后重置）

// ===== 工具 =====
export function ok(data, msg = '操作成功') {
  const payload = data ?? null
  const normalizedData =
    payload &&
    !Array.isArray(payload) &&
    typeof payload === 'object' &&
    Object.keys(payload).length === 1 &&
    Object.prototype.hasOwnProperty.call(payload, 'data')
      ? payload.data
      : payload
  return { code: 0, msg, data: normalizedData }
}

export function paginate(rows, query) {
  const page = parseInt(query.page || query.pageNum || 1)
  const pageSize = parseInt(query.pageSize || 10)
  const total = rows.length
  const start = (page - 1) * pageSize
  return { total, page, pageSize, rows: rows.slice(start, start + pageSize) }
}

export function nextId(rows, key) {
  return rows.reduce((m, r) => Math.max(m, r[key] || 0), 0) + 1
}

// ===== 系统管理：用户管理 =====
export const users = [
  {
    userId: 1,
    userName: 'admin',
    nickName: '超级管理员',
    deptId: 100,
    dept: { deptName: 'AI招聘管理系统' },
    phonenumber: '15888888888',
    status: '0',
    createTime: '2024-01-05 10:24:31',
    remark: '平台最高权限'
  },
  {
    userId: 2,
    userName: 'ops01',
    nickName: '运营专员-李晴',
    deptId: 101,
    dept: { deptName: '运营部' },
    phonenumber: '13800000001',
    status: '0',
    createTime: '2024-02-18 09:15:02',
    remark: ''
  },
  {
    userId: 3,
    userName: 'ops02',
    nickName: '运营专员-王可',
    deptId: 101,
    dept: { deptName: '运营部' },
    phonenumber: '13800000002',
    status: '0',
    createTime: '2024-03-02 14:40:11',
    remark: ''
  },
  {
    userId: 4,
    userName: 'tech01',
    nickName: '技术支持-刘畅',
    deptId: 102,
    dept: { deptName: '技术部' },
    phonenumber: '13800000003',
    status: '0',
    createTime: '2024-03-27 16:08:55',
    remark: ''
  },
  {
    userId: 5,
    userName: 'fin01',
    nickName: '财务-赵敏',
    deptId: 103,
    dept: { deptName: '财务部' },
    phonenumber: '13800000004',
    status: '0',
    createTime: '2024-04-11 11:22:37',
    remark: ''
  },
  {
    userId: 6,
    userName: 'auditor',
    nickName: '审计-陈墨',
    deptId: 104,
    dept: { deptName: '审计部' },
    phonenumber: '13800000005',
    status: '1',
    createTime: '2024-05-09 15:47:20',
    remark: '账号停用'
  }
]

// ===== 系统管理：部门管理 =====
export const depts = [
  { deptId: 100, parentId: 0, deptName: 'AI招聘管理系统', orderNum: 0, status: '0' },
  { deptId: 101, parentId: 100, deptName: '运营部', orderNum: 1, status: '0' },
  { deptId: 102, parentId: 100, deptName: '技术部', orderNum: 2, status: '0' },
  { deptId: 103, parentId: 100, deptName: '财务部', orderNum: 3, status: '0' },
  { deptId: 104, parentId: 100, deptName: '审计部', orderNum: 4, status: '0' }
]

// ===== 系统管理：角色管理 =====
export const roles = [
  {
    roleId: 1,
    roleName: '超级管理员',
    roleKey: 'admin',
    roleSort: 1,
    status: '0',
    createTime: '2024-01-05 10:24:31',
    remark: '平台最高权限'
  },
  {
    roleId: 2,
    roleName: '运营人员',
    roleKey: 'operator',
    roleSort: 2,
    status: '0',
    createTime: '2024-02-18 09:15:02',
    remark: '租户与内容管理'
  },
  {
    roleId: 3,
    roleName: '技术支持',
    roleKey: 'tech',
    roleSort: 3,
    status: '0',
    createTime: '2024-03-27 16:08:55',
    remark: 'AI配置与监控'
  },
  {
    roleId: 4,
    roleName: '财务',
    roleKey: 'finance',
    roleSort: 4,
    status: '0',
    createTime: '2024-04-11 11:22:37',
    remark: '套餐与账单'
  }
]

// ===== 系统管理：菜单管理 =====
export const menus = [
  {
    menuId: 1,
    menuName: '租户管理',
    parentId: 0,
    orderNum: 1,
    path: '/tenant',
    component: null,
    query: '',
    routeName: '',
    isFrame: '1',
    isCache: '0',
    menuType: 'M',
    visible: '0',
    status: '0',
    perms: '',
    icon: 'peoples',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 100,
    menuName: '企业管理',
    parentId: 1,
    orderNum: 1,
    path: 'company',
    component: 'tenant/company/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'tenant:company:list',
    icon: 'build',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 101,
    menuName: '套餐管理',
    parentId: 1,
    orderNum: 2,
    path: 'package',
    component: 'tenant/package/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'tenant:package:list',
    icon: 'money',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 2,
    menuName: '系统管理',
    parentId: 0,
    orderNum: 2,
    path: '/system',
    component: null,
    menuType: 'M',
    visible: '0',
    status: '0',
    perms: '',
    icon: 'system',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 102,
    menuName: '用户管理',
    parentId: 2,
    orderNum: 1,
    path: 'user',
    component: 'system/user/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'system:user:list',
    icon: 'user',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 103,
    menuName: '角色分配',
    parentId: 2,
    orderNum: 2,
    path: 'role',
    component: 'system/role/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'system:role:list',
    icon: 'peoples',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 104,
    menuName: '菜单配置',
    parentId: 2,
    orderNum: 3,
    path: 'menu',
    component: 'system/menu/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'system:menu:list',
    icon: 'tree-table',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 105,
    menuName: '数据字典',
    parentId: 2,
    orderNum: 4,
    path: 'dict',
    component: 'system/dict/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'system:dict:list',
    icon: 'dict',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 3,
    menuName: 'AI 配置',
    parentId: 0,
    orderNum: 3,
    path: '/ai',
    component: null,
    menuType: 'M',
    visible: '0',
    status: '0',
    perms: '',
    icon: 'skill',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 106,
    menuName: '模型管理',
    parentId: 3,
    orderNum: 1,
    path: 'model',
    component: 'ai/model/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'ai:model:list',
    icon: 'component',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 107,
    menuName: 'API 配额',
    parentId: 3,
    orderNum: 2,
    path: 'quota',
    component: 'ai/quota/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'ai:quota:list',
    icon: 'chart',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 108,
    menuName: '提示词模板',
    parentId: 3,
    orderNum: 3,
    path: 'prompt',
    component: 'ai/prompt/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'ai:prompt:list',
    icon: 'edit',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 4,
    menuName: '内容管理',
    parentId: 0,
    orderNum: 4,
    path: '/content',
    component: null,
    menuType: 'M',
    visible: '0',
    status: '0',
    perms: '',
    icon: 'form',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 109,
    menuName: '职位分类',
    parentId: 4,
    orderNum: 1,
    path: 'category',
    component: 'content/category/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'content:category:list',
    icon: 'tree',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 110,
    menuName: '面试题库',
    parentId: 4,
    orderNum: 2,
    path: 'question',
    component: 'content/question/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'content:question:list',
    icon: 'education',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 111,
    menuName: '公告管理',
    parentId: 4,
    orderNum: 3,
    path: 'notice',
    component: 'content/notice/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'content:notice:list',
    icon: 'message',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 5,
    menuName: '日志审计',
    parentId: 0,
    orderNum: 5,
    path: '/log',
    component: null,
    menuType: 'M',
    visible: '0',
    status: '0',
    perms: '',
    icon: 'log',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 112,
    menuName: '操作日志',
    parentId: 5,
    orderNum: 1,
    path: 'operlog',
    component: 'monitor/operlog/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'monitor:operlog:list',
    icon: 'form',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 113,
    menuName: '登录日志',
    parentId: 5,
    orderNum: 2,
    path: 'logininfor',
    component: 'monitor/logininfor/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'monitor:logininfor:list',
    icon: 'logininfor',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 6,
    menuName: '系统监控',
    parentId: 0,
    orderNum: 6,
    path: '/monitor',
    component: null,
    menuType: 'M',
    visible: '0',
    status: '0',
    perms: '',
    icon: 'monitor',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 114,
    menuName: '在线用户',
    parentId: 6,
    orderNum: 1,
    path: 'online',
    component: 'monitor/online/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'monitor:online:list',
    icon: 'online',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 115,
    menuName: '服务状态',
    parentId: 6,
    orderNum: 2,
    path: 'server',
    component: 'monitor/server/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'monitor:server:list',
    icon: 'server',
    createTime: '2024-01-05 10:24:31'
  },
  {
    menuId: 116,
    menuName: '定时任务',
    parentId: 6,
    orderNum: 3,
    path: 'job',
    component: 'monitor/job/index',
    menuType: 'C',
    visible: '0',
    status: '0',
    perms: 'monitor:job:list',
    icon: 'job',
    createTime: '2024-01-05 10:24:31'
  }
]

// 原生若依公告（复用 system/notice 页面并挂载到内容管理菜单）
export const notices = [
  {
    noticeId: 1,
    noticeTitle: '平台 V2.3 版本更新公告',
    noticeType: '2',
    noticeContent: '新增 AI 面试报告导出、候选人端广告位支持、配额预警等功能。',
    status: '0',
    createBy: 'admin',
    createTime: '2026-08-20 09:00:00'
  },
  {
    noticeId: 2,
    noticeTitle: '9月8日凌晨系统维护通知',
    noticeType: '1',
    noticeContent: '平台将于 9月8日 02:00-06:00 进行系统维护，期间服务暂不可用。',
    status: '0',
    createBy: 'admin',
    createTime: '2026-09-06 15:30:00'
  },
  {
    noticeId: 3,
    noticeTitle: '关于上线简历解析加速的通知',
    noticeType: '2',
    noticeContent: '为提升简历解析速度，我们已对底层OCR引擎进行升级，预计解析时间缩短60%。',
    status: '0',
    createBy: 'tech01',
    createTime: '2026-09-05 14:20:00'
  },
  {
    noticeId: 4,
    noticeTitle: '9月份企业套餐续费优惠公告',
    noticeType: '1',
    noticeContent: '9月15日前完成续费的旗舰版企业可获赠20%额外API调用额度，专业版获赠10%。',
    status: '0',
    createBy: 'ops01',
    createTime: '2026-09-04 10:15:00'
  },
  {
    noticeId: 5,
    noticeTitle: '用户反馈渠道升级说明',
    noticeType: '2',
    noticeContent: '平台智能客服小智已完成模型升级，响应速度和准确率均有显著提升，欢迎大家体验使用。',
    status: '0',
    createBy: 'ops02',
    createTime: '2026-09-03 16:40:00'
  },
  {
    noticeId: 6,
    noticeTitle: 'AI面试系统常见问题FAQ汇总',
    noticeType: '2',
    noticeContent: '整理候选人在AI面试过程中常见的问题及解决方案，包括设备检测、网络环境、网络卡顿等处理方法。',
    status: '0',
    createBy: 'tech01',
    createTime: '2026-09-02 11:30:00'
  },
  {
    noticeId: 7,
    noticeTitle: '平台V2.4版本即将上线预告',
    noticeType: '2',
    noticeContent: '新版本将新增AI视频面试报告自动生成、企业自定义评分维度、面试回放等功能，敬请期待。',
    status: '0',
    createBy: 'admin',
    createTime: '2026-09-07 09:00:00'
  }
]

// ===== 字典 =====
export const dictTypes = [
  {
    dictId: 1,
    dictName: '用户性别',
    dictType: 'sys_user_sex',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '用户性别列表'
  },
  {
    dictId: 2,
    dictName: '菜单状态',
    dictType: 'sys_show_hide',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '菜单状态列表'
  },
  {
    dictId: 3,
    dictName: '系统开关',
    dictType: 'sys_normal_disable',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '系统开关列表'
  },
  {
    dictId: 4,
    dictName: '操作类型',
    dictType: 'sys_oper_type',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '操作类型列表'
  },
  {
    dictId: 5,
    dictName: '系统状态',
    dictType: 'sys_common_status',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '登录状态列表'
  },
  {
    dictId: 6,
    dictName: '套餐类型',
    dictType: 'tenant_package_type',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '租户套餐类型'
  },
  {
    dictId: 7,
    dictName: '企业状态',
    dictType: 'tenant_company_status',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '租户企业状态'
  },
  {
    dictId: 8,
    dictName: '模型提供商',
    dictType: 'ai_model_provider',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: 'AI模型提供商'
  },
  {
    dictId: 9,
    dictName: '广告位类型',
    dictType: 'ad_slot_type',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '广告位类型'
  },
  {
    dictId: 10,
    dictName: '广告状态',
    dictType: 'ad_advert_status',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '广告投放状态'
  },
  {
    dictId: 11,
    dictName: 'C端用户状态',
    dictType: 'member_user_status',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '候选人/企业用户账号状态'
  },
  {
    dictId: 12,
    dictName: '认证审核状态',
    dictType: 'verify_status',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '企业归属认证审核状态'
  },
  {
    dictId: 13,
    dictName: '消息渠道',
    dictType: 'msg_channel',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '通知发送渠道'
  },
  {
    dictId: 14,
    dictName: '反馈类型',
    dictType: 'feedback_type',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '用户反馈问题类型'
  },
  {
    dictId: 15,
    dictName: '工单状态',
    dictType: 'ticket_status',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '反馈工单处理状态'
  },
  {
    dictId: 16,
    dictName: '面试模式',
    dictType: 'interview_mode',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '面试执行模式'
  },
  {
    dictId: 17,
    dictName: '面试状态',
    dictType: 'interview_status',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '面试场次状态'
  },
  {
    dictId: 18,
    dictName: '岗位审核状态',
    dictType: 'job_audit_status',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '平台岗位审核状态'
  },
  {
    dictId: 19,
    dictName: '风险等级',
    dictType: 'risk_level',
    status: '0',
    createBy: 'admin',
    createTime: '2024-01-05 10:24:31',
    remark: '岗位风险等级'
  }
]

export const dictDatas = {
  sys_user_sex: [
    {
      dictCode: 1,
      dictLabel: '男',
      dictValue: '0',
      dictType: 'sys_user_sex',
      listClass: 'default',
      isDefault: 'Y',
      status: '0'
    },
    {
      dictCode: 2,
      dictLabel: '女',
      dictValue: '1',
      dictType: 'sys_user_sex',
      listClass: 'default',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 3,
      dictLabel: '未知',
      dictValue: '2',
      dictType: 'sys_user_sex',
      listClass: 'default',
      isDefault: 'N',
      status: '0'
    }
  ],
  sys_show_hide: [
    {
      dictCode: 4,
      dictLabel: '显示',
      dictValue: '0',
      dictType: 'sys_show_hide',
      listClass: 'primary',
      isDefault: 'Y',
      status: '0'
    },
    {
      dictCode: 5,
      dictLabel: '隐藏',
      dictValue: '1',
      dictType: 'sys_show_hide',
      listClass: 'danger',
      isDefault: 'N',
      status: '0'
    }
  ],
  sys_normal_disable: [
    {
      dictCode: 6,
      dictLabel: '正常',
      dictValue: '0',
      dictType: 'sys_normal_disable',
      listClass: 'primary',
      isDefault: 'Y',
      status: '0'
    },
    {
      dictCode: 7,
      dictLabel: '停用',
      dictValue: '1',
      dictType: 'sys_normal_disable',
      listClass: 'danger',
      isDefault: 'N',
      status: '0'
    }
  ],
  sys_oper_type: [
    {
      dictCode: 8,
      dictLabel: '新增',
      dictValue: '1',
      dictType: 'sys_oper_type',
      listClass: 'primary',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 9,
      dictLabel: '修改',
      dictValue: '2',
      dictType: 'sys_oper_type',
      listClass: 'warning',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 10,
      dictLabel: '删除',
      dictValue: '3',
      dictType: 'sys_oper_type',
      listClass: 'danger',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 11,
      dictLabel: '导出',
      dictValue: '8',
      dictType: 'sys_oper_type',
      listClass: 'info',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 12,
      dictLabel: '其他',
      dictValue: '0',
      dictType: 'sys_oper_type',
      listClass: 'info',
      isDefault: 'Y',
      status: '0'
    }
  ],
  sys_common_status: [
    {
      dictCode: 13,
      dictLabel: '成功',
      dictValue: '0',
      dictType: 'sys_common_status',
      listClass: 'primary',
      isDefault: 'Y',
      status: '0'
    },
    {
      dictCode: 14,
      dictLabel: '失败',
      dictValue: '1',
      dictType: 'sys_common_status',
      listClass: 'danger',
      isDefault: 'N',
      status: '0'
    }
  ],
  tenant_package_type: [
    {
      dictCode: 15,
      dictLabel: '基础版',
      dictValue: 'basic',
      dictType: 'tenant_package_type',
      listClass: 'info',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 16,
      dictLabel: '专业版',
      dictValue: 'pro',
      dictType: 'tenant_package_type',
      listClass: 'primary',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 17,
      dictLabel: '旗舰版',
      dictValue: 'flag',
      dictType: 'tenant_package_type',
      listClass: 'warning',
      isDefault: 'N',
      status: '0'
    }
  ],
  tenant_company_status: [
    {
      dictCode: 18,
      dictLabel: '正常',
      dictValue: '0',
      dictType: 'tenant_company_status',
      listClass: 'success',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 19,
      dictLabel: '停用',
      dictValue: '1',
      dictType: 'tenant_company_status',
      listClass: 'danger',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 20,
      dictLabel: '试用期',
      dictValue: '2',
      dictType: 'tenant_company_status',
      listClass: 'warning',
      isDefault: 'N',
      status: '0'
    }
  ],
  ai_model_provider: [
    {
      dictCode: 21,
      dictLabel: '阿里云',
      dictValue: 'aliyun',
      dictType: 'ai_model_provider',
      listClass: 'primary',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 22,
      dictLabel: '其他',
      dictValue: 'other',
      dictType: 'ai_model_provider',
      listClass: 'info',
      isDefault: 'N',
      status: '0'
    }
  ],
  ad_slot_type: [
    {
      dictCode: 23,
      dictLabel: '开屏广告',
      dictValue: 'splash',
      dictType: 'ad_slot_type',
      listClass: 'primary',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 24,
      dictLabel: '弹窗广告',
      dictValue: 'popup',
      dictType: 'ad_slot_type',
      listClass: 'warning',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 25,
      dictLabel: 'Banner 轮播',
      dictValue: 'banner',
      dictType: 'ad_slot_type',
      listClass: 'info',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 26,
      dictLabel: '信息流广告',
      dictValue: 'feed',
      dictType: 'ad_slot_type',
      listClass: 'success',
      isDefault: 'N',
      status: '0'
    }
  ],
  ad_advert_status: [
    {
      dictCode: 27,
      dictLabel: '待投放',
      dictValue: '0',
      dictType: 'ad_advert_status',
      listClass: 'info',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 28,
      dictLabel: '投放中',
      dictValue: '1',
      dictType: 'ad_advert_status',
      listClass: 'primary',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 29,
      dictLabel: '已暂停',
      dictValue: '2',
      dictType: 'ad_advert_status',
      listClass: 'warning',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 30,
      dictLabel: '已结束',
      dictValue: '3',
      dictType: 'ad_advert_status',
      listClass: 'danger',
      isDefault: 'N',
      status: '0'
    }
  ],
  member_user_status: [
    {
      dictCode: 31,
      dictLabel: '正常',
      dictValue: '0',
      dictType: 'member_user_status',
      listClass: 'success',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 32,
      dictLabel: '已封禁',
      dictValue: '1',
      dictType: 'member_user_status',
      listClass: 'danger',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 33,
      dictLabel: '注销待审核',
      dictValue: '2',
      dictType: 'member_user_status',
      listClass: 'warning',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 34,
      dictLabel: '已注销',
      dictValue: '3',
      dictType: 'member_user_status',
      listClass: 'info',
      isDefault: 'N',
      status: '0'
    }
  ],
  verify_status: [
    {
      dictCode: 35,
      dictLabel: '待审核',
      dictValue: '0',
      dictType: 'verify_status',
      listClass: 'warning',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 36,
      dictLabel: '已通过',
      dictValue: '1',
      dictType: 'verify_status',
      listClass: 'success',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 37,
      dictLabel: '已驳回',
      dictValue: '2',
      dictType: 'verify_status',
      listClass: 'danger',
      isDefault: 'N',
      status: '0'
    }
  ],
  msg_channel: [
    {
      dictCode: 38,
      dictLabel: '短信',
      dictValue: 'sms',
      dictType: 'msg_channel',
      listClass: 'primary',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 39,
      dictLabel: '邮件',
      dictValue: 'email',
      dictType: 'msg_channel',
      listClass: 'success',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 40,
      dictLabel: '站内推送',
      dictValue: 'site',
      dictType: 'msg_channel',
      listClass: 'info',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 41,
      dictLabel: '小程序',
      dictValue: 'miniapp',
      dictType: 'msg_channel',
      listClass: 'warning',
      isDefault: 'N',
      status: '0'
    }
  ],
  feedback_type: [
    {
      dictCode: 48,
      dictLabel: '功能异常',
      dictValue: '0',
      dictType: 'feedback_type',
      listClass: 'danger',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 49,
      dictLabel: '体验建议',
      dictValue: '1',
      dictType: 'feedback_type',
      listClass: 'primary',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 50,
      dictLabel: '账号问题',
      dictValue: '2',
      dictType: 'feedback_type',
      listClass: 'warning',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 51,
      dictLabel: '其他',
      dictValue: '3',
      dictType: 'feedback_type',
      listClass: 'info',
      isDefault: 'N',
      status: '0'
    }
  ],
  ticket_status: [
    {
      dictCode: 52,
      dictLabel: '待处理',
      dictValue: '0',
      dictType: 'ticket_status',
      listClass: 'warning',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 53,
      dictLabel: '处理中',
      dictValue: '1',
      dictType: 'ticket_status',
      listClass: 'primary',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 54,
      dictLabel: '已解决',
      dictValue: '2',
      dictType: 'ticket_status',
      listClass: 'success',
      isDefault: 'N',
      status: '0'
    }
  ],
  interview_mode: [
    {
      dictCode: 55,
      dictLabel: '纯 AI 面试',
      dictValue: '0',
      dictType: 'interview_mode',
      listClass: 'primary',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 56,
      dictLabel: 'AI+HR 协同',
      dictValue: '1',
      dictType: 'interview_mode',
      listClass: 'success',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 57,
      dictLabel: '级联面试',
      dictValue: '2',
      dictType: 'interview_mode',
      listClass: 'warning',
      isDefault: 'N',
      status: '0'
    }
  ],
  interview_status: [
    {
      dictCode: 58,
      dictLabel: '待开始',
      dictValue: '0',
      dictType: 'interview_status',
      listClass: 'info',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 59,
      dictLabel: '进行中',
      dictValue: '1',
      dictType: 'interview_status',
      listClass: 'primary',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 60,
      dictLabel: '已完成',
      dictValue: '2',
      dictType: 'interview_status',
      listClass: 'success',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 61,
      dictLabel: '异常',
      dictValue: '3',
      dictType: 'interview_status',
      listClass: 'danger',
      isDefault: 'N',
      status: '0'
    }
  ],
  job_audit_status: [
    {
      dictCode: 62,
      dictLabel: '待审核',
      dictValue: '0',
      dictType: 'job_audit_status',
      listClass: 'warning',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 63,
      dictLabel: '已发布',
      dictValue: '1',
      dictType: 'job_audit_status',
      listClass: 'success',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 64,
      dictLabel: '违规下架',
      dictValue: '2',
      dictType: 'job_audit_status',
      listClass: 'danger',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 65,
      dictLabel: '已下架',
      dictValue: '3',
      dictType: 'job_audit_status',
      listClass: 'info',
      isDefault: 'N',
      status: '0'
    }
  ],
  risk_level: [
    {
      dictCode: 66,
      dictLabel: '低',
      dictValue: '0',
      dictType: 'risk_level',
      listClass: 'success',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 67,
      dictLabel: '中',
      dictValue: '1',
      dictType: 'risk_level',
      listClass: 'warning',
      isDefault: 'N',
      status: '0'
    },
    {
      dictCode: 68,
      dictLabel: '高',
      dictValue: '2',
      dictType: 'risk_level',
      listClass: 'danger',
      isDefault: 'N',
      status: '0'
    }
  ]
}

// ===== 日志与监控：操作日志 =====
export const operLogs = [
  {
    operId: 1,
    title: '租户模块',
    businessType: '2',
    method: 'com.aihire.web.tenant.TenantCompanyController.edit()',
    requestMethod: 'PUT',
    operName: 'admin',
    operUrl: '/tenant/company',
    operIp: '192.168.1.23',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-06 09:21:12'
  },
  {
    operId: 2,
    title: 'AI配置模块',
    businessType: '2',
    method: 'com.aihire.web.ai.AiModelController.edit()',
    requestMethod: 'PUT',
    operName: 'tech01',
    operUrl: '/ai/model',
    operIp: '192.168.1.45',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-06 10:03:44'
  },
  {
    operId: 3,
    title: '广告管理',
    businessType: '1',
    method: 'com.aihire.web.ad.AdvertController.add()',
    requestMethod: 'POST',
    operName: 'ops01',
    operUrl: '/ad/advert',
    operIp: '10.0.0.12',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-06 10:47:21'
  },
  {
    operId: 4,
    title: 'AI配置模块',
    businessType: '2',
    method: 'com.aihire.web.ai.AiQuotaController.adjust()',
    requestMethod: 'PUT',
    operName: 'ops02',
    operUrl: '/ai/quota/adjust',
    operIp: '192.168.3.18',
    status: '1',
    errorMsg: '配额调整原因不能为空',
    operTime: '2026-09-06 11:02:05'
  },
  {
    operId: 5,
    title: '租户模块',
    businessType: '8',
    method: 'com.aihire.web.tenant.TenantCompanyController.export()',
    requestMethod: 'POST',
    operName: 'admin',
    operUrl: '/tenant/company/export',
    operIp: '10.0.0.12',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-06 11:26:48'
  },
  {
    operId: 6,
    title: '消息模板模块',
    businessType: '1',
    method: 'com.aihire.web.msg.MsgTemplateController.add()',
    requestMethod: 'POST',
    operName: 'ops01',
    operUrl: '/msg/template',
    operIp: '192.168.1.45',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-06 13:15:30'
  },
  {
    operId: 7,
    title: '评估评分卡模块',
    businessType: '2',
    method: 'com.aihire.web.ai.ScorecardController.edit()',
    requestMethod: 'PUT',
    operName: 'ops02',
    operUrl: '/ai/scorecard',
    operIp: '192.168.1.46',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-06 13:30:22'
  },
  {
    operId: 8,
    title: '岗位审核模块',
    businessType: '2',
    method: 'com.aihire.web.biz.JobAuditController.audit()',
    requestMethod: 'PUT',
    operName: 'ops01',
    operUrl: '/biz/job/audit',
    operIp: '192.168.1.45',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-06 14:12:40'
  },
  {
    operId: 9,
    title: 'C端用户模块',
    businessType: '3',
    method: 'com.aihire.web.member.MemberUserController.remove()',
    requestMethod: 'DELETE',
    operName: 'ops02',
    operUrl: '/member/user',
    operIp: '192.168.1.46',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-06 14:25:18'
  },
  {
    operId: 10,
    title: '字典管理模块',
    businessType: '2',
    method: 'com.aihire.web.system.SysDictDataController.edit()',
    requestMethod: 'PUT',
    operName: 'admin',
    operUrl: '/system/dict/data',
    operIp: '192.168.1.23',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-06 14:40:55'
  },
  {
    operId: 11,
    title: '提示词模板模块',
    businessType: '1',
    method: 'com.aihire.web.ai.AiPromptController.add()',
    requestMethod: 'POST',
    operName: 'tech01',
    operUrl: '/ai/prompt',
    operIp: '192.168.1.45',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-06 15:05:33'
  },
  {
    operId: 12,
    title: '用户管理模块',
    businessType: '1',
    method: 'com.aihire.web.system.SysUserController.add()',
    requestMethod: 'POST',
    operName: 'admin',
    operUrl: '/system/user',
    operIp: '192.168.1.23',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-05 16:22:10'
  },
  {
    operId: 13,
    title: '面试题库模块',
    businessType: '2',
    method: 'com.aihire.web.content.QuestionController.edit()',
    requestMethod: 'PUT',
    operName: 'tech01',
    operUrl: '/content/question',
    operIp: '192.168.1.45',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-05 14:10:44'
  },
  {
    operId: 14,
    title: '面试监控模块',
    businessType: '2',
    method: 'com.aihire.web.biz.InterviewMonitorController.terminate()',
    requestMethod: 'PUT',
    operName: 'ops01',
    operUrl: '/biz/interview/terminate',
    operIp: '192.168.1.45',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-05 12:35:20'
  },
  {
    operId: 15,
    title: '操作日志模块',
    businessType: '11',
    method: 'com.aihire.web.monitor.OperlogController.clean()',
    requestMethod: 'DELETE',
    operName: 'admin',
    operUrl: '/monitor/operlog/clean',
    operIp: '192.168.1.23',
    status: '0',
    errorMsg: '',
    operTime: '2026-09-05 10:00:00'
  }
]

// ===== 日志与监控：登录日志 =====
export const logininforLogs = [
  {
    infoId: 1,
    userName: 'admin',
    ipaddr: '192.168.1.23',
    loginLocation: '内网',
    browser: 'Chrome 132',
    os: 'Windows 11',
    status: '0',
    msg: '登录成功',
    loginTime: '2026-09-06 08:32:16'
  },
  {
    infoId: 2,
    userName: 'ops01',
    ipaddr: '192.168.1.45',
    loginLocation: '内网',
    browser: 'Chrome 132',
    os: 'Windows 11',
    status: '0',
    msg: '登录成功',
    loginTime: '2026-09-06 09:58:22'
  },
  {
    infoId: 3,
    userName: 'tech01',
    ipaddr: '10.0.0.12',
    loginLocation: '内网',
    browser: 'Edge 132',
    os: 'Windows 11',
    status: '0',
    msg: '登录成功',
    loginTime: '2026-09-06 09:41:05'
  },
  {
    infoId: 4,
    userName: 'zhangsan',
    ipaddr: '58.34.102.11',
    loginLocation: '上海市',
    browser: 'Firefox 135',
    os: 'Windows 10',
    status: '1',
    msg: '密码错误',
    loginTime: '2026-09-06 10:12:40'
  },
  {
    infoId: 5,
    userName: 'ops02',
    ipaddr: '192.168.1.46',
    loginLocation: '内网',
    browser: 'Chrome 132',
    os: 'Windows 11',
    status: '0',
    msg: '登录成功',
    loginTime: '2026-09-06 09:30:15'
  },
  {
    infoId: 6,
    userName: 'linxiao01',
    ipaddr: '117.136.8.11',
    loginLocation: '浙江省杭州市',
    browser: 'Chrome 132',
    os: 'Windows 11',
    status: '0',
    msg: '登录成功',
    loginTime: '2026-09-06 21:40:12'
  },
  {
    infoId: 7,
    userName: 'kevin_w',
    ipaddr: '58.34.102.11',
    loginLocation: '上海市',
    browser: 'Firefox 135',
    os: 'Windows 10',
    status: '0',
    msg: '登录成功',
    loginTime: '2026-09-06 19:22:45'
  },
  {
    infoId: 8,
    userName: 'pm_xin',
    ipaddr: '58.192.2.31',
    loginLocation: '江苏省南京市',
    browser: 'Chrome 132',
    os: 'Windows 11',
    status: '0',
    msg: '登录成功',
    loginTime: '2026-09-06 22:18:03'
  },
  {
    infoId: 9,
    userName: 'hr_zhang',
    ipaddr: '111.20.4.88',
    loginLocation: '湖北省武汉市',
    browser: 'Edge 132',
    os: 'Windows 10',
    status: '0',
    msg: '登录成功',
    loginTime: '2026-09-06 23:01:09'
  },
  {
    infoId: 10,
    userName: 'test_user',
    ipaddr: '221.192.8.66',
    loginLocation: '四川省成都市',
    browser: 'Safari',
    os: 'macOS',
    status: '1',
    msg: '账号已锁定',
    loginTime: '2026-09-06 22:55:30'
  }
]

// ===== 日志与监控：在线用户 =====
export const onlineUsers = [
  {
    tokenId: 'a1b2c3d4e5f6',
    userName: 'admin',
    deptName: 'AI招聘管理系统',
    ipaddr: '192.168.1.23',
    loginLocation: '内网',
    browser: 'Chrome 132',
    os: 'Windows 11',
    loginTime: '2026-09-06 08:32:16',
    lastAccessTime: '2026-09-06 15:26:40'
  },
  {
    tokenId: 'b2c3d4e5f6g7',
    userName: 'ops01',
    deptName: '运营部',
    ipaddr: '192.168.1.45',
    loginLocation: '内网',
    browser: 'Chrome 132',
    os: 'Windows 11',
    loginTime: '2026-09-06 09:58:22',
    lastAccessTime: '2026-09-06 15:20:11'
  },
  {
    tokenId: 'c3d4e5f6g7h8',
    userName: 'tech01',
    deptName: '技术部',
    ipaddr: '10.0.0.12',
    loginLocation: '内网',
    browser: 'Edge 132',
    os: 'Windows 11',
    loginTime: '2026-09-06 09:41:05',
    lastAccessTime: '2026-09-06 14:55:33'
  },
  {
    tokenId: 'd4e5f6g7h8i9',
    userName: 'ops02',
    deptName: '运营部',
    ipaddr: '192.168.1.46',
    loginLocation: '内网',
    browser: 'Chrome 132',
    os: 'Windows 11',
    loginTime: '2026-09-06 09:30:15',
    lastAccessTime: '2026-09-06 15:10:22'
  },
  {
    tokenId: 'e5f6g7h8i9j0',
    userName: 'fin01',
    deptName: '财务部',
    ipaddr: '192.168.2.15',
    loginLocation: '内网',
    browser: 'Chrome 132',
    os: 'macOS',
    loginTime: '2026-09-06 10:05:30',
    lastAccessTime: '2026-09-06 14:30:18'
  },
  {
    tokenId: 'f6g7h8i9j0k1',
    userName: 'linxiao01',
    deptName: '-',
    ipaddr: '117.136.8.11',
    loginLocation: '浙江省杭州市',
    browser: 'Chrome 132',
    os: 'Windows 11',
    loginTime: '2026-09-06 21:40:12',
    lastAccessTime: '2026-09-06 21:52:30'
  },
  {
    tokenId: 'g7h8i9j0k1l2',
    userName: 'kevin_w',
    deptName: '-',
    ipaddr: '58.34.102.11',
    loginLocation: '上海市',
    browser: 'Firefox 135',
    os: 'Windows 10',
    loginTime: '2026-09-06 19:22:45',
    lastAccessTime: '2026-09-06 19:30:05'
  },
  {
    tokenId: 'h8i9j0k1l2m3',
    userName: 'pm_xin',
    deptName: '-',
    ipaddr: '58.192.2.31',
    loginLocation: '江苏省南京市',
    browser: 'Chrome 132',
    os: 'Windows 11',
    loginTime: '2026-09-06 22:18:03',
    lastAccessTime: '2026-09-06 22:20:40'
  }
]

// ===== 日志与监控：定时任务 =====
export const jobs = [
  {
    jobId: 1,
    jobName: '每日配额重置',
    jobGroup: 'DEFAULT',
    invokeTarget: 'quotaTask.reset',
    cronExpression: '0 0 0 * * ?',
    misfirePolicy: '3',
    concurrent: '1',
    status: '0',
    nextValidTime: '2026-09-08 00:00:00',
    createTime: '2024-01-05 10:24:31'
  },
  {
    jobId: 2,
    jobName: '日志自动归档（90天）',
    jobGroup: 'DEFAULT',
    invokeTarget: 'logTask.archive',
    cronExpression: '0 30 2 * * ?',
    misfirePolicy: '3',
    concurrent: '1',
    status: '0',
    nextValidTime: '2026-09-08 02:30:00',
    createTime: '2024-01-05 10:24:31'
  },
  {
    jobId: 3,
    jobName: '企业到期提醒',
    jobGroup: 'DEFAULT',
    invokeTarget: 'tenantTask.expireRemind',
    cronExpression: '0 0 9 * * ?',
    misfirePolicy: '3',
    concurrent: '1',
    status: '0',
    nextValidTime: '2026-09-08 09:00:00',
    createTime: '2024-01-05 10:24:31'
  },
  {
    jobId: 4,
    jobName: 'AI 调用量日报',
    jobGroup: 'DEFAULT',
    invokeTarget: 'aiTask.dailyReport',
    cronExpression: '0 0 8 * * ?',
    misfirePolicy: '3',
    concurrent: '1',
    status: '0',
    nextValidTime: '2026-09-08 08:00:00',
    createTime: '2024-01-05 10:24:31'
  }
]

// ===== 系统监控：服务状态 =====
export const serverInfo = {
  cpu: { cpuNum: 8, total: 92.3, sys: 28.5, used: 32.0, wait: 2.1, free: 65.7 },
  mem: { total: 16.0, used: 7.7, free: 8.3, usage: 48.1 },
  jvm: {
    total: 1024.0,
    max: 2048.0,
    free: 612.5,
    version: 'Java 17.0.10',
    home: '/usr/lib/jvm/jdk-17',
    usage: 40.2,
    startTime: '2026-09-06 08:00:12',
    runTime: '7小时26分',
    inputArgs: '-Xms1024m -Xmx2048m',
    name: 'OpenJDK 64-Bit Server VM'
  },
  sys: {
    computerName: 'ai-recruit-prod-01',
    osName: 'Linux (Ubuntu 22.04 LTS)',
    computerIp: '10.0.0.12',
    osArch: 'amd64',
    userDir: '/opt/ai-recruit'
  },
  sysFiles: [
    { dirName: '/', sysTypeName: 'ext4', typeName: '本地磁盘', total: 200, free: 74, used: 126, usage: 63.0 },
    { dirName: '/data', sysTypeName: 'xfs', typeName: '数据盘', total: 1000, free: 620, used: 380, usage: 38.0 }
  ]
}
