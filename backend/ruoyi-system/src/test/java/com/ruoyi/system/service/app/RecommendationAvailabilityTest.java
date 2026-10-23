package com.ruoyi.system.service.app;

import java.io.InputStream;
import java.util.List;
import org.apache.ibatis.builder.xml.XMLMapperBuilder;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.Configuration;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.junit.jupiter.api.Test;
import com.ruoyi.system.mapper.app.AppJobMapper;
import static org.junit.jupiter.api.Assertions.*;

class RecommendationAvailabilityTest
{
    @Test
    void realMapperRestrictsIdsAndRejectsOfflineJobsAndDisabledCompanies() throws Exception
    {
        UnpooledDataSource source = new UnpooledDataSource("org.h2.Driver",
                "jdbc:h2:mem:recommend_security;MODE=MySQL", "sa", "");
        Configuration config = new Configuration(new Environment("test", new JdbcTransactionFactory(), source));
        String resource = "mapper/app/AppJobMapper.xml";
        try (InputStream xml = getClass().getClassLoader().getResourceAsStream(resource))
        {
            assertNotNull(xml);
            new XMLMapperBuilder(xml, config, resource, config.getSqlFragments()).parse();
        }
        try (SqlSession session = new SqlSessionFactoryBuilder().build(config).openSession())
        {
            try (var statement = session.getConnection().createStatement())
            {
                statement.execute("create table t_cmp(cmp_id bigint primary key, cmp_status int)");
                statement.execute("create table t_pos(pos_id bigint primary key, pos_company_id bigint, pos_status int)");
                statement.execute("insert into t_cmp values(1,1),(2,0)");
                statement.execute("insert into t_pos values(91,1,1),(92,1,0),(93,2,1),(94,1,1)");
            }
            AppJobMapper mapper = session.getMapper(AppJobMapper.class);
            assertEquals(List.of(91L), mapper.selectAvailableRecommendationIds(List.of(91L, 92L, 93L, 999L)));
            assertTrue(mapper.selectAvailableRecommendationIds(List.of()).isEmpty());
            assertTrue(mapper.selectAvailableRecommendationIds(null).isEmpty());
        }
    }
}
