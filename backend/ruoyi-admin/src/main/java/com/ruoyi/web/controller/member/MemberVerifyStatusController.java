package com.ruoyi.web.controller.member;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import java.util.*;

/**
 * 实名认证状态查询
 *
 * @author TQY
 */
@RestController
@RequestMapping("/member/verify")
public class MemberVerifyStatusController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /**
     * 查询所有用户的实名认证状态
     */
    @GetMapping("/userStatus")
    public AjaxResult userStatus() {
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT usv_user_id, usv_verify_status FROM t_usr_verify WHERE usv_verify_status = 1"
        );
        
        Set<Long> verifiedUserIds = new HashSet<>();
        for (Map<String, Object> item : list) {
            verifiedUserIds.add(((Number) item.get("usv_user_id")).longValue());
        }
        
        return success(verifiedUserIds);
    }
}
