package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import java.io.InputStream;
import java.math.BigDecimal;
import java.sql.Statement;
import java.util.List;
import java.util.UUID;
import org.apache.ibatis.builder.xml.XMLMapperBuilder;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.Configuration;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import com.github.pagehelper.Page;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInterceptor;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import com.ruoyi.system.mapper.agent.AgentJobMapper;

class AgentJobMatchScoreTest
{
    private SqlSession session;
    private AgentJobMapper mapper;

    @BeforeEach
    void setup() throws Exception
    {
        UnpooledDataSource source = new UnpooledDataSource("org.h2.Driver",
                "jdbc:h2:mem:job_match_" + UUID.randomUUID() + ";MODE=MySQL", "sa", "");
        Configuration config = new Configuration(new Environment("test", new JdbcTransactionFactory(), source));
        config.addInterceptor(new PageInterceptor());
        String resource = "mapper/agent/AgentJobMapper.xml";
        try (InputStream xml = getClass().getClassLoader().getResourceAsStream(resource))
        {
            assertNotNull(xml);
            new XMLMapperBuilder(xml, config, resource, config.getSqlFragments()).parse();
        }
        session = new SqlSessionFactoryBuilder().build(config).openSession();
        mapper = session.getMapper(AgentJobMapper.class);
        execute("create table sys_user(user_id bigint primary key, target_direction varchar(100),"
                + " target_city varchar(100), current_city varchar(100))");
        execute("create table t_res_base(rbs_id bigint primary key, rbs_user_id bigint, rbs_status int,"
                + " rbs_is_default int, rbs_updated_at timestamp, rbs_job_direction varchar(100))");
        execute("create table t_res_skill(skl_id bigint primary key, skl_resume_id bigint, skl_name varchar(100))");
        execute("create table t_cmp(cmp_id bigint primary key, cmp_name varchar(100), cmp_logo_url varchar(100),"
                + " cmp_industry varchar(100), cmp_size varchar(100), cmp_city varchar(100), cmp_address varchar(100),"
                + " cmp_intro varchar(100), cmp_detail_json varchar(100), cmp_status int)");
        execute("create table t_pos(pos_id bigint primary key, pos_title varchar(100), pos_department varchar(100),"
                + " pos_company_id bigint, pos_publisher_id bigint, pos_work_city varchar(100), pos_salary_min decimal,"
                + " pos_salary_max decimal, pos_experience_required varchar(100), pos_education_required int,"
                + " pos_job_type int, pos_jd_json varchar(100), pos_status int, pos_created_at timestamp)");
        execute("create table t_pos_skill(psk_id bigint primary key, psk_position_id bigint, psk_name varchar(100),"
                + " psk_required int)");
        execute("create table t_tal(tal_id bigint primary key, tal_user_id bigint, tal_company_id bigint,"
                + " tal_matched_score decimal(5,1))");
        execute("create table t_app_record(app_id bigint primary key, app_candidate_id bigint, app_position_id bigint)");
        execute("insert into sys_user values(100,'Java','杭州','广州'),(200,null,null,'杭州')");
        execute("insert into t_cmp(cmp_id,cmp_name,cmp_status) values(1,'Synthetic company',1)");
        execute("insert into t_res_base values(10,100,1,1,'2026-10-28','Java')");
        execute("insert into t_res_skill values(1,10,' java '),(2,10,'SQL'),(3,10,'JAVA')");
        execute("insert into t_tal values(1,100,1,82.8)");
        execute("insert into t_pos(pos_id,pos_title,pos_company_id,pos_work_city,pos_status,pos_created_at) values"
                + "(1,'Java开发工程师',1,'杭州',1,'2026-10-01'),"
                + "(2,'Python开发工程师',1,'广州',1,'2026-10-29'),"
                + "(3,'前端开发工程师',1,'杭州',1,'2026-10-28')");
        execute("insert into t_pos_skill values(1,1,'Java',1),(2,1,'SQL',0),(3,2,'Python',1),(4,3,'Vue',1)");
    }

    @AfterEach
    void cleanup()
    {
        PageHelper.clearPage();
        if (session != null) session.close();
    }

    @Test
    void sameCompanyJobsUseTheirOwnRequirementsInsteadOfCompanyTalentScore()
    {
        List<AgentJob> jobs = mapper.selectJobList(matchQuery(), 100L);
        assertEquals(List.of(1L, 3L, 2L), jobs.stream().map(AgentJob::getId).toList());
        assertScore("100", jobs.get(0));
        assertScore("15", jobs.get(1));
        assertScore("0", jobs.get(2));
        for (AgentJob job : jobs)
        {
            assertEquals(0, job.getMatchScore().compareTo(mapper.selectJobById(job.getId(), 100L).getMatchScore()));
        }
    }

