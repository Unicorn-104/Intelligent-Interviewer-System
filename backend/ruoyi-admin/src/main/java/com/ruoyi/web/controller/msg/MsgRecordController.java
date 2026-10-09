package com.ruoyi.web.controller.msg;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.page.TableDataInfo;

import java.util.List;

/**
 * 消息发送记录Controller
 */
@RestController
@RequestMapping("/msg/record")
public class MsgRecordController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('msg:record:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<java.util.Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT mr_id as id, mr_user_name as userName, mr_template_id as templateId, " +
            "mr_channel as channel, mr_content as content, mr_status as status, " +
            "mr_create_time as createTime FROM t_msg_record ORDER BY mr_create_time DESC"
        );
        return getDataTable(list);
    }
}
