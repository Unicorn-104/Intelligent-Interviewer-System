package com.ruoyi.web.controller.tenant;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.system.service.ICompanyService;
import com.ruoyi.system.domain.Company;
import java.util.*;

/**
 * 企业管理（对齐前端 /tenant/company 接口）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/tenant/company")
public class TenantCompanyController extends BaseController {

    @Autowired
    private ICompanyService companyService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('tenant:company:list')")
    @GetMapping("/list")
    public TableDataInfo list(
            @RequestParam(required = false) String companyName,
            @RequestParam(required = false) Integer verifyStatus,
            @RequestParam(required = false) Integer pageNum,
            @RequestParam(required = false) Integer pageSize) {
        startPage();
        Company query = new Company();
        query.setCmpName(companyName);
        query.setCmpVerifyStatus(verifyStatus);
        List<Company> list = companyService.selectCompanyList(query);
        List<Map<String, Object>> result = new ArrayList<>();
        for (Company c : list) {
            Map<String, Object> item = new HashMap<>();
            item.put("companyId", c.getCmpId());
            item.put("companyName", c.getCmpName());
            item.put("creditCode", c.getCmpCreditCode());
            item.put("industry", c.getCmpIndustry());
            item.put("size", c.getCmpSize());
            item.put("city", c.getCmpCity());
            item.put("address", c.getCmpAddress());
            item.put("website", c.getCmpWebsite());
            item.put("intro", c.getCmpIntro());
            item.put("contactName", c.getContactName());
            item.put("contactPhone", c.getContactPhone());
            item.put("verifyStatus", c.getCmpVerifyStatus() != null ? c.getCmpVerifyStatus() : 0);
            item.put("verifyAt", c.getCmpVerifyAt());
            item.put("verifyRemark", c.getVerifyRemark());
            item.put("verifyByName", resolveUserName(c.getCmpVerifyBy()));
            item.put("createTime", c.getCmpCreatedAt());
            result.add(item);
        }
        return getDataTable(result);
    }

    @PreAuthorize("@ss.hasPermi('tenant:company:query')")
    @GetMapping("/{companyId}")
    public AjaxResult getInfo(@PathVariable("companyId") Long companyId) {
        Company c = companyService.selectCompanyByCmpId(companyId);
        if (c == null) {
            return error("企业不存在");
        }
        Map<String, Object> item = new HashMap<>();
        item.put("companyId", c.getCmpId());
        item.put("companyName", c.getCmpName());
        item.put("creditCode", c.getCmpCreditCode());
        item.put("industry", c.getCmpIndustry());
        item.put("size", c.getCmpSize());
        item.put("city", c.getCmpCity());
        item.put("address", c.getCmpAddress());
        item.put("website", c.getCmpWebsite());
        item.put("intro", c.getCmpIntro());
        item.put("contactName", c.getContactName());
        item.put("contactPhone", c.getContactPhone());
        item.put("verifyStatus", c.getCmpVerifyStatus() != null ? c.getCmpVerifyStatus() : 0);
        item.put("verifyAt", c.getCmpVerifyAt());
        item.put("verifyRemark", c.getVerifyRemark());
        item.put("verifyByName", resolveUserName(c.getCmpVerifyBy()));
        item.put("createTime", c.getCmpCreatedAt());
        return success(item);
    }

    /** 企业用量明细 */
    @GetMapping("/{companyId}/usage")
    public AjaxResult usage(@PathVariable("companyId") Long companyId) {
        Map<String, Object> u = new HashMap<>();
        try {
            Integer jobs = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM t_pos WHERE pos_cmp_id = ?", Integer.class, companyId);
            Integer apps = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM t_app_record a JOIN t_pos p ON a.app_position_id = p.pos_id WHERE p.pos_cmp_id = ?", Integer.class, companyId);
            Integer interviews = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM t_int_session s JOIN t_pos p ON s.ses_pos_id = p.pos_id WHERE p.pos_cmp_id = ?", Integer.class, companyId);
            u.put("jobs", jobs != null ? jobs : 0);
            u.put("applications", apps != null ? apps : 0);
            u.put("interviews", interviews != null ? interviews : 0);
        } catch (Exception e) {
            u.put("error", e.getMessage());
        }
        return success(u);
    }

    @PreAuthorize("@ss.hasPermi('tenant:company:add')")
    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> data) {
        String companyName = (String) data.get("companyName");
        if (companyName == null || companyName.trim().isEmpty()) {
            return AjaxResult.error("企业名称不能为空");
        }
        Company company = new Company();
        company.setCmpName(companyName);
        company.setCmpStatus(1);
        return toAjax(companyService.insertCompany(company));
    }

    @PreAuthorize("@ss.hasPermi('tenant:company:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> data) {
        Object companyIdObj = data.get("companyId");
        if (companyIdObj == null) {
            return AjaxResult.error("企业ID不能为空");
        }
        Company company = new Company();
        company.setCmpId(Long.valueOf(companyIdObj.toString()));
        company.setCmpName((String) data.get("companyName"));
        return toAjax(companyService.updateCompany(company));
    }

    @PreAuthorize("@ss.hasPermi('tenant:company:remove')")
    @DeleteMapping("/{companyIds}")
    public AjaxResult remove(@PathVariable Long[] companyIds) {
        for (Long id : companyIds) {
            companyService.deleteCompanyByCmpId(id);
        }
        return success();
    }

    @PreAuthorize("@ss.hasPermi('tenant:company:edit')")
    @Log(title = "企业状态变更", businessType = BusinessType.UPDATE)
    @PutMapping("/changeStatus")
    public AjaxResult changeStatus(@RequestBody Map<String, Object> data) {
        Object companyIdObj = data.get("companyId");
        if (companyIdObj == null) {
            return AjaxResult.error("企业ID不能为空");
        }
        Object statusObj = data.get("status");
        if (statusObj == null) {
            return AjaxResult.error("状态不能为空");
        }
        Company company = new Company();
        company.setCmpId(((Number) companyIdObj).longValue());
        company.setCmpStatus(Integer.valueOf(statusObj.toString()));
        return toAjax(companyService.updateCompany(company));
    }

    /**
     * 企业审核
     */
    @PreAuthorize("@ss.hasPermi('tenant:company:audit')")
    @Log(title = "企业审核", businessType = BusinessType.UPDATE)
    @PutMapping("/audit")
    public AjaxResult audit(@RequestBody Map<String, Object> data) {
        Object companyIdObj = data.get("companyId");
        if (companyIdObj == null) {
            return AjaxResult.error("企业ID不能为空");
        }
        Object statusObj = data.get("status");
        if (statusObj == null) {
            return AjaxResult.error("审核状态不能为空");
        }
        Long companyId = Long.valueOf(companyIdObj.toString());
        Integer status = Integer.valueOf(statusObj.toString()); // 1通过 2拒绝
        String rejectReason = data.get("rejectReason") != null ? data.get("rejectReason").toString() : "";
        return toAjax(companyService.verifyCompany(companyId, status, getUserId(), rejectReason));
    }

    /**
     * 撤销审核：重置为待审核并清空留痕
     */
    @PreAuthorize("@ss.hasPermi('tenant:company:edit')")
    @Log(title = "撤销企业审核", businessType = BusinessType.UPDATE)
    @PutMapping("/revoke")
    public AjaxResult revoke(@RequestBody Map<String, Object> data) {
        Object companyIdObj = data.get("companyId");
        if (companyIdObj == null) {
            return AjaxResult.error("企业ID不能为空");
        }
        Long companyId = Long.valueOf(companyIdObj.toString());
        return toAjax(companyService.resetVerify(companyId));
    }

    /**
     * 审核状态统计：0待审核 1已通过 2已拒绝
     */
    @PreAuthorize("@ss.hasPermi('tenant:company:list')")
    @GetMapping("/stats")
    public AjaxResult stats() {
        Map<String, Object> result = new HashMap<>();
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                "SELECT cmp_verify_status AS s, COUNT(*) AS cnt FROM t_cmp GROUP BY cmp_verify_status");
        int pending = 0, approved = 0, rejected = 0;
        for (Map<String, Object> row : rows) {
            int s = row.get("s") == null ? 0 : ((Number) row.get("s")).intValue();
            int cnt = ((Number) row.get("cnt")).intValue();
            if (s == 1) approved = cnt;
            else if (s == 2) rejected = cnt;
            else pending += cnt;
        }
        result.put("pending", pending);
        result.put("approved", approved);
        result.put("rejected", rejected);
        result.put("total", pending + approved + rejected);
        try {
            Long expiring = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM t_cmp WHERE cmp_verify_status=1 AND cmp_expire_date IS NOT NULL AND cmp_expire_date > NOW() AND cmp_expire_date <= DATE_ADD(NOW(), INTERVAL 30 DAY)",
                    Long.class);
            result.put("expiring", expiring == null ? 0 : expiring);
        } catch (Exception e) {
            result.put("expiring", 0);
        }
        return success(result);
    }

    private String resolveUserName(Long userId) {
        if (userId == null) {
            return null;
        }
        try {
            List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                    "SELECT nick_name, user_name FROM sys_user WHERE user_id = ?", userId);
            if (rows.isEmpty()) {
                return null;
            }
            Map<String, Object> row = rows.get(0);
            Object nick = row.get("nick_name");
            if (nick != null && !nick.toString().isEmpty()) {
                return nick.toString();
            }
            Object login = row.get("user_name");
            return login == null ? null : login.toString();
        } catch (Exception e) {
            return null;
        }
    }
}
