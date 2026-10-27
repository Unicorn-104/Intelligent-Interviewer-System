package com.ruoyi.web.controller.admin;

import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.page.TableDataInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/** 站内信已发列表 */
@RestController
@RequestMapping("/admin/msg/sent")
public class MsgSentController extends BaseController {

    @Autowired
    private JdbcTemplate jdbc;

    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) String title,
                             @RequestParam(required = false) Integer isRead) {
        startPage();
        StringBuilder sql = new StringBuilder(
                "SELECT m.msg_id, m.msg_title, m.msg_type, m.msg_is_read, m.msg_created_at, " +
                "u.nick_name AS receiver_name, u.phonenumber AS receiver_phone " +
                "FROM t_msg m LEFT JOIN sys_user u ON m.msg_receiver_id = u.user_id WHERE 1=1");
        List<Object> args = new java.util.ArrayList<>();
        if (title != null && !title.isEmpty()) {
            sql.append(" AND m.msg_title LIKE ?");
            args.add("%" + title + "%");
        }
        if (isRead != null) {
            sql.append(" AND m.msg_is_read=?");
            args.add(isRead);
        }
        sql.append(" ORDER BY m.msg_id DESC");
        List<Map<String, Object>> list = jdbc.queryForList(sql.toString(), args.toArray());
        return getDataTable(list);
    }
}
