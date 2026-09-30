# A-PC 目录说明

## 项目结构

```
Intelligent-Interviewer-System/
├── admin_pc/              # A-PC 管理员端（若依 Vue3）
│   └── RuoYi-Vue3/
│       ├── src/
│       │   ├── api/       # 接口请求
│       │   ├── views/     # 页面组件
│       │   ├── router/    # 路由配置
│       │   ├── store/     # 状态管理
│       │   └── utils/     # 工具函数
│       └── package.json
├── backend/               # 后端（若依 Spring Boot）
│   ├── ruoyi-admin/       # 启动模块
│   ├── ruoyi-system/      # 业务模块
│   └── ruoyi-common/      # 通用模块
├── docs/                  # 文档
│   └── spec/              # 开发规范
├── enterprise_pc/         # 企业端
└── user-PC/               # 用户端
```

## A-PC 启动方式

### 后端启动
```bash
cd backend
mvn spring-boot:run -pl ruoyi-admin
```
- 端口：8080
- 数据库：MySQL localhost:3306/recruit_agent
- Redis：localhost:6379

### 前端启动
```bash
cd admin_pc/RuoYi-Vue3
npm install
npm run dev
```
- 端口：5173

## 登录账号
- 账号：admin
- 密码：admin123

## 主要功能模块

### 用户管理
- 用户列表（/business/list）
- 实名认证（/business/verify）

### 企业管理
- 企业审核（/company/company/list）
- 企业用户（/company/user）

### AI配置
- 模型Provider（/ai/provider-list）
- Prompt版本（/ai/prompt-list）
- AI配额（/ai/quota-list）
- AI记分卡（/ai/scorecard）

### 系统管理（若依自带）
- 角色管理、菜单管理、部门管理、岗位管理
- 字典管理、参数设置、通知公告、日志管理

### 系统监控（若依自带）
- 在线用户、定时任务、数据监控、服务监控、缓存监控

### 系统工具（若依自带）
- 表单构建、代码生成、系统接口

## 权限指令

前端使用 `v-hasPermi` 指令控制按钮权限：
```vue
<el-button v-hasPermi="['system:user:add']">新增</el-button>
```

权限字符串格式：`模块:功能:操作`
