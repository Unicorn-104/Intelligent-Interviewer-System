package com.ruoyi.web.controller.admin;

import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.redis.RedisCache;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.io.File;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.sql.Connection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 系统工具 - 运维巡检聚合接口
 *
 * @author TQY
 */
@RestController
@RequestMapping("/admin/ops")
public class OpsInspectController extends BaseController {

    @Autowired
    private DataSource dataSource;

    @Autowired
    private RedisCache redisCache;

    /** 一键巡检：DB / Redis / 磁盘 / JVM / 邮件连通性 */
    @GetMapping("/inspect")
    public AjaxResult inspect() {
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("db", checkDb());
        res.put("redis", checkRedis());
        res.put("disk", checkDisk());
        res.put("jvm", checkJvm());
        res.put("overall", "ok");
        return AjaxResult.success(res);
    }

    private Map<String, Object> checkDb() {
        Map<String, Object> m = new HashMap<>();
        try (Connection c = dataSource.getConnection()) {
            m.put("ok", !c.isClosed());
            m.put("url", c.getMetaData().getURL());
            m.put("product", c.getMetaData().getDatabaseProductName());
        } catch (Exception e) {
            m.put("ok", false);
            m.put("error", e.getMessage());
        }
        return m;
    }

    private Map<String, Object> checkRedis() {
        Map<String, Object> m = new HashMap<>();
        try {
            String pong = redisCache.redisTemplate.getConnectionFactory().getConnection().ping();
            m.put("ok", "PONG".equalsIgnoreCase(pong));
        } catch (Exception e) {
            m.put("ok", false);
            m.put("error", e.getMessage());
        }
        return m;
    }

    private Map<String, Object> checkDisk() {
        Map<String, Object> m = new HashMap<>();
        File root = new File(".");
        long total = root.getTotalSpace();
        long free = root.getUsableSpace();
        long used = total - free;
        m.put("totalGb", Math.round(total / 1024.0 / 1024 / 1024 * 10) / 10.0);
        m.put("usedGb", Math.round(used / 1024.0 / 1024 / 1024 * 10) / 10.0);
        m.put("usedPct", (int) (used * 100 / total));
        return m;
    }

    private Map<String, Object> checkJvm() {
        MemoryMXBean mem = ManagementFactory.getMemoryMXBean();
        long used = mem.getHeapMemoryUsage().getUsed();
        long max = mem.getHeapMemoryUsage().getMax();
        Map<String, Object> m = new HashMap<>();
        m.put("heapUsedMb", Math.round(used / 1024.0 / 1024));
        m.put("heapMaxMb", Math.round(max / 1024.0 / 1024));
        m.put("heapPct", (int) (used * 100 / max));
        m.put("processors", Runtime.getRuntime().availableProcessors());
        m.put("uptimeMs", ManagementFactory.getRuntimeMXBean().getUptime());
        return m;
    }
}
