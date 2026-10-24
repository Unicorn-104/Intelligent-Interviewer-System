package com.ruoyi.enterprise.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.util.ReflectionTestUtils;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInterceptor;
import com.github.pagehelper.PageInfo;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.domain.TalentSearchCriteria;
import com.ruoyi.enterprise.mapper.TalentDiscoveryMapper;
import com.ruoyi.enterprise.service.TalentDiscoveryService;
import com.ruoyi.system.mapper.DashboardMapper;

/** H2合成注册账号；刻意不创建 t_tal/t_app_record/AI/招聘流程表。 */
public class TalentDiscoveryTest
{
    private JdbcTemplate jdbc;
    private TalentDiscoveryMapper mapper;
    private TalentDiscoveryService service;
    public static String format(Timestamp value, String pattern)
    {
        return value == null ? null : value.toLocalDateTime().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
    }
    @BeforeEach void setup() throws Exception
    {
        var ds = new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()
                +";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1", "sa", "");
        jdbc = new JdbcTemplate(ds);
        jdbc.execute("CREATE ALIAS date_format FOR 'com.ruoyi.enterprise.service.impl.TalentDiscoveryTest.format'");
        for (String sql : List.of(
            "create table sys_user(user_id bigint primary key,nick_name varchar(100),avatar varchar(200),user_identity_type int,status varchar(1),del_flag varchar(1),current_city varchar(50),target_city varchar(50),current_status int,target_direction varchar(100),login_date timestamp)",
            "create table sys_user_role(user_id bigint,role_id bigint)",
            "create table sys_role(role_id bigint,role_key varchar(100))",
            "create table t_res_base(rbs_id bigint primary key,rbs_user_id bigint,rbs_status int,rbs_is_default int,rbs_updated_at timestamp,rbs_job_direction varchar(100))",
            "create table t_res_education(edu_id bigint auto_increment primary key,edu_resume_id bigint,edu_degree int,edu_school varchar(100),edu_major varchar(100),edu_end_date date)",
            "create table t_usr_job_preference(user_id bigint primary key,salary_min int,salary_max int,salary_negotiable int)",
            "create table t_res_work(wrk_id bigint primary key,wrk_resume_id bigint,wrk_start_date date,wrk_end_date date,wrk_is_current int)")) jdbc.execute(sql);
        user(101,"合成未投递用户",1,"0","0","杭州","上海",2,"Java");
        user(102,"合成另一用户",1,"0","0","上海","杭州",1,null);
        user(103,"合成未建简历用户",1,"0","0","杭州","杭州",3,null);
        user(104,"合成禁用账号",1,"1","0","杭州","杭州",2,"Java");
        user(105,"合成已删除账号",1,"0","2","杭州","杭州",2,"Java");
        user(106,"合成招聘者账号",2,"0","0","杭州","杭州",2,"Java");
        user(107,"合成管理员",1,"0","0","杭州","杭州",2,"Java");
        jdbc.execute("insert into sys_role values(1,'admin')");
        jdbc.execute("insert into sys_user_role values(107,1)");
        jdbc.execute("insert into t_res_base values(11,101,1,1,current_timestamp,'旧期望'),(12,102,1,1,current_timestamp,'产品经理')");
        jdbc.execute("insert into t_res_education(edu_resume_id,edu_degree) values(11,2),(11,3),(11,0),(12,4)");
        jdbc.execute("insert into t_res_work values(1,11,'2019-01-01','2021-01-01',0),(2,11,'2020-01-01','2022-01-01',0),(3,11,'2020-01-01','2020-06-01',0)");
        var factory=new SqlSessionFactoryBean();factory.setDataSource(ds);
        var paging=new PageInterceptor();var props=new java.util.Properties();props.setProperty("helperDialect","mysql");paging.setProperties(props);factory.setPlugins(paging);
        factory.setMapperLocations(new ClassPathResource("mapper/enterprise/TalentDiscoveryMapper.xml"));
        mapper=new SqlSessionTemplate(factory.getObject()).getMapper(TalentDiscoveryMapper.class);
        var companies=mock(DashboardMapper.class);
        when(companies.selectCompanyIdByUser(9L)).thenReturn(1L);
        when(companies.selectCompanyIdByUser(8L)).thenReturn(2L);
        service=new TalentDiscoveryService();ReflectionTestUtils.setField(service,"discoveryMapper",mapper);
        ReflectionTestUtils.setField(service,"dashboardMapper",companies);
    }
    @AfterEach void clearPage() {PageHelper.clearPage();}
    private void user(long id,String name,int identity,String status,String deleted,String city,String target,int seeking,String direction)
    {
        jdbc.update("insert into sys_user values(?,?,null,?,?,?,?,?,?,?,?)",id,name,identity,status,deleted,city,target,seeking,direction,Timestamp.valueOf(LocalDateTime.now().minusDays(2)));
    }
    private List<Map<String,Object>> list(long viewer) {return service.list(viewer,null,null,null,1,20,new TalentSearchCriteria());}
    private List<Long> ids(List<Map<String,Object>> rows) {return rows.stream().map(r->((Number)r.get("userId")).longValue()).toList();}
    @Test void registeredUsersWithoutApplicationsOrTalentRecordsAreDiscoverableByEveryEnterprise()
    {
        assertEquals(List.of(103L,102L,101L),ids(list(9)));
        assertEquals(ids(list(9)),ids(list(8)));
        assertEquals(103L,((Number)service.detail(9L,103L).get("userId")).longValue());
        assertNull(service.detail(9L,103L).get("jobDirection"));
    }
    @Test void excludesDisabledDeletedEnterpriseAndAdministratorAccounts()
    {
        assertEquals(3,list(9).size());
        for(long id : List.of(104L,105L,106L,107L,999L))
            assertThrows(ServiceException.class,()->service.detail(9L,id));
    }
    @Test void responseContainsOnlyPublicBasicFieldsAndNoJobBoundOrSensitiveData()
    {
        Set<String> allowed=Set.of("userId","name","avatar","currentCity","targetCity","currentStatus",
                "jobDirection","highestEducation","workMonths","directoryVersion",
                "schoolName","major","graduationYear","salaryMin","salaryMax","salaryNegotiable");
        for(var row : list(9)) assertTrue(allowed.containsAll(row.keySet()));
        var row=service.detail(9L,101L);
        assertEquals("Java",row.get("jobDirection"));
        assertEquals(36,((Number)row.get("workMonths")).intValue());
        assertEquals(3,((Number)row.get("highestEducation")).intValue());
        for(String forbidden:List.of("talentId","positionId","matchedScore","status","tags","phone","email","password","resumeUrl","stageName"))
            assertFalse(row.containsKey(forbidden));
    }
    @Test void defaultActiveResumeDoesNotLeakOtherUsersOrInactiveResumeIntent()
    {
        jdbc.execute("insert into t_res_base values(21,102,0,1,'2099-01-01 00:00:00','失效期望'),(22,102,1,0,'2099-01-01 00:00:00','非默认期望')");
        assertEquals("产品经理",service.detail(9L,102L).get("jobDirection"));
        assertEquals("Java",service.detail(9L,101L).get("jobDirection"));
    }
    @Test void seekStatusIsNotCompanyRecruitmentStatusAndKeywordSearchIncludesIntent()
    {
        assertEquals(List.of(101L),ids(service.list(9L,"Java",null,2,1,20,new TalentSearchCriteria())));
        assertEquals(List.of(102L),ids(service.list(9L,"产品",null,1,1,20,new TalentSearchCriteria())));
        assertEquals(List.of(103L),ids(service.list(9L,null,null,3,1,20,new TalentSearchCriteria())));
        assertThrows(ServiceException.class,()->service.list(9L,null,null,0,1,20,new TalentSearchCriteria()));
        assertThrows(ServiceException.class,()->service.list(9L,null,null,9,1,20,new TalentSearchCriteria()));
    }
    @Test void combinedEducationExperienceCityAndLoginFilterBeforePagination()
    {
        var criteria=new TalentSearchCriteria();criteria.setMinimumEducation(3);criteria.setExperienceRange("3to5");
        criteria.setCity("上海");criteria.setCityType("target");criteria.setLoginWithinDays(7);
        assertEquals(List.of(101L),ids(service.list(9L,null,null,null,1,20,criteria)));
        var c=new TalentSearchCriteria();c.setExperienceRange("lt1");
        assertTrue(service.list(9L,null,null,null,1,20,c).isEmpty());
    }
    @Test void paginationCountsAllEligibleRegisteredUsersBeforeSlicing()
    {
        for(long id=200;id<224;id++)user(id,"合成分页用户"+id,1,"0","0","杭州","杭州",2,"Java");
        var page=service.list(9L,null,null,null,2,20,new TalentSearchCriteria());
        assertEquals(7,page.size());assertEquals(27,new PageInfo<>(page).getTotal());
    }
    @Test void optionsUseRegisteredProfilesNotEnterpriseInternalTagsOrApplications()
    {
        var options=service.options(9L);
        assertEquals(List.of("Java","产品经理"),options.get("directions"));
        assertEquals(List.of(),options.get("tags"));
        assertEquals(1,options.get("directoryVersion"));
    }
    @Test void unboundUsersInvalidIdsAndBadQueriesAreRejectedWithoutCompanyOneFallback()
    {
        assertThrows(ServiceException.class,()->list(1));
        assertThrows(ServiceException.class,()->service.options(99L));
        assertThrows(ServiceException.class,()->service.detail(9L,0L));
        assertThrows(ServiceException.class,()->service.list(9L,null,null,null,0,20,new TalentSearchCriteria()));
        assertThrows(ServiceException.class,()->service.list(9L,"x".repeat(101),null,null,1,20,new TalentSearchCriteria()));
        assertThrows(ServiceException.class,()->service.list(9L,"x\u0000",null,null,1,20,new TalentSearchCriteria()));
    }
    @Test void phoneOrEmailLikeNicknamesAreNotExposedInDiscovery()
    {
        jdbc.update("update sys_user set nick_name=? where user_id=101","00000000000");
        jdbc.update("update sys_user set nick_name=? where user_id=102","synthetic@example.invalid");
        assertEquals("求职者",service.detail(9L,101L).get("name"));
        assertEquals("求职者",service.detail(9L,102L).get("name"));
    }
    @Test void schoolComesFromHighestCompletedEducationInCurrentUsersActiveResume()
    {
        jdbc.execute("insert into t_res_education(edu_resume_id,edu_degree,edu_school,edu_major,edu_end_date) values"
            + "(11,3,'合成本科学校','软件工程','2022-06-30'),"
            + "(11,4,'合成硕士学校','计算机','2025-06-30'),"
            + "(11,5,'合成在读学校','计算机','2099-06-30'),"
            + "(12,5,'其他用户学校','其他专业','2024-06-30')");
        var row=service.detail(9L,101L);
        assertEquals("合成硕士学校",row.get("schoolName"));assertEquals("计算机",row.get("major"));
        assertEquals(2025,((Number)row.get("graduationYear")).intValue());
        assertNull(service.detail(9L,103L).get("schoolName"));
    }
    @Test void salaryUsesUserPreferenceOnlyAndDoesNotRequireResumeOrApplication()
    {
        jdbc.execute("insert into t_usr_job_preference values(101,8000,12000,0),(103,null,null,1)");
        var row=service.detail(9L,101L);
        assertEquals(8000,((Number)row.get("salaryMin")).intValue());
        assertEquals(12000,((Number)row.get("salaryMax")).intValue());
        assertEquals(1,((Number)service.detail(9L,103L).get("salaryNegotiable")).intValue());
        assertNull(service.detail(9L,102L).get("salaryMin"));
    }

}
