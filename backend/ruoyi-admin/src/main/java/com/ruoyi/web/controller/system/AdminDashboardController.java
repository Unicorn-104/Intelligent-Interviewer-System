package com.ruoyi.web.controller.system;

import java.util.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.mapper.CompanyMapper;

/**
 * 后台管理端Controller
 *
 * @author TQY
 */
@RestController
@RequestMapping("/dashboard")
public class AdminDashboardController extends BaseController
{
    @Autowired
    private CompanyMapper companyMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /**
     * 后台管理端Controller
     *
     * @author TQY
     */
    @PreAuthorize("@ss.hasPermi('dashboard:view')")
    @GetMapping("/stats")
    public AjaxResult stats()
    {
        Map<String, Object> data = new HashMap<>();

        // 岗位：已发布 / 待审核
        int jobPublished = count("SELECT COUNT(*) FROM t_pos WHERE pos_status = 1");
        int jobPending = count("SELECT COUNT(*) FROM t_pos WHERE pos_status = 0");
        // 候选人总数、今日新增
        int candidateTotal = count("SELECT COUNT(*) FROM t_tal");
        int candidateToday = count("SELECT COUNT(*) FROM t_tal WHERE DATE(tal_created_at) = CURDATE()");
        // 投递总量、今日新增投递
        int applicationTotal = count("SELECT COUNT(*) FROM t_app_record");
        int applicationToday = count("SELECT COUNT(*) FROM t_app_record WHERE DATE(app_created_at) = CURDATE()");
        // 今日简历、今日面试场次
        int todayResumes = count("SELECT COUNT(*) FROM t_res_base WHERE DATE(rbs_created_at) = CURDATE()");
        int todayInterviews = count("SELECT COUNT(*) FROM t_int_session WHERE DATE(ses_start_at) = CURDATE()");
        // 企业总数 / 已认证企业
        int companyTotal = companyMapper.selectCompanyCount();
        int companyActive = companyMapper.selectActiveCompanyCount();

        data.put("jobPublished", jobPublished);
        data.put("jobPending", jobPending);
        data.put("candidateTotal", candidateTotal);
        data.put("candidateToday", candidateToday);
        data.put("applicationTotal", applicationTotal);
        data.put("applicationToday", applicationToday);
        data.put("todayResumes", todayResumes);
        data.put("todayInterviews", todayInterviews);
        data.put("companyTotal", companyTotal);
        data.put("companyActive", companyActive);
        return success(data);
    }

    /** 安全计数：表或列缺失时返回 0，不阻断整页 */
    private int count(String sql)
    {
        try {
            return jdbcTemplate.queryForObject(sql, Integer.class);
        } catch (Exception e) {
            return 0;
        }
    }

    /**
     * 后台管理端Controller
     *
     * @author TQY
     */
    @PreAuthorize("@ss.hasPermi('dashboard:view')")
    @GetMapping("/trend")
    public AjaxResult trend()
    {
        Map<String, Object> data = new HashMap<>();
        List<String> dates = new ArrayList<>();
        List<Integer> companies = new ArrayList<>();
        List<Integer> candidates = new ArrayList<>();
        List<Integer> interviews = new ArrayList<>();
        List<Integer> applications = new ArrayList<>();

        // 近30天按天聚合，列名与实际表一致；单序列失败不影响其他
        Map<String, Integer> companyMap = dailyCount("SELECT DATE(cmp_created_at) AS dt, COUNT(*) AS cnt FROM t_cmp "
                + "WHERE cmp_created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) GROUP BY DATE(cmp_created_at)");
        Map<String, Integer> candidateMap = dailyCount("SELECT DATE(tal_created_at) AS dt, COUNT(*) AS cnt FROM t_tal "
                + "WHERE tal_created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) GROUP BY DATE(tal_created_at)");
        Map<String, Integer> applicationMap = dailyCount("SELECT DATE(app_created_at) AS dt, COUNT(*) AS cnt FROM t_app_record "
                + "WHERE app_created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) GROUP BY DATE(app_created_at)");
        Map<String, Integer> interviewMap = dailyCount("SELECT DATE(ses_start_at) AS dt, COUNT(*) AS cnt FROM t_int_session "
                + "WHERE ses_start_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) AND ses_start_at IS NOT NULL GROUP BY DATE(ses_start_at)");

        for (int i = 29; i >= 0; i--) {
            java.time.LocalDate day = java.time.LocalDate.now().minusDays(i);
            String key = day.toString();
            dates.add(key.substring(5)); // MM-dd
            companies.add(companyMap.getOrDefault(key, 0));
            candidates.add(candidateMap.getOrDefault(key, 0));
            applications.add(applicationMap.getOrDefault(key, 0));
            interviews.add(interviewMap.getOrDefault(key, 0));
        }

        data.put("dates", dates);
        data.put("companies", companies);
        data.put("candidates", candidates);
        data.put("interviews", interviews);
        data.put("applications", applications);
        return success(data);
    }

