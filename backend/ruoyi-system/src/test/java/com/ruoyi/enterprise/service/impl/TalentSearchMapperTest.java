package com.ruoyi.enterprise.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInterceptor;
import com.ruoyi.enterprise.domain.TalentSearchCriteria;
import com.ruoyi.enterprise.mapper.TalentPoolMapper;

/** Synthetic H2-only mapper regression; never loads application/private datasource configuration. */
public class TalentSearchMapperTest
{
    JdbcTemplate jdbc;
    TalentPoolMapper mapper;
    public static String format(Timestamp time, String pattern)
    {
        if (time == null) return null;
        return time.toLocalDateTime().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
    }
    @BeforeEach void setup() throws Exception
    {
        var ds = new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1", "sa", "");
        jdbc = new JdbcTemplate(ds);
        jdbc.execute("CREATE ALIAS date_format FOR 'com.ruoyi.enterprise.service.impl.TalentSearchMapperTest.format'");
        for (String sql : List.of(
            "create table sys_user(user_id bigint primary key, nick_name varchar(100),phonenumber varchar(30),email varchar(100), current_city varchar(50),target_city varchar(50),login_date timestamp)",
            "create table t_tal(tal_id bigint primary key,tal_company_id bigint,tal_user_id bigint,tal_resume_id bigint,tal_status int,tal_matched_score double,tal_current_round int,tal_updated_at timestamp,tal_archive_source int)",
            "create table t_res_base(rbs_id bigint primary key,rbs_user_id bigint,rbs_job_direction varchar(100),rbs_status int)",
            "create table t_tal_tag(tg_candidate_id bigint,tg_name varchar(100))",
            "create table t_tal_status_log(tsl_candidate_id bigint,tsl_to_status int)",
            "create table t_res_education(edu_resume_id bigint,edu_degree int)",
            "create table t_res_work(wrk_id bigint primary key,wrk_resume_id bigint,wrk_start_date date,wrk_end_date date,wrk_is_current int)")) jdbc.execute(sql);
        for (long i=1;i<=6;i++) {
            jdbc.update("insert into sys_user values(?,?,null,null,?,?,?)",i,"合成候选人"+i, i==1?"杭州":"上海", i==1?"上海":"杭州", Timestamp.valueOf(LocalDateTime.now().minusDays(i==1?1:40)));
            jdbc.update("insert into t_res_base values(?,?,?,1)",i,i,"Java");
            jdbc.update("insert into t_tal values(?,?,?,?,1,80,0,current_timestamp,3)",i,i==6?2:1,i,i);
        }
        jdbc.execute("insert into t_res_education values(1,2),(1,3),(1,0),(2,4),(4,3),(6,5)");
        jdbc.execute("insert into t_tal_tag values(1,'Java'),(2,'Java')");
        jdbc.execute("insert into t_res_work values(1,1,'2019-01-01','2021-01-01',0),(2,1,'2020-01-01','2022-01-01',0),(3,1,'2019-01-01','2019-06-01',0),(4,1,'2020-06-01','2020-12-01',0)");
        jdbc.execute("insert into t_res_work values(5,2,'2020-01-01','2021-01-01',0),(6,2,'2022-01-01','2023-01-01',0)");
        jdbc.execute("insert into t_res_work values(7,3,'2022-01-01',null,0),(8,3,'2999-01-01',null,1),(9,3,'2024-01-01','2023-01-01',0)");
        var factory = new SqlSessionFactoryBean(); factory.setDataSource(ds);
        var paging = new PageInterceptor(); var properties = new java.util.Properties(); properties.setProperty("helperDialect","mysql"); paging.setProperties(properties);
        factory.setPlugins(paging);
        factory.setMapperLocations(new ClassPathResource("mapper/enterprise/TalentPoolMapper.xml"));
        mapper = new SqlSessionTemplate(factory.getObject()).getMapper(TalentPoolMapper.class);
    }
    @AfterEach void clear() { PageHelper.clearPage(); }
    List<Map<String,Object>> search(TalentSearchCriteria c) {c.validate(); return mapper.selectFilteredTalentList(1L,null,null,null,null,null,c);}
    List<Long> ids(List<Map<String,Object>> rows) { return rows.stream().map(r -> ((Number)r.get("talentId")).longValue()).toList(); }

