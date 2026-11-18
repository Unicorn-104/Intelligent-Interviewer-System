package com.ruoyi.enterprise.service.drill;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import org.testcontainers.containers.MySQLContainer;

/**
 * 隔离演练环境：JVM 内单例的一次性 MySQL 8 容器，随机端口、独立库/账号、不挂载数据卷。
 * 提供支持客户端 DELIMITER 切换的脚本执行（存储过程），以及只读查询工具。
 * 容器在 JVM 退出时由 Testcontainers/Ryuk 自动销毁；全程不连任何外部库。
 */
final class DrillEnv
{
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0")
            .withDatabaseName("recruit_drill")
            .withUsername("drill")
            .withPassword("drill")
            .withReuse(false);

    static
    {
        MYSQL.start();
    }

    private DrillEnv() {}

    static Connection connection() throws SQLException
    {
        return MYSQL.createConnection("");
    }

    static String mysqlVersion() throws SQLException
    {
        return scalar("select version()");
    }

    /** 执行 classpath 上的 SQL 文件（支持 DELIMITER 切换）。 */
    static void runResource(String resourcePath) throws SQLException, IOException
    {
        try (InputStream in = DrillEnv.class.getClassLoader().getResourceAsStream(resourcePath))
        {
            if (in == null) throw new IOException("classpath 资源不存在: " + resourcePath);
            executeScript(new String(in.readAllBytes(), StandardCharsets.UTF_8));
        }
    }

    /** 直接执行脚本文本（支持 DELIMITER 切换）。 */
    static void executeScript(String script) throws SQLException
    {
        try (Connection conn = connection())
        {
            executeScript(conn, script);
        }
    }

    /** 在指定连接上执行脚本（支持 DELIMITER 切换），保留过程内注释与格式。 */
    static void executeScript(Connection conn, String script) throws SQLException
    {
        String delimiter = ";";
        StringBuilder pending = new StringBuilder();
        for (String rawLine : script.split("\n", -1))
        {
            String line = rawLine.strip();
            if (line.toUpperCase().startsWith("DELIMITER "))
            {
                delimiter = line.substring("DELIMITER ".length()).trim();
                continue;
            }
            pending.append(rawLine).append("\n");
            String accumulated = pending.toString().trim();
            if (accumulated.endsWith(delimiter))
            {
                String toRun = accumulated.substring(0, accumulated.length() - delimiter.length()).trim();
                if (!toRun.isEmpty())
                {
                    try (Statement st = conn.createStatement())
                    {
                        st.execute(toRun);
                    }
                }
                pending.setLength(0);
            }
        }
        String tail = pending.toString().trim();
        if (!tail.isEmpty())
        {
            try (Statement st = conn.createStatement())
            {
                st.execute(tail);
            }
        }
    }

    static long count(String sql) throws SQLException
    {
        try (Connection conn = connection(); Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql))
        {
            if (!rs.next()) return 0L;
            return rs.getLong(1);
        }
    }

    static String scalar(String sql) throws SQLException
    {
        try (Connection conn = connection(); Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql))
        {
            return rs.next() ? rs.getString(1) : null;
        }
    }

    /** 执行查询并把结果集字符串化为行集合（含表头）。 */
    static List<List<String>> select(String sql) throws SQLException
    {
        List<List<String>> out = new ArrayList<>();
        try (Connection conn = connection(); Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql))
        {
            ResultSetMetaData meta = rs.getMetaData();
            int n = meta.getColumnCount();
            List<String> header = new ArrayList<>();
            for (int i = 1; i <= n; i++) header.add(meta.getColumnLabel(i));
            out.add(header);
            while (rs.next())
            {
                List<String> row = new ArrayList<>();
                for (int i = 1; i <= n; i++)
                {
                    Object v = rs.getObject(i);
                    row.add(v == null ? null : v.toString());
                }
                out.add(row);
            }
        }
        return out;
    }
}
