package com.ruoyi.enterprise.service.drill;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/** 最小冒烟：验证当前环境可一次性拉起 mysql:8.0 并查询版本，不连任何外部库。 */
@Testcontainers
class DrillSmokeIT
{
    @Container
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0")
            .withDatabaseName("recruit_drill")
            .withUsername("drill")
            .withPassword("drill")
            .withReuse(false);

    @Test
    void mysqlStartsAndReportsVersion8() throws Exception
    {
        try (var conn = MYSQL.createConnection("");
             var st = conn.createStatement();
             var rs = st.executeQuery("select version()"))
        {
            assertTrue(rs.next());
            String version = rs.getString(1);
            System.out.println("MYSQL_VERSION=" + version);
            assertTrue(version.startsWith("8.0"));
            System.out.println("JDBC_URL=" + MYSQL.getJdbcUrl());
        }
    }
}