    @Test void overlapsDuplicatesNestedJobsAndDisjointRangesCountOnlyCoveredMonths()
    {
        var rows = search(new TalentSearchCriteria());
        var first = rows.stream().filter(r -> ((Number)r.get("talentId")).longValue()==1).findFirst().orElseThrow();
        var second = rows.stream().filter(r -> ((Number)r.get("talentId")).longValue()==2).findFirst().orElseThrow();
        assertEquals(36,((Number)first.get("workMonths")).intValue());
        assertEquals(24,((Number)second.get("workMonths")).intValue());
        assertEquals(3,((Number)first.get("highestEducation")).intValue());
        assertFalse(ids(rows).contains(6L));
        assertTrue(rows.stream().allMatch(r -> ((Number)r.get("searchFilterVersion")).intValue()==2));
    }
    @Test void experienceBoundariesAreInclusiveLowerExclusiveUpperAndMissingIsNotZero()
    {
        var c = new TalentSearchCriteria(); c.setExperienceRange("1to3"); assertEquals(List.of(2L),ids(search(c)));
        c.setExperienceRange("3to5"); assertEquals(List.of(1L),ids(search(c)));
        c.setExperienceRange("lt1"); assertTrue(search(c).isEmpty());
        c.setExperienceRange("gte10"); assertTrue(search(c).isEmpty());
    }
    @Test void currentJobUsesCurrentMonthWithoutFutureOvercount()
    {
        LocalDate start = LocalDate.now().withDayOfMonth(1).minusMonths(18);
        jdbc.update("insert into t_res_work values(10,4,?,null,1)",start);
        var c=new TalentSearchCriteria();c.setExperienceRange("1to3");
        assertTrue(ids(search(c)).contains(4L));
        var row=search(c).stream().filter(r -> ((Number)r.get("talentId")).longValue()==4).findFirst().orElseThrow();
        assertEquals(18,((Number)row.get("workMonths")).intValue());
    }
    @Test void degreeThresholdExcludesMissingAndRespectsResumeOwnership()
    {
        var c=new TalentSearchCriteria(); c.setMinimumEducation(3); assertEquals(List.of(4L,2L,1L),ids(search(c)));
        jdbc.execute("update t_res_base set rbs_user_id=999 where rbs_id=4"); assertEquals(List.of(2L,1L),ids(search(c)));
        c.setMinimumEducation(4);assertEquals(List.of(2L),ids(search(c)));
        c.setMinimumEducation(5);assertTrue(search(c).isEmpty());
    }
    @Test void cityTypesAndLoginWindowCombineWithExistingTagAndStatus()
    {
        var c=new TalentSearchCriteria(); c.setCity("杭州"); c.setCityType("current");c.setMinimumEducation(3);c.setLoginWithinDays(7);c.validate();
        assertEquals(List.of(1L),ids(mapper.selectFilteredTalentList(1L,"候选人1","Java","Java",3,1,c)));
        c.setCityType("target");assertTrue(search(c).isEmpty());
        c.setLoginWithinDays(null);assertEquals(List.of(4L,2L),ids(search(c)));
        assertEquals(List.of("上海","杭州"),mapper.selectTalentCities(1L,"current"));
    }
    @Test void nullAndFutureLoginDatesDoNotMeanRecentlyLoggedIn()
    {
        jdbc.execute("update sys_user set login_date=null where user_id=1");
        jdbc.update("update sys_user set login_date=? where user_id=2",Timestamp.valueOf(LocalDateTime.now().plusDays(1)));
        var c=new TalentSearchCriteria();c.setLoginWithinDays(7); assertTrue(search(c).isEmpty());
    }
    @Test void equalAndAdjacentIntervalsAreNotDoubleCountedAndFutureEndIsCapped()
    {
        jdbc.execute("insert into t_res_work values(20,5,'2020-01-01','2021-01-01',0),(21,5,'2020-01-01','2021-01-01',0),(22,5,'2021-01-01','2022-01-01',0)");
        var row=search(new TalentSearchCriteria()).stream().filter(r -> ((Number)r.get("talentId")).longValue()==5).findFirst().orElseThrow();
        assertEquals(24,((Number)row.get("workMonths")).intValue());
        jdbc.execute("delete from t_res_work where wrk_resume_id=5");
        jdbc.update("insert into t_res_work values(23,5,?,date '2999-01-01',0)",LocalDate.now().withDayOfMonth(1).minusMonths(8));
        row=search(new TalentSearchCriteria()).stream().filter(r -> ((Number)r.get("talentId")).longValue()==5).findFirst().orElseThrow();
        assertEquals(8,((Number)row.get("workMonths")).intValue());
    }

    @Test void advancedFiltersAreAppliedBeforePagination()
    {
        var c=new TalentSearchCriteria();c.setMinimumEducation(3);c.validate();
        PageHelper.startPage(2,1);
        var rows=mapper.selectFilteredTalentList(1L,null,null,null,null,null,c);
        assertEquals(List.of(2L),ids(rows));
        assertEquals(3,((com.github.pagehelper.Page<?>)rows).getTotal());
    }
}
