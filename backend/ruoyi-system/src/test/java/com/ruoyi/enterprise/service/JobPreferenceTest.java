package com.ruoyi.enterprise.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.UUID;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.JobPreferenceMapper;
import com.ruoyi.system.domain.app.AppUserProfile;
import com.ruoyi.system.mapper.app.AppUserProfileMapper;
import com.ruoyi.system.service.ISysUserService;
import com.ruoyi.system.service.app.impl.AppUserProfileServiceImpl;

/** 合成H2验证本人求职薪资，绝不读取应用私有数据源。 */
public class JobPreferenceTest
{
    public static java.sql.Timestamp sysdate() { return java.sql.Timestamp.valueOf(java.time.LocalDateTime.now()); }
    JdbcTemplate jdbc;
    AppUserProfileServiceImpl service;
    AppUserProfileMapper profiles;
    JobPreferenceMapper preferences;
    DriverManagerDataSource ds;
    @BeforeEach void setup() throws Exception
    {
        ds=new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1","sa","");
        jdbc=new JdbcTemplate(ds);
        Path directory=Path.of("").toAbsolutePath();
        while(directory!=null&&!Files.exists(directory.resolve("e-app/new.sql")))directory=directory.getParent();
        assertNotNull(directory);
        String section=Files.readString(directory.resolve("e-app/new.sql")).split("-- BEGIN TALENT_EXPECTATION_20261023")[1];
        String ddl=section.substring(section.indexOf("CREATE TABLE"));ddl=ddl.substring(0,ddl.indexOf(';')+1)
            .replaceAll("COMMENT '[^']*'","").replaceAll("ENGINE=InnoDB DEFAULT CHARSET=utf8mb4","");
        jdbc.execute(ddl);jdbc.execute(ddl);
        for(String sql:List.of(
            "create table sys_user(user_id bigint primary key,user_name varchar(100),nick_name varchar(100),real_name varchar(100),avatar varchar(200),email varchar(100),phonenumber varchar(30),sex varchar(1),remark varchar(500),current_city varchar(50),current_status int,target_direction varchar(100),target_city varchar(50),del_flag varchar(1),update_by varchar(100),update_time timestamp)",
            "create table t_usr_verify(vef_id bigint,vef_user_id bigint,vef_status int)",
            "create table t_tal(tal_id bigint,tal_user_id bigint)",
            "create table t_app_record(app_candidate_id bigint)",
            "create table t_sch_appointment(apt_candidate_id bigint,apt_status int)",
            "create table t_usr_interest(int_user_id bigint,int_status int)",
            "create table t_res_base(rbs_id bigint,rbs_user_id bigint,rbs_status int)",
            "create table t_res_work(wrk_resume_id bigint,wrk_start_date date)",
            "insert into sys_user(user_id,nick_name,del_flag)values(101,'合成用户','0'),(102,'另一用户','0')"))jdbc.execute(sql);
        var factory=new SqlSessionFactoryBean();factory.setDataSource(ds);
        factory.setMapperLocations(new ClassPathResource("mapper/enterprise/JobPreferenceMapper.xml"),new org.springframework.core.io.ByteArrayResource(new String(new ClassPathResource("mapper/app/AppUserProfileMapper.xml").getInputStream().readAllBytes(), java.nio.charset.StandardCharsets.UTF_8).replace("sysdate()", "current_timestamp").getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        var session=new SqlSessionTemplate(factory.getObject());
        profiles=session.getMapper(AppUserProfileMapper.class);preferences=session.getMapper(JobPreferenceMapper.class);
        service=service(preferences);
    }
    AppUserProfileServiceImpl service(JobPreferenceMapper preferenceMapper)
    {
        var target=new AppUserProfileServiceImpl();
        ReflectionTestUtils.setField(target,"profileMapper",profiles);
        ReflectionTestUtils.setField(target,"jobPreferenceMapper",preferenceMapper);
        var users=mock(ISysUserService.class);when(users.selectUserById(101L)).thenReturn(new SysUser());
        ReflectionTestUtils.setField(target,"userService",users);
        var proxy=new ProxyFactory(target);proxy.setProxyTargetClass(true);
        proxy.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(ds),new AnnotationTransactionAttributeSource()));
        return (AppUserProfileServiceImpl)proxy.getProxy();
    }
    AppUserProfile payload(Integer mode,Integer min,Integer max)
    {
        var p=new AppUserProfile();p.setUserId(101L);p.setNickName("合成用户");
        p.setSalaryNegotiable(mode);p.setSalaryMin(min);p.setSalaryMax(max);return p;
    }
    @Test void explicitRangePersistsAndProfileReadsSameUnitsWithoutChangingAnotherUser()
    {
        service.updateProfile(payload(0,8000,12000));
        var p=service.selectProfileByUserId(101L);
        assertEquals(8000,p.getSalaryMin());assertEquals(12000,p.getSalaryMax());assertEquals(0,p.getSalaryNegotiable());
        assertNull(service.selectProfileByUserId(102L).getSalaryMin());
    }
    @Test void negotiableAndUnknownAreDistinctAndExplicitClearDoesNotSaveZero()
    {
        service.updateProfile(payload(0,8000,12000));service.updateProfile(payload(1,null,null));
        assertEquals(1,service.selectProfileByUserId(101L).getSalaryNegotiable());
        service.updateProfile(payload(null,null,null));
        var p=service.selectProfileByUserId(101L);assertNull(p.getSalaryMin());assertNull(p.getSalaryMax());assertNull(p.getSalaryNegotiable());
    }
    @Test void legacyRequestOmittingSalaryPreservesExistingPreference() throws Exception
    {
        service.updateProfile(payload(0,8000,12000));
        var p=new ObjectMapper().readValue("{\"userId\":101,\"nickName\":\"新合成昵称\"}",AppUserProfile.class);
        assertFalse(p.isSalaryProvided());service.updateProfile(p);
        assertEquals(12000,service.selectProfileByUserId(101L).getSalaryMax());
        var clear=new ObjectMapper().readValue("{\"salaryMin\":null,\"salaryMax\":null,\"salaryNegotiable\":null}",AppUserProfile.class);
        assertTrue(clear.isSalaryProvided());assertDoesNotThrow(clear::validateSalary);
    }
    @Test void validationRejectsReversedPartialNegativeAndConflictingModes()
    {
        for(var p:List.of(payload(0,12000,8000),payload(0,8000,null),payload(0,-1,100),
            payload(1,8000,12000),payload(null,8000,12000),payload(2,null,null),payload(0,0,10000001)))
            assertThrows(ServiceException.class,()->service.updateProfile(p));
        assertEquals(0,jdbc.queryForObject("select count(*)from t_usr_job_preference",Integer.class));
    }
    @Test void databaseChecksRejectNullModeWithRangeAndOtherInvalidDirectWrites()
    {
        for(String values:List.of("101,8000,12000,null","101,12000,8000,0","101,8000,null,0","101,8000,12000,1","101,null,null,2"))
            assertThrows(org.springframework.dao.DataIntegrityViolationException.class,()->jdbc.execute("insert into t_usr_job_preference(user_id,salary_min,salary_max,salary_negotiable)values("+values+")"));
    }
    @Test void salaryFailureRollsBackProfileEditTogetherWithPreference()
    {
        var failing=mock(JobPreferenceMapper.class);when(failing.saveSalary(any())).thenThrow(new IllegalStateException("合成失败"));
        var p=payload(0,8000,12000);p.setNickName("不得提交的昵称");
        assertThrows(IllegalStateException.class,()->service(failing).updateProfile(p));
        assertEquals("合成用户",jdbc.queryForObject("select nick_name from sys_user where user_id=101",String.class));
    }
}