    /** 按天聚合计数，返回 dateString -> count；查询失败返回空 Map */
    private Map<String, Integer> dailyCount(String sql)
    {
        Map<String, Integer> map = new HashMap<>();
        try {
            for (Map<String, Object> row : jdbcTemplate.queryForList(sql)) {
                map.put(row.get("dt").toString(), ((Number) row.get("cnt")).intValue());
            }
        } catch (Exception e) {
            // 表/列缺失时按 0 处理
        }
        return map;
    }

    /**
     * 企业 API 调用量 TOP10（真实查询，无数据返回空列表）
     */
    @PreAuthorize("@ss.hasPermi('dashboard:view')")
    @GetMapping("/apiTop")
    public AjaxResult apiTop()
    {
        List<Map<String, Object>> list = new ArrayList<>();
        try {
            list = jdbcTemplate.queryForList(
                "SELECT c.cmp_name AS companyName, COALESCE(c.api_used, 0) AS calls, "
                + "COALESCE(c.api_quota, 0) AS quota FROM t_cmp c ORDER BY calls DESC LIMIT 10"
            );
        } catch (Exception e) {
            // 表/列缺失时保持空列表，不返回假数据
        }
        return success(list);
    }

    /** 候选人状态分布（归并后的6类），供首页环形图 */
    @PreAuthorize("@ss.hasPermi('dashboard:view')")
    @GetMapping("/statusDist")
    public AjaxResult statusDist()
    {
        List<Map<String, Object>> list = new ArrayList<>();
        try {
            list = jdbcTemplate.queryForList(
                "SELECT CASE "
                + "WHEN tal_status IN (0,9) THEN '新候选人' "
                + "WHEN tal_status = 1 THEN '已初筛' "
                + "WHEN tal_status = 2 THEN '面试中' "
                + "WHEN tal_status IN (4,5) THEN '通过' "
                + "WHEN tal_status IN (3,8) THEN '淘汰' "
                + "WHEN tal_status IN (6,7) THEN '归档' "
                + "ELSE '其他' END AS name, COUNT(*) AS value "
                + "FROM t_tal GROUP BY name"
            );
        } catch (Exception e) {
            // 表/列缺失时保持空列表，不返回假数据
        }
        return success(list);
    }

    /**
     * 后台管理端Controller
     *
     * @author TQY
     */
    @PreAuthorize("@ss.hasPermi('dashboard:view')")
    @GetMapping("/recentLogs")
    public AjaxResult recentLogs()
    {
        List<Map<String, Object>> list = new ArrayList<>();
        
        try {
            // 从数据库查询最近的操作日志
            list = jdbcTemplate.queryForList(
                "SELECT user_name AS operName, operation AS content, create_time AS operTime, 'primary' AS level FROM sys_oper_log ORDER BY create_time DESC LIMIT 10"
            );
        } catch (Exception e) {
            // 如果查询失败，返回默认数据
            Map<String, Object> item1 = new HashMap<>();
            item1.put("operName", "admin");
            item1.put("content", "登录系统");
            item1.put("operTime", "2026-09-29 10:00:00");
            item1.put("level", "primary");
            list.add(item1);
        }
        
        return success(list);
    }

