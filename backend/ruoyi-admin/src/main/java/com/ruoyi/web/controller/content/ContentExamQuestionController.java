package com.ruoyi.web.controller.content;

import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.sql.PreparedStatement;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * 考试题库管理：平台题库（eqs_company_id 为空）与企业题库（eqs_company_id 有值）共用一张表。
 * 题型：1 单选、2 多选、3 判断、4 简答、5 编程。
 */
@RestController
@RequestMapping("/content/examQuestion")
public class ContentExamQuestionController extends BaseController {

    private static final String COLUMNS =
            "e.eqs_id AS id, e.eqs_type AS type, e.eqs_type_name AS typeName, e.eqs_content AS content, " +
            "e.eqs_options_json AS optionsJson, e.eqs_answer AS answer, e.eqs_analysis AS analysis, " +
            "e.eqs_score AS score, e.eqs_difficulty AS difficulty, e.eqs_company_id AS companyId, " +
            "e.eqs_skill_tag AS skillTag, e.eqs_category AS category, e.eqs_created_at AS createTime, " +
            "e.eqs_updated_at AS updateTime, c.cmp_name AS companyName";

    private static final String FROM_CLAUSE =
            " FROM t_exam_question e LEFT JOIN t_cmp c ON c.cmp_id = e.eqs_company_id";

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /** 导入批次记录，单条新增也记一条（类型 2）。 */
    @Autowired
    private com.ruoyi.system.service.exam.IExamImportLogService examImportLogService;

