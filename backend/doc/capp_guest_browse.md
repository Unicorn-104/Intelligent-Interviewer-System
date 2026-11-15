# C-App 游客浏览与登录

## 客户端行为

未登录时进入游客首页，推荐区提示登录后可用，岗位入口支持公开搜索和详情浏览。
游客隐藏投递、收藏、面试日程等私人能力；简历、消息、我的入口弹出「不了 / 登录」。
岗位详情不加载私人收藏状态，企业信息保留静态展示，企业主页跳转只在登录后开放。

登录成功关闭登录页并更新首页；会话改变时重建首页及其面试日程控制器，隔离旧凭据和旧请求。
退出登录先返回根路由，再进入游客首页，重置不再可用的底部页签。
认证过期弹窗选择重新登录时清理过期会话并打开登录页，不以静默空日程掩盖认证错误。

## 公开接口

以下接口仅放行 GET，统一响应为 code/msg/data。公开接口不执行任何投递、收藏或私人资料写入。

| 路径 | 参数与响应 |
| --- | --- |
| `/app/jobs` | 兼容原聚合列表 keyword/filter/limit；匿名无个人上下文，登录保留原用户语义 |
| `/app/jobs/search` | 复用 AgentJobQuery 的筛选和分页；data 含 items/page/size/total/hasNext |
| `/app/jobs/filter-options` | 返回当前可用岗位的城市、类别、经验、行业、规模等筛选选项 |
| `/app/jobs/public/{positionId}` | 返回公开岗位详情；不存在或已下线时拒绝读取 |

公开搜索始终以 null 用户身份执行，并丢弃 resumeId，不能读取指定简历或私人匹配上下文。
城市、类别、经验、行业、规模、排序和分页参数继续使用已有服务校验与 SQL；salary 为薪资排序，
不再映射为旧列表的 urgent 筛选。游客的默认匹配排序没有个人简历上下文，不表示个性化推荐。

登录客户端继续使用 `/agent/v1/jobs` 及其筛选接口；分享岗位在游客状态使用公开详情。
`/app/jobs/favorites`、`/app/jobs/{id}/favorite`、投递、面试、简历和知识库仍需登录。
不放行 `/app/jobs/**`，不改变其他端登录接口或权限。

## 验证与限制

AppJobControllerTest 检查匿名/登录用户透传、公开筛选分页、简历上下文隔离及下线岗位拒绝。
GuestJobSecurityTest 通过实际 SecurityConfig 构建过滤链，检查公开 GET 与私人接口边界。
客户端 guest_browse_contract_test 检查完整筛选、分页和无 Authorization 请求；
guest_job_detail_test 检查游客不调用收藏接口；widget_test 和 home_session_transition_test
分别覆盖受限入口登录和会话切换。

控制器替身测试不代替真实 MySQL、跨账号、服务器和目标设备验收。
新公开路由需要与后端一起部署；不要把新客户端连接到只有旧路由的服务器验收。
回滚时协调客户端游客入口与后端放行规则，通过 revert 保留共享历史。
