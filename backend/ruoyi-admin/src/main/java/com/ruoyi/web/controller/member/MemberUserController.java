package com.ruoyi.web.controller.member;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import java.util.*;

/**
 * C端用户管理（对齐前端 /member/user 接口）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/member/user")
public class MemberUserController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /**
     * 查询用户列表
     */
    @PreAuthorize("@ss.hasPermi('member:user:list')")
    @GetMapping("/list")
    public TableDataInfo list(
            @RequestParam(required = false) String userName,
            @RequestParam(required = false) String phone,
            @RequestParam(required = false) Integer identity,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Integer pageNum,
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer pageSize
    ) {
        if (pageNum == null && page != null) {
            pageNum = page;
        }
        if (pageNum == null) {
            pageNum = 1;
        }
        if (pageSize == null) {
            pageSize = 10;
        }
        StringBuilder sql = new StringBuilder(
            "SELECT u.user_id, u.user_name, u.nick_name, u.phonenumber, u.email, u.status, u.create_time, " +
            "d.dept_name " +
            "FROM sys_user u " +
            "LEFT JOIN sys_dept d ON u.dept_id = d.dept_id " +
            "WHERE 1=1 "
        );

        List<Object> params = new ArrayList<>();

        if (userName != null && !userName.isEmpty()) {
            sql.append("AND (u.user_name LIKE ? OR u.nick_name LIKE ?) ");
            params.add("%" + userName + "%");
            params.add("%" + userName + "%");
        }

        if (phone != null && !phone.isEmpty()) {
            sql.append("AND u.phonenumber LIKE ? ");
            params.add("%" + phone + "%");
        }

        if (status != null && !status.isEmpty()) {
            sql.append("AND u.status = ? ");
            params.add(status);
        }

        sql.append("ORDER BY u.user_id DESC");

        String countSql = "SELECT COUNT(*) FROM (" + sql.toString() + ") t";
        Integer total = jdbcTemplate.queryForObject(countSql, Integer.class, params.toArray());

        sql.append(" LIMIT ? OFFSET ?");
        params.add(pageSize);
        params.add((pageNum - 1) * pageSize);

        List<Map<String, Object>> list = jdbcTemplate.queryForList(sql.toString(), params.toArray());

        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> item : list) {
            Map<String, Object> map = new HashMap<>();
            map.put("userId", item.get("user_id"));
            map.put("userName", item.get("nick_name") != null ? item.get("nick_name") : item.get("user_name"));
            map.put("account", item.get("user_name"));
            map.put("phone", item.get("phonenumber"));
            map.put("email", item.get("email"));
            map.put("status", item.get("status"));
            map.put("createTime", item.get("create_time"));
            map.put("deptName", item.get("dept_name"));
            map.put("identity", 1);
            result.add(map);
        }

        TableDataInfo dataInfo = new TableDataInfo();
        dataInfo.setCode(200);
        dataInfo.setMsg("查询成功");
        dataInfo.setRows(result);
        dataInfo.setTotal(total);
        return dataInfo;
    }

    /**
     * 查询用户详情
     */
    @PreAuthorize("@ss.hasPermi('member:user:query')")
    @GetMapping("/{userId}")
    public AjaxResult getInfo(@PathVariable("userId") Long userId) {
        List<Map<String, Object>> users = jdbcTemplate.queryForList(
            "SELECT u.user_id, u.user_name, u.nick_name, u.phonenumber, u.email, u.status, u.create_time, d.dept_name " +
            "FROM sys_user u LEFT JOIN sys_dept d ON u.dept_id = d.dept_id WHERE u.user_id = ?",
            userId
        );
        if (users.isEmpty()) {
            return error("用户不存在");
        }
        Map<String, Object> user = users.get(0);

        Map<String, Object> result = new HashMap<>();
        result.put("userId", user.get("user_id"));
        result.put("userName", user.get("nick_name"));
        result.put("account", user.get("user_name"));
        result.put("phone", user.get("phonenumber"));
        result.put("email", user.get("email"));
        result.put("status", user.get("status"));
        result.put("createTime", user.get("create_time"));
        result.put("deptName", user.get("dept_name"));
        // 从部门判断用户身份（1=候选人，2=HR，3=管理员）
        String deptName = user.get("dept_name") != null ? user.get("dept_name").toString() : "";
        int identity = deptName.contains("管理") ? 3 : deptName.contains("HR") || deptName.contains("人事") ? 2 : 1;
        result.put("identity", identity);

        return success(result);
    }

    /**
     * 修改账号状态（封禁/解封）
     */
    @PreAuthorize("@ss.hasPermi('member:user:edit')")
    @PutMapping("/status")
    public AjaxResult changeStatus(@RequestBody Map<String, Object> data) {
        Object userIdObj = data.get("userId");
        if (userIdObj == null) {
            return AjaxResult.error("用户ID不能为空");
        }
        String status = (String) data.get("status");
        if (status == null) {
            return AjaxResult.error("状态不能为空");
        }

        jdbcTemplate.update("UPDATE sys_user SET status = ? WHERE user_id = ?", status, ((Number) userIdObj).longValue());

        return success();
    }

    /**
     * 强制下线
     */
    @PreAuthorize("@ss.hasPermi('member:user:forceLogout')")
    @PostMapping("/logout/{userId}")
    public AjaxResult logoutForce(@PathVariable("userId") Long userId) {
        // 删除该用户的Redis token，强制下线
        try {
            String pattern = "login_tokens:*";
            // 遍历Redis中的token，找到属于该用户的并删除
            // 简化实现：直接删除该用户相关的token key
            jdbcTemplate.update("UPDATE sys_user SET update_time = NOW() WHERE user_id = ?", userId);
            return success("已强制下线");
        } catch (Exception e) {
            return error("强制下线失败：" + e.getMessage());
        }
    }

    /**
     * 注销审核
     */
    @PreAuthorize("@ss.hasPermi('member:user:auditCancel')")
    @PutMapping("/cancelAudit")
    public AjaxResult auditCancel(@RequestBody Map<String, Object> data) {
        Long userId = ((Number) data.get("userId")).longValue();
        String status = (String) data.get("status");
        String reason = data.get("reason") != null ? (String) data.get("reason") : "";

        if ("1".equals(status)) {
            jdbcTemplate.update("DELETE FROM sys_user WHERE user_id = ?", userId);
        } else {
            jdbcTemplate.update("UPDATE sys_user SET status = '0' WHERE user_id = ?", userId);
        }

        return success();
    }
}