    @Test
    void defaultResumeWinsAndOtherUsersOrInactiveResumesDoNotIncreaseScore() throws Exception
    {
        execute("insert into t_res_base values(11,100,1,0,'2026-10-29','Python'),"
                + "(12,100,0,1,'2026-10-29','Python'),(20,200,1,1,'2026-10-29','Python')");
        execute("insert into t_res_skill values(4,11,'Python'),(5,12,'Python'),(6,20,'Python')");
        assertScore("0", mapper.selectJobById(2L, 100L));
        assertScore("85", mapper.selectJobById(2L, 200L));
    }

    @Test
    void newestActiveResumeIsUsedWhenNoDefaultIsSet() throws Exception
    {
        execute("update t_res_base set rbs_is_default=0");
        execute("insert into t_res_base values(11,100,1,0,'2026-10-29','Python')");
        execute("insert into t_res_skill values(4,11,'Python')");
        assertScore("85", mapper.selectJobById(2L, 100L));
        assertScore("15", mapper.selectJobById(1L, 100L));
    }

    @Test
    void missingProfileDoesNotProduceFakePercentagesOrUseOtherUsersResume()
    {
        assertNull(mapper.selectJobById(1L, 200L).getMatchScore());
        assertTrue(mapper.selectJobList(matchQuery(), 200L).stream().allMatch(job -> job.getMatchScore() == null));
        assertNull(mapper.selectJobById(1L, 999L).getMatchScore());
    }

    @Test
    void duplicateSkillsDoNotInflateScoreAndMissingRequirementsDoNotDivideByZero() throws Exception
    {
        execute("insert into t_pos_skill values(5,1,' JAVA ',1),(6,1,'Redis',1),(7,1,' ',0)");
        assertScore("80", mapper.selectJobById(1L, 100L));
        execute("delete from t_pos_skill where psk_position_id=1");
        assertScore("40", mapper.selectJobById(1L, 100L));
    }

    @Test
    void matchOrderingIsAppliedBeforePagination()
    {
        PageHelper.startPage(1, 1);
        List<AgentJob> firstPage = mapper.selectJobList(matchQuery(), 100L);
        assertEquals(1, firstPage.size());
        assertEquals(3L, ((Page<AgentJob>) firstPage).getTotal());
        assertEquals(1L, firstPage.get(0).getId());
        PageHelper.startPage(2, 1);
        List<AgentJob> secondPage = mapper.selectJobList(matchQuery(), 100L);
        assertEquals(3L, secondPage.get(0).getId());
    }

    @Test
    void paginationCountUsesTheSameFiltersAsTheJobList()
    {
        AgentJobQuery query = matchQuery();
        query.setKeyword("SQL");
        query.setCity("杭州");
        PageHelper.startPage(1, 1);
        List<AgentJob> jobs = mapper.selectJobList(query, 100L);
        assertEquals(1L, ((Page<AgentJob>) jobs).getTotal());
        assertEquals(1, jobs.size());
        assertEquals(1L, jobs.get(0).getId());
    }

    @Test
    void emptyResumeDirectionFallsBackToProfileAndScoreKeepsOneDecimal() throws Exception
    {
        execute("update t_res_base set rbs_job_direction=' '");
        execute("insert into t_pos_skill values(5,1,'Redis',1),(6,1,'Linux',1),(7,1,'Docker',1),"
                + "(8,1,'Spring',1),(9,1,'Git',1)");
        assertScore("57.1", mapper.selectJobById(1L, 100L));
        execute("update t_res_base set rbs_status=0");
        assertScore("40", mapper.selectJobById(1L, 100L));
    }

    @Test
    void wildcardInDirectionIsLiteralAndCurrentCityIsFallback() throws Exception
    {
        execute("update t_res_base set rbs_job_direction=' % '");
        execute("update sys_user set target_city=' ',current_city='杭州' where user_id=100");
        assertScore("75", mapper.selectJobById(1L, 100L));
    }

    private AgentJobQuery matchQuery()
    {
        AgentJobQuery query = new AgentJobQuery();
        query.setSort("match");
        return query;
    }

    private void assertScore(String expected, AgentJob job)
    {
        assertNotNull(job.getMatchScore());
        assertEquals(0, new BigDecimal(expected).compareTo(job.getMatchScore()));
    }

    private void execute(String sql) throws Exception
    {
        try (Statement statement = session.getConnection().createStatement())
        {
            statement.execute(sql);
        }
        session.clearCache();
    }
}
