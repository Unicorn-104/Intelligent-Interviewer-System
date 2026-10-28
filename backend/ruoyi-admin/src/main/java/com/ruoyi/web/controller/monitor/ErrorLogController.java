package com.ruoyi.web.controller.monitor;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;

import java.util.List;
import java.util.Map;

/** 错误日志：查操作日志里异常的记录 */
@RestController
@RequestMapping("/monitor/errorlog")
public class ErrorLogController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('monitor:errorlog:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT oper_id AS operId, title, oper_name AS operName, oper_url AS operUrl, " +
            "oper_param AS operParam, error_msg AS errorMsg, oper_time AS operTime " +
            "FROM sys_oper_log WHERE status = 1 " +
            "ORDER BY oper_time DESC LIMIT 100");
        return getDataTable(list);
    }
}
