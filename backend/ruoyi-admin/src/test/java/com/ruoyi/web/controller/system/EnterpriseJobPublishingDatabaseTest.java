package com.ruoyi.web.controller.system;

import static org.junit.jupiter.api.Assertions.*;
import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.enterprise.mapper.EnterpriseJdMapper;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.EnterpriseJobMapper;
import com.ruoyi.system.service.impl.EnterpriseJobServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.support.TransactionTemplate;

/** Opt-in local database smoke; all job writes are rolled back. */
@EnabledIfEnvironmentVariable(named = "JOB_MYSQL_SMOKE", matches = "true")
class EnterpriseJobPublishingDatabaseTest
{
    @Test
    void publishesAndReadsBackUsingActualMysqlSchemaThenRollsBack() throws Exception
    {
        DriverManagerDataSource source = new DriverManagerDataSource();
        source.setDriverClassName("com.mysql.cj.jdbc.Driver");
        source.setUrl(System.getenv("JOB_MYSQL_URL"));
        source.setUsername(System.getenv("JOB_MYSQL_USERNAME"));
        source.setPassword(System.getenv("JOB_MYSQL_PASSWORD"));
        JdbcTemplate jdbc = new JdbcTemplate(source);
        assertEquals("recruit_agent", jdbc.queryForObject("select database()", String.class));
        List<Long> users = jdbc.queryForList("select bnd_user_id from t_cmp_binding b join t_cmp c on c.cmp_id = b.bnd_company_id where b.bnd_status = 1 and c.cmp_status = 1 order by b.bnd_id limit 1", Long.class);
        assertFalse(users.isEmpty(), "An approved company binding is required for this smoke test");
        Long userId = users.get(0);
        SqlSessionFactoryBean factory = new SqlSessionFactoryBean();
        factory.setDataSource(source);
        factory.setMapperLocations(new ClassPathResource("mapper/system/EnterpriseJobMapper.xml"),
                new ClassPathResource("mapper/system/DashboardMapper.xml"),
                new ClassPathResource("mapper/enterprise/EnterpriseJdMapper.xml"));
        SqlSessionTemplate session = new SqlSessionTemplate(Objects.requireNonNull(factory.getObject()));
        EnterpriseJobServiceImpl service = new EnterpriseJobServiceImpl();
        ReflectionTestUtils.setField(service, "jobMapper", session.getMapper(EnterpriseJobMapper.class));
        ReflectionTestUtils.setField(service, "dashboardMapper", session.getMapper(DashboardMapper.class));
        ReflectionTestUtils.setField(service, "jdMapper", session.getMapper(EnterpriseJdMapper.class));
        String title = "JOB_PUBLISH_ROLLBACK_" + System.nanoTime();
        Long before = jdbc.queryForObject("select count(*) from t_pos", Long.class);
        Long skillsBefore = jdbc.queryForObject("select count(*) from t_pos_skill", Long.class);
        TransactionTemplate transaction = new TransactionTemplate(new DataSourceTransactionManager(source));
        transaction.executeWithoutResult(status -> {
            try
            {
                Map<String, Object> options = service.publishingOptions(userId);
                assertNotNull(options.get("company"));
                Map<String, Object> form = new LinkedHashMap<>();
                form.put("title", title); form.put("dept", "Integration Test"); form.put("city", "Test city");
                form.put("salaryMin", "15000.50"); form.put("salaryMax", "25000");
                form.put("education", 3); form.put("jobType", 1); form.put("experience", "3-5 years");
                form.put("responsibilities", List.of("Build mobile applications"));
                form.put("requirements", List.of("Flutter experience"));
                form.put("skills", List.of(Map.of("name", "Flutter", "required", 1), Map.of("name", "Dart", "required", 0)));
                Map<String, Object> result = service.createJob(userId, form);
                Long positionId = ((Number) result.get("posId")).longValue();
                assertEquals(2, jdbc.queryForObject("select count(*) from t_pos_skill where psk_position_id = ?", Integer.class, positionId));
                Map<String, Object> details = service.jobDetail(userId, positionId);
                @SuppressWarnings("unchecked")
                Map<String, Object> job = (Map<String, Object>) details.get("job");
                assertEquals(title, job.get("title"));
                assertEquals(new BigDecimal("15000.50"), job.get("salaryMin"));
                assertEquals(3, ((Number) job.get("education")).intValue());
                assertEquals(List.of("Flutter experience"), JSON.parseObject((String) job.get("jdJson"))
                        .getJSONArray("requirements").toJavaList(String.class));
                assertTrue(service.selectJobList(((Number) ((Map<?, ?>) options.get("company")).get("id")).longValue(), title, null, 1)
                        .stream().anyMatch(row -> ((Number) row.get("posId")).longValue() == positionId));
            }
            finally
            {
                status.setRollbackOnly();
            }
        });
        assertEquals(0, jdbc.queryForObject("select count(*) from t_pos where pos_title = ?", Integer.class, title));
        assertEquals(before, jdbc.queryForObject("select count(*) from t_pos", Long.class));
        assertEquals(skillsBefore, jdbc.queryForObject("select count(*) from t_pos_skill", Long.class));
    }
}
