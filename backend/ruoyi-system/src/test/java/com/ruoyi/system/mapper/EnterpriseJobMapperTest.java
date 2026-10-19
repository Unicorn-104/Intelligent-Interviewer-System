package com.ruoyi.system.mapper;

import static org.junit.jupiter.api.Assertions.*;
import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;
import org.h2.jdbcx.JdbcDataSource;
import org.junit.jupiter.api.Test;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;

class EnterpriseJobMapperTest
{
    @Test
    void insertsFullJobAndReturnsGeneratedKey() throws Exception
    {
        JdbcDataSource source = new JdbcDataSource();
        source.setURL("jdbc:h2:mem:job_publish;MODE=MySQL;DB_CLOSE_DELAY=-1");
        JdbcTemplate jdbc = new JdbcTemplate(source);
        jdbc.execute("create table t_cmp (cmp_id bigint primary key, cmp_name varchar(100), cmp_city varchar(50), cmp_status int)");
        jdbc.execute("insert into t_cmp values (2, 'Test company', 'Test city', 1)");
        jdbc.execute("""
            create table t_pos (pos_id bigint auto_increment primary key, pos_company_id bigint,
                pos_publisher_id bigint, pos_title varchar(100), pos_department varchar(50),
                pos_work_city varchar(50), pos_salary_min decimal(10,2), pos_salary_max decimal(10,2),
                pos_experience_required varchar(20), pos_education_required tinyint, pos_job_type tinyint,
                pos_jd_json varchar(20000), pos_status tinyint)
            """);
        SqlSessionFactoryBean factory = new SqlSessionFactoryBean();
        factory.setDataSource(source);
        factory.setMapperLocations(new ClassPathResource("mapper/system/EnterpriseJobMapper.xml"));
        EnterpriseJobMapper mapper = new SqlSessionTemplate(factory.getObject()).getMapper(EnterpriseJobMapper.class);
        Map<String, Object> job = new LinkedHashMap<>();
        job.put("companyId", 2L); job.put("publisherId", 100L);
        job.put("title", "Mobile Engineer"); job.put("dept", "Engineering"); job.put("city", "Test city");
        job.put("salaryMin", new BigDecimal("15000.50")); job.put("salaryMax", new BigDecimal("25000"));
        job.put("experience", "3-5 years"); job.put("education", 3); job.put("jobType", 1);
        job.put("jdJson", "{\"requirements\":[\"Flutter\"]}"); job.put("status", 1);
        assertEquals(1, mapper.insertJob(job));
        assertNotNull(job.get("posId"));
        assertEquals(new BigDecimal("15000.50"), jdbc.queryForObject(
                "select pos_salary_min from t_pos where pos_id = ?", BigDecimal.class, job.get("posId")));
        assertEquals("Mobile Engineer", jdbc.queryForObject(
                "select pos_title from t_pos where pos_id = ?", String.class, job.get("posId")));
        assertEquals("Test company", mapper.selectPublishingCompany(2L).get("NAME"));
        assertNull(mapper.selectPublishingCompany(999L));
    }
}
