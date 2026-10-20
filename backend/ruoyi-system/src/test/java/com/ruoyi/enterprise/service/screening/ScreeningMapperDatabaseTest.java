package com.ruoyi.enterprise.service.screening;

import static org.junit.jupiter.api.Assertions.*;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import org.apache.ibatis.builder.xml.XMLMapperBuilder;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.Configuration;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import com.ruoyi.enterprise.mapper.ScreeningMapper;

/** Opt-in local MySQL smoke; every row written by this test is rolled back. */
@EnabledIfEnvironmentVariable(named = "SCREENING_DB_SMOKE", matches = "true")
class ScreeningMapperDatabaseTest
{
    @Test void actualMybatisStatementsRespectScopeAndPersistJsonWithoutLeavingTestData() throws Exception
    {
        var source = new UnpooledDataSource("com.mysql.cj.jdbc.Driver", System.getenv("SCREENING_DB_URL"),
                System.getenv("SCREENING_DB_USER"), System.getenv("SCREENING_DB_PASSWORD"));
        var configuration = new Configuration(new Environment("screening-smoke", new JdbcTransactionFactory(), source));
        try (var xml = getClass().getResourceAsStream("/mapper/enterprise/ScreeningMapper.xml"))
        {
            assertNotNull(xml);
            new XMLMapperBuilder(xml, configuration, "mapper/enterprise/ScreeningMapper.xml", configuration.getSqlFragments()).parse();
        }
        var factory = new SqlSessionFactoryBuilder().build(configuration);
        try (var session = factory.openSession(false))
        {
            try (var statement = session.getConnection().createStatement(); var rows = statement.executeQuery(
                    "select pos.pos_company_id, pos.pos_id from t_pos pos join t_process_instance p on p.pin_position_id=pos.pos_id "
                    + "join t_tal t on t.tal_id=p.pin_candidate_id and t.tal_company_id=pos.pos_company_id limit 1"))
            {
                assertTrue(rows.next(), "Local smoke requires one existing job with a candidate");
                long company = rows.getLong(1), position = rows.getLong(2);
                var mapper = session.getMapper(ScreeningMapper.class);
                assertNotNull(mapper.selectPosition(company, position));
                assertNull(mapper.selectPosition(Long.MAX_VALUE, position));
                var candidates = mapper.selectCandidatesByPosition(position);
                assertFalse(candidates.isEmpty());
                // Match the authoritative membership used by EnterpriseJobMapper, including talents whose active pointer moved.
                try (var expected = session.getConnection().prepareStatement("select count(distinct t.tal_id) from t_process_instance p join t_tal t on t.tal_id=p.pin_candidate_id where p.pin_position_id=? and t.tal_company_id=?"))
                {
                    expected.setLong(1, position); expected.setLong(2, company);
                    try (var result = expected.executeQuery()) { assertTrue(result.next()); assertEquals(result.getInt(1), candidates.size()); }
                }
                long talent = ((Number)candidates.get(0).get("talentId")).longValue();
                Object resume = candidates.get(0).get("resumeId");
                assertNotNull(mapper.selectOwnedCandidate(company, talent));
                assertNull(mapper.selectOwnedCandidate(Long.MAX_VALUE, talent));
                mapper.selectPositionSkills(position); mapper.selectCandidateSkills(talent);
                if (resume instanceof Number id)
                {
                    mapper.selectEducationEvidence(id.longValue()); mapper.selectWorkEvidence(id.longValue());
                    mapper.selectProjectEvidence(id.longValue());
                }
                mapper.selectTaskList(company); mapper.selectResultsByPosition(position);
                mapper.initTask(company, position);
                String run = UUID.randomUUID().toString();
                assertEquals(1, mapper.claimTask(company, position, run, candidates.size()));
                assertEquals(0, mapper.claimTask(company, position, UUID.randomUUID().toString(), candidates.size()));
                assertEquals(run, mapper.selectTaskStatus(company, position).get("runId"));
                assertEquals(run, mapper.lockTask(company, position).get("runId"));
                Map<String, Object> report = new LinkedHashMap<>();
                report.put("companyId", company); report.put("positionId", position); report.put("resultId", talent);
                report.put("resumeId", resume); report.put("report", "{\"source\":\"llm\",\"recommendation\":\"演示数据：事务回滚验证\"}");
                assertTrue(mapper.saveAnalysis(report) > 0);
                assertTrue(mapper.selectAnalysis(company, position, talent).get("report").toString().contains("llm"));
                assertNotNull(mapper.selectLatestAnalysis(company, talent));
                assertNull(mapper.selectAnalysis(Long.MAX_VALUE, position, talent));
                assertEquals(1, mapper.updateTask(company, position, run, "completed", candidates.size(), 1, null));
                assertEquals(0, mapper.updateTask(company, position, "stale-run", "failed", 0, 0, "stale"));
            }
            finally { session.rollback(); }
        }
    }
}