    @PreAuthorize("@ss.hasPermi('content:question:list')")
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) String bankType,
                              @RequestParam(required = false) Long companyId,
                              @RequestParam(required = false) Integer type,
                              @RequestParam(required = false) Integer category,
                              @RequestParam(required = false) Integer difficulty,
                              @RequestParam(required = false) String keyword) {
        StringBuilder sql = new StringBuilder("SELECT " + COLUMNS + FROM_CLAUSE + " WHERE 1=1");
        List<Object> args = new ArrayList<>();
        if ("platform".equals(bankType)) {
            sql.append(" AND e.eqs_company_id IS NULL");
        } else if ("enterprise".equals(bankType)) {
            sql.append(" AND e.eqs_company_id IS NOT NULL");
            if (companyId != null) {
                sql.append(" AND e.eqs_company_id = ?");
                args.add(companyId);
            }
        }
        if (type != null) {
            sql.append(" AND e.eqs_type = ?");
            args.add(type);
        }
        if (category != null) {
            sql.append(" AND e.eqs_category = ?");
            args.add(category);
        }
        if (difficulty != null) {
            sql.append(" AND e.eqs_difficulty = ?");
            args.add(difficulty);
        }
        if (keyword != null && !keyword.isBlank()) {
            sql.append(" AND e.eqs_content LIKE ?");
            args.add("%" + keyword.trim() + "%");
        }
        sql.append(" ORDER BY e.eqs_id DESC");
        startPage();
        return getDataTable(jdbcTemplate.queryForList(sql.toString(), args.toArray()));
    }

    @PreAuthorize("@ss.hasPermi('content:question:list')")
    @GetMapping("/{id}")
    public AjaxResult detail(@PathVariable Long id) {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                "SELECT " + COLUMNS + FROM_CLAUSE + " WHERE e.eqs_id = ?", id);
        if (rows.isEmpty()) {
            return error("题目不存在");
        }
        return success(rows.get(0));
    }

    @PreAuthorize("@ss.hasPermi('content:question:add')")
    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> body) {
        String invalid = validate(body);
        if (invalid != null) {
            return error(invalid);
        }
        Long companyId = toLong(body.get("companyId"));
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement(
                    "INSERT INTO t_exam_question (eqs_type, eqs_type_name, eqs_content, eqs_options_json, " +
                    "eqs_answer, eqs_analysis, eqs_score, eqs_difficulty, eqs_company_id, eqs_skill_tag, eqs_category) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    new String[] { "eqs_id" });
            ps.setObject(1, toInt(body.get("type")));
            ps.setObject(2, str(body.get("typeName")));
            ps.setObject(3, str(body.get("content")));
            ps.setObject(4, optionsJson(body));
            ps.setObject(5, str(body.get("answer")));
            ps.setObject(6, str(body.get("analysis")));
            ps.setObject(7, toScore(body.get("score")));
            ps.setObject(8, toInt(body.get("difficulty")));
            ps.setObject(9, companyId);
            ps.setObject(10, str(body.get("skillTag")));
            ps.setObject(11, toCategory(body.get("category")));
            return ps;
        }, keyHolder);
        Number key = keyHolder.getKey();
        Long newId = key == null ? null : key.longValue();
        if (newId != null) {
            examImportLogService.record(2, null, companyId, 1, 1, 0,
                    Collections.singletonList(newId), getUsername());
        }
        AjaxResult result = success();
        result.put("id", newId);
        return result;
    }

    @PreAuthorize("@ss.hasPermi('content:question:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> body) {
        Long id = toLong(body.get("id"));
        if (id == null) {
            return error("题目ID不能为空");
        }
        String invalid = validate(body);
        if (invalid != null) {
            return error(invalid);
        }
        jdbcTemplate.update(
                "UPDATE t_exam_question SET eqs_type = ?, eqs_type_name = ?, eqs_content = ?, " +
                "eqs_options_json = ?, eqs_answer = ?, eqs_analysis = ?, eqs_score = ?, " +
                "eqs_difficulty = ?, eqs_company_id = ?, eqs_skill_tag = ?, eqs_category = ? WHERE eqs_id = ?",
                toInt(body.get("type")), str(body.get("typeName")), str(body.get("content")),
                optionsJson(body), str(body.get("answer")), str(body.get("analysis")),
                toScore(body.get("score")), toInt(body.get("difficulty")),
                toLong(body.get("companyId")), str(body.get("skillTag")), toCategory(body.get("category")), id);
        return success();
    }

    @PreAuthorize("@ss.hasPermi('content:question:remove')")
    @DeleteMapping("/{ids}")
    public AjaxResult remove(@PathVariable Long[] ids) {
        for (Long id : ids) {
            jdbcTemplate.update("DELETE FROM t_exam_question WHERE eqs_id = ?", id);
        }
        return success();
    }

    /** 分类统计（顶部统计卡数据） */
    @PreAuthorize("@ss.hasPermi('content:question:list')")
    @GetMapping("/stats")
    public AjaxResult stats(@RequestParam(required = false) String bankType,
                            @RequestParam(required = false) Long companyId) {
        StringBuilder sql = new StringBuilder(
                "SELECT e.eqs_category AS category, COUNT(*) AS cnt FROM t_exam_question e WHERE 1=1");
        List<Object> args = new ArrayList<>();
        if ("platform".equals(bankType)) {
            sql.append(" AND e.eqs_company_id IS NULL");
        } else if ("enterprise".equals(bankType)) {
            sql.append(" AND e.eqs_company_id IS NOT NULL");
            if (companyId != null) {
                sql.append(" AND e.eqs_company_id = ?");
                args.add(companyId);
            }
        }
        sql.append(" GROUP BY e.eqs_category ORDER BY e.eqs_category");
        return success(jdbcTemplate.queryForList(sql.toString(), args.toArray()));
    }

    /** 企业下拉数据（仅正常状态企业），供"企业自定义题库"选择归属 */
    @PreAuthorize("@ss.hasPermi('content:question:list')")
    @GetMapping("/companies")
    public AjaxResult companies() {
        return success(jdbcTemplate.queryForList(
                "SELECT cmp_id AS id, cmp_name AS name FROM t_cmp WHERE cmp_status = 1 ORDER BY cmp_id"));
    }

    /** 企业题库总览：每个企业的题目量与分类分布，供企业题库折叠面板使用 */
    @PreAuthorize("@ss.hasPermi('content:question:list')")
    @GetMapping("/companyOverview")
    public AjaxResult companyOverview() {
        String sql = "SELECT c.cmp_id AS id, c.cmp_name AS name, COUNT(e.eqs_id) AS total, " +
                "SUM(CASE WHEN e.eqs_category = 1 THEN 1 ELSE 0 END) AS c1, " +
                "SUM(CASE WHEN e.eqs_category = 2 THEN 1 ELSE 0 END) AS c2, " +
                "SUM(CASE WHEN e.eqs_category = 3 THEN 1 ELSE 0 END) AS c3, " +
                "SUM(CASE WHEN e.eqs_category = 4 THEN 1 ELSE 0 END) AS c4, " +
                "SUM(CASE WHEN e.eqs_category = 5 THEN 1 ELSE 0 END) AS c5 " +
                "FROM t_cmp c LEFT JOIN t_exam_question e ON e.eqs_company_id = c.cmp_id " +
                "WHERE c.cmp_status = 1 GROUP BY c.cmp_id, c.cmp_name ORDER BY c.cmp_id";
        return success(jdbcTemplate.queryForList(sql));
    }

    /** 必填与题型约束校验，返回 null 表示通过 */
    private String validate(Map<String, Object> body) {
        Integer type = toInt(body.get("type"));
        if (type == null || type < 1 || type > 5) {
            return "题目类型必须是 1-5（1单选 2多选 3判断 4简答 5编程）";
        }
        if (isBlank(str(body.get("content")))) {
            return "题目内容不能为空";
        }
        if (isBlank(str(body.get("answer")))) {
            return "正确答案不能为空";
        }
        Object score = body.get("score");
        if (score == null || toScore(score).compareTo(BigDecimal.ZERO) <= 0) {
            return "分值必须大于 0";
        }
        if (type == 1 || type == 2) {
            Object options = body.get("options");
            if (!(options instanceof List) || ((List<?>) options).size() < 2) {
                return "单选/多选至少需要 2 个选项";
            }
        }
        return null;
    }

    /** 选项数组转 JSON 存储；非选择题返回 null */
    private String optionsJson(Map<String, Object> body) {
        Integer type = toInt(body.get("type"));
        if (type == null || type == 3 || type == 4 || type == 5) {
            return null;
        }
        Object options = body.get("options");
        return options instanceof List ? JSON.toJSONString(options) : null;
    }

    private String str(Object v) {
        return v == null ? null : String.valueOf(v);
    }

    private boolean isBlank(String v) {
        return v == null || v.trim().isEmpty();
    }

    private Integer toInt(Object v) {
        if (v == null || String.valueOf(v).isBlank()) {
            return null;
        }
        return Integer.valueOf(String.valueOf(v).trim());
    }

    private Long toLong(Object v) {
        if (v == null || String.valueOf(v).isBlank()) {
            return null;
        }
        return Long.valueOf(String.valueOf(v).trim());
    }

    /** 题目分类归一：非法或空值落到 1（专业题） */
    private Integer toCategory(Object v) {
        Integer c = toInt(v);
        return (c == null || c < 1 || c > 5) ? 1 : c;
    }

    private BigDecimal toScore(Object v) {
        if (v == null || String.valueOf(v).isBlank()) {
            return BigDecimal.ZERO;
        }
        return new BigDecimal(String.valueOf(v).trim());
    }
}
