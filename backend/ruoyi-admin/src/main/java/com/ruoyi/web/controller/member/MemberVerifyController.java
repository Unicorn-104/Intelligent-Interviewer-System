package com.ruoyi.web.controller.member;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import java.util.*;

/**
 * 实名认证审核（对齐前端 /member/verify 接口）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/member/verify")
public class MemberVerifyController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /**
     * 查询实名认证列表
     */
    @GetMapping("/list")
    public TableDataInfo list(
            @RequestParam(required = false) String userName,
            @RequestParam(required = false) String companyName,
            @RequestParam(required = false) Integer status
    ) {
        startPage();
        
        StringBuilder sql = new StringBuilder(
            "SELECT v.vef_id as verify_id, v.vef_real_name as real_name, v.vef_id_card as id_card, " +
            "v.vef_front_img as front_img, v.vef_back_img as back_img, v.vef_status as status, " +
            "v.vef_reject_reason as reject_reason, v.vef_created_at as created_at, v.vef_verified_at as verified_at, " +
            "u.user_id as user_id, u.user_name as user_name, u.nick_name as nick_name, u.phonenumber as phone " +
            "FROM t_usr_verify v " +
            "LEFT JOIN sys_user u ON v.vef_user_id = u.user_id " +
            "WHERE 1=1 "
        );
        
        List<Object> params = new ArrayList<>();
        
        if (userName != null && !userName.isEmpty()) {
            sql.append("AND (u.user_name LIKE ? OR u.nick_name LIKE ?) ");
            params.add("%" + userName + "%");
            params.add("%" + userName + "%");
        }
        
        if (status != null) {
            sql.append("AND v.vef_status = ? ");
            params.add(status);
        }
        
        sql.append("ORDER BY v.vef_created_at DESC");
        
        List<Map<String, Object>> list = jdbcTemplate.queryForList(sql.toString(), params.toArray());
        
        // 转换字段名
        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> item : list) {
            Map<String, Object> map = new HashMap<>();
            map.put("verifyId", item.get("verify_id"));
            map.put("userName", item.get("nick_name") != null ? item.get("nick_name") : item.get("user_name"));
            map.put("phone", item.get("phone"));
            map.put("realName", item.get("real_name"));
            map.put("idCard", item.get("id_card"));
            map.put("frontImg", item.get("front_img"));
            map.put("backImg", item.get("back_img"));
            map.put("status", item.get("status"));
            map.put("rejectReason", item.get("reject_reason"));
            map.put("createdAt", item.get("created_at"));
            map.put("verifiedAt", item.get("verified_at"));
            result.add(map);
        }
        
        return getDataTable(result);
    }

    /**
     * 审核
     */
    @PutMapping("/audit")
    public AjaxResult audit(@RequestBody Map<String, Object> data) {
        Object verifyIdObj = data.get("verifyId");
        Object statusObj = data.get("status");
        String reason = (String) data.get("reason");
        
        if (verifyIdObj == null || statusObj == null) {
            return AjaxResult.error("参数错误");
        }
        
        Integer verifyId = Integer.valueOf(verifyIdObj.toString());
        Integer status = Integer.valueOf(statusObj.toString());
        
        jdbcTemplate.update(
            "UPDATE t_usr_verify SET vef_status = ?, vef_reject_reason = ?, vef_verified_at = NOW() WHERE vef_id = ?",
            status, reason, verifyId
        );
        
        return success();
    }
}