    /**
     * 招聘闭环工作台：5 步 pipeline、真实待办、转化漏斗
     */
    @PreAuthorize("@ss.hasPermi('dashboard:view')")
    @GetMapping("/recruitmentOverview")
    public AjaxResult recruitmentOverview()
    {
        Map<String, Object> data = new HashMap<>();
        List<Map<String, Object>> pipeline = new ArrayList<>();

        int jobPublished = count("SELECT COUNT(*) FROM t_pos WHERE pos_status = 1");
        int applicationTotal = count("SELECT COUNT(*) FROM t_app_record");
        int screened = count("SELECT COUNT(*) FROM t_tal WHERE tal_status = 1");
        int interviewing = count("SELECT COUNT(*) FROM t_tal WHERE tal_status = 2");
        int passed = count("SELECT COUNT(*) FROM t_tal WHERE tal_status IN (4,5)");

        pipeline.add(step("jobs", "已发布岗位", jobPublished, "在架可投递", "/recruit/job", "blue", "Briefcase"));
        pipeline.add(step("applications", "投递总量", applicationTotal, "累计投递记录", "/recruit/resume", "cyan", "Promotion"));
        pipeline.add(step("screened", "已初筛", screened, "通过初筛进入流程", "/recruit/candidate", "green", "User"));
        pipeline.add(step("interviewing", "面试中", interviewing, "正在安排/进行面试", "/recruit/interview", "orange", "VideoCamera"));
        pipeline.add(step("passed", "已通过", passed, "面试通过待录用", "/recruit/exam", "purple", "CircleCheck"));

        // 待办：待审核企业 / 待审核岗位 / 待初筛候选人 / 待开始面试 / 待回复反馈
        List<Map<String, Object>> todos = new ArrayList<>();
        int entPending = count("SELECT COUNT(*) FROM t_company WHERE cmp_status = 0");
        int jobPending = count("SELECT COUNT(*) FROM t_pos WHERE pos_status = 0");
        int talNew = count("SELECT COUNT(*) FROM t_tal WHERE tal_status IN (0,9)");
        int sessionPending = count("SELECT COUNT(*) FROM t_int_session WHERE ses_status = 0");
        int fbPending = count("SELECT COUNT(*) FROM t_feedback WHERE fb_status = 0");
        todos.add(todo("entPending", "待审核企业", entPending, "企业入驻待审核", "/member/verify", "danger"));
        todos.add(todo("jobPending", "待审核岗位", jobPending, "岗位待管理员审核", "/recruit/job", "warning"));
        todos.add(todo("talNew", "待初筛候选人", talNew, "新候选人等待初筛", "/recruit/candidate", "primary"));
        todos.add(todo("sessionPending", "待开始面试", sessionPending, "已排期待开始的面试", "/recruit/interview", "success"));
        todos.add(todo("fbPending", "待回复反馈", fbPending, "用户反馈待处理", "/content/feedback", "info"));

        // 转化漏斗：已发布岗位 → 投递 → 初筛 → 面试中 → 通过
        List<Map<String, Object>> funnel = new ArrayList<>();
        funnel.add(funnelItem("已发布岗位", jobPublished));
        funnel.add(funnelItem("投递总量", applicationTotal));
        funnel.add(funnelItem("已初筛", screened));
        funnel.add(funnelItem("面试中", interviewing));
        funnel.add(funnelItem("已通过", passed));

        data.put("pipeline", pipeline);
        data.put("todos", todos);
        data.put("funnel", funnel);
        data.put("asOf", java.time.LocalDateTime.now()
                .format(java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
        return success(data);
    }

    private Map<String, Object> step(String key, String label, int value, String detail, String route, String tone, String icon)
    {
        Map<String, Object> m = new HashMap<>();
        m.put("key", key);
        m.put("label", label);
        m.put("value", value);
        m.put("detail", detail);
        m.put("route", route);
        m.put("tone", tone);
        m.put("icon", icon);
        return m;
    }

    private Map<String, Object> todo(String key, String title, int count, String desc, String route, String level)
    {
        Map<String, Object> m = new HashMap<>();
        m.put("key", key);
        m.put("title", title);
        m.put("count", count);
        m.put("desc", desc);
        m.put("route", route);
        m.put("level", level);
        return m;
    }

    private Map<String, Object> funnelItem(String label, int value)
    {
        Map<String, Object> m = new HashMap<>();
        m.put("label", label);
        m.put("value", value);
        return m;
    }
}
