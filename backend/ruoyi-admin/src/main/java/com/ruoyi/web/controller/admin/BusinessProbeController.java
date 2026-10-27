package com.ruoyi.web.controller.admin;

import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 业务数据探查台
 *
 * @author TQY
 */
@RestController
@RequestMapping("/admin/probe")
public class BusinessProbeController extends BaseController {

    @Autowired
    private JdbcTemplate jdbc;

    /** 岗位投递漏斗 */
    @GetMapping("/jobFunnel")
    public AjaxResult jobFunnel(@RequestParam(required = false) Long posId) {
        List<Map<String, Object>> rows = new ArrayList<>();
        if (posId != null) {
            long applied = queryForLong("SELECT COUNT(*) FROM t_tal WHERE pos_id=?", posId);
            long interviewed = queryForLong("SELECT COUNT(*) FROM t_tal WHERE pos_id=? AND tal_status>=2", posId);
            long offered = queryForLong("SELECT COUNT(*) FROM t_tal WHERE pos_id=? AND tal_status>=4", posId);
            rows.add(stage("投递", applied));
            rows.add(stage("进面", interviewed));
            rows.add(stage("Offer", offered));
        } else {
            List<Map<String, Object>> posList = jdbc.queryForList(
                    "SELECT pos_id, pos_title FROM t_pos ORDER BY pos_id DESC LIMIT 50");
            return AjaxResult.success(posList);
        }
        return AjaxResult.success(rows);
    }

    /** 企业用量 */
    @GetMapping("/companyUsage")
    public AjaxResult companyUsage(@RequestParam(required = false) Long companyId) {
        if (companyId == null) {
            List<Map<String, Object>> list = jdbc.queryForList(
                    "SELECT cmp_id AS company_id, cmp_name AS company_name FROM t_cmp ORDER BY cmp_id DESC LIMIT 50");
            return AjaxResult.success(list);
        }
        Map<String, Object> res = new HashMap<>();
        res.put("employees", queryForLong("SELECT COUNT(*) FROM sys_user WHERE company_id=?", companyId));
        res.put("jobs", queryForLong("SELECT COUNT(*) FROM t_pos WHERE cmp_id=?", companyId));
        res.put("candidates", queryForLong("SELECT COUNT(*) FROM t_tal WHERE cmp_id=?", companyId));
        res.put("interviews", queryForLong("SELECT COUNT(*) FROM t_exam_record WHERE cmp_id=?", companyId));
        return AjaxResult.success(res);
    }

    /** 候选人全链路 */
    @GetMapping("/talentTrace")
    public AjaxResult talentTrace(@RequestParam(required = false) Long talId) {
        if (talId == null) {
            List<Map<String, Object>> list = jdbc.queryForList(
                    "SELECT t.tal_id, u.nick_name AS tal_name FROM t_tal t LEFT JOIN sys_user u ON t.tal_user_id=u.user_id ORDER BY t.tal_id DESC LIMIT 50");
            return AjaxResult.success(list);
        }
        Map<String, Object> res = new HashMap<>();
        try {
            res.put("info", jdbc.queryForMap(
                    "SELECT t.tal_id, u.nick_name AS tal_name, t.tal_status, t.pos_id, t.tal_created_at AS created_at FROM t_tal t LEFT JOIN sys_user u ON t.tal_user_id=u.user_id WHERE t.tal_id=?", talId));
        } catch (Exception e) {
            return AjaxResult.error("候选人不存在");
        }
        res.put("interviews", jdbc.queryForList("SELECT * FROM t_exam_record WHERE tal_id=? ORDER BY exam_id DESC", talId));
        return AjaxResult.success(res);
    }

    /** 全局概览 */
    @GetMapping("/overview")
    public AjaxResult overview() {
        Map<String, Object> res = new HashMap<>();
        res.put("jobs", queryForLong("SELECT COUNT(*) FROM t_pos"));
        res.put("talents", queryForLong("SELECT COUNT(*) FROM t_tal"));
        res.put("companies", queryForLong("SELECT COUNT(*) FROM t_cmp"));
        res.put("interviews", queryForLong("SELECT COUNT(*) FROM t_exam_record"));
        res.put("todayNewTalents", queryForLong("SELECT COUNT(*) FROM t_tal WHERE DATE(tal_created_at)=CURDATE()"));
        res.put("pendingJobs", queryForLong("SELECT COUNT(*) FROM t_pos WHERE pos_status='0'"));
        res.put("pendingVerify", queryForLong("SELECT COUNT(*) FROM t_usr_verify WHERE vrf_status='0'"));
        return AjaxResult.success(res);
    }

    /** 最近错误日志 */
    @GetMapping("/recentErrors")
    public AjaxResult recentErrors() {
        List<Map<String, Object>> list = jdbc.queryForList(
                "SELECT oper_id, oper_name, oper_url, oper_param, oper_time, status, error_msg " +
                "FROM sys_oper_log WHERE status='1' ORDER BY oper_id DESC LIMIT 10");
        return AjaxResult.success(list);
    }

    private long queryForLong(String sql, Object... args) {
        try {
            Long n = jdbc.queryForObject(sql, Long.class, args);
            return n == null ? 0 : n;
        } catch (Exception e) {
            return 0;
        }
    }

    private Map<String, Object> stage(String name, long count) {
        Map<String, Object> m = new HashMap<>();
        m.put("stage", name);
        m.put("count", count);
        return m;
    }
}
