package com.ruoyi.system.service.app;

import static org.junit.jupiter.api.Assertions.*;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import com.ruoyi.system.domain.Company;
import com.ruoyi.system.mapper.app.AppCompanyMapper;

public class RecruiterPublicMapperTest
{
    @Test
    void onlyActiveBoundRecruitersExposeAllowlistedPublicFields() throws Exception
    {
        var source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID() + ";MODE=MySQL;DATABASE_TO_UPPER=false", "sa", "");
        var jdbc = new JdbcTemplate(source);
        try (var connection = source.getConnection())
        {
            jdbc.execute("create table sys_user(user_id bigint primary key,nick_name varchar(50),user_name varchar(50),avatar varchar(100),status varchar(1),del_flag varchar(1),password varchar(100),phonenumber varchar(20),email varchar(100))");
            jdbc.execute("create table t_cmp(cmp_id bigint primary key,cmp_name varchar(100),cmp_status int)");
            jdbc.execute("create table t_cmp_binding(bnd_user_id bigint,bnd_company_id bigint,bnd_status int)");
            jdbc.execute("insert into sys_user values(20,'合成 HR','synthetic','/profile/avatar.png','0','0','never-expose','never-expose','never-expose'),(21,'未绑定','unbound',null,'0','0',null,null,null)");
            jdbc.execute("insert into t_cmp values(3,'合成企业',1)");
            jdbc.execute("insert into t_cmp_binding values(20,3,1)");
            var factory = new SqlSessionFactoryBean();
            factory.setDataSource(source);
            factory.setTypeAliases(Company.class);
            factory.setMapperLocations(new ClassPathResource("mapper/app/AppCompanyMapper.xml"));
            var mapper = new SqlSessionTemplate(factory.getObject()).getMapper(AppCompanyMapper.class);
            var contact = mapper.selectRecruiter(20L);
            assertEquals(Set.of("id", "name", "avatarUrl", "companyId", "companyName"), contact.keySet());
            assertEquals("合成 HR", contact.get("name"));
            jdbc.update("update sys_user set nick_name='' where user_id=20");
            assertEquals("招聘联系人", mapper.selectRecruiter(20L).get("name"));
            assertNull(mapper.selectRecruiter(21L));
            assertNull(mapper.selectRecruiter(999L));
            jdbc.update("update sys_user set status='1' where user_id=20");
            assertNull(mapper.selectRecruiter(20L));
            jdbc.update("update sys_user set status='0',del_flag='2' where user_id=20");
            assertNull(mapper.selectRecruiter(20L));
            jdbc.update("update sys_user set del_flag='0' where user_id=20");
            jdbc.update("update t_cmp_binding set bnd_status=0");
            assertNull(mapper.selectRecruiter(20L));
            jdbc.update("update t_cmp_binding set bnd_status=1");
            jdbc.update("update t_cmp set cmp_status=0");
            assertNull(mapper.selectRecruiter(20L));
        }
    }
}
