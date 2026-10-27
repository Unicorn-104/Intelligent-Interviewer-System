package com.ruoyi.system.service.app;

import java.util.Date;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.agent.AgentApplication;
import com.ruoyi.system.mapper.agent.AgentApplicationMapper;
import com.ruoyi.system.service.impl.agent.AgentApplicationServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AgentApplicationWithdrawalTest
{
    private final AgentApplicationMapper mapper = mock(AgentApplicationMapper.class);
    private final AgentApplicationServiceImpl service = new AgentApplicationServiceImpl();

    @BeforeEach
    void setup() { ReflectionTestUtils.setField(service, "applicationMapper", mapper); }

    private AgentApplication application(int status)
    {
        var item = new AgentApplication();
        item.setId(91L); item.setCandidateId(31L); item.setStatusCode(status);
        item.setCanWithdraw(status == 0); item.setAppliedAt(new Date(1)); item.setUpdatedAt(new Date(2));
        return item;
    }

    @Test
    void withdrawalRetainsRecordAndAddsTerminalTimeline()
    {
        when(mapper.lockWithdrawalCandidate(17L, 91L)).thenReturn(31L);
        when(mapper.selectApplicationById(17L, 91L)).thenReturn(application(0), application(9));
        when(mapper.withdrawApplication(17L, 91L)).thenReturn(1);
        var result = service.withdrawApplication(17L, 91L);
        assertEquals("已撤回", result.getStatusText());
        assertEquals("closed", result.getStatus());
        assertFalse(result.getCanWithdraw());
        assertEquals("withdrawn", result.getTimeline().get(result.getTimeline().size() - 1).getStage());
    }

    @Test
    void foreignApplicationIsRejectedBeforeAnyMutation()
    {
        when(mapper.lockWithdrawalCandidate(18L, 91L)).thenReturn(null);
        assertThrows(ServiceException.class, () -> service.withdrawApplication(18L, 91L));
        verify(mapper, never()).withdrawApplication(anyLong(), anyLong());
    }

    @Test
    void repeatedWithdrawalIsIdempotent()
    {
        when(mapper.lockWithdrawalCandidate(17L, 91L)).thenReturn(31L);
        when(mapper.selectApplicationById(17L, 91L)).thenReturn(application(9));
        assertEquals("已撤回", service.withdrawApplication(17L, 91L).getStatusText());
        verify(mapper, never()).withdrawApplication(anyLong(), anyLong());
    }

    @Test
    void progressedApplicationAndConcurrentStateChangesAreRejected()
    {
        when(mapper.lockWithdrawalCandidate(17L, 91L)).thenReturn(31L);
        when(mapper.selectApplicationById(17L, 91L)).thenReturn(application(3));
        assertThrows(ServiceException.class, () -> service.withdrawApplication(17L, 91L));
        verify(mapper, never()).withdrawApplication(anyLong(), anyLong());
        when(mapper.selectApplicationById(17L, 91L)).thenReturn(application(0));
        when(mapper.withdrawApplication(17L, 91L)).thenReturn(0);
        assertThrows(ServiceException.class, () -> service.withdrawApplication(17L, 91L));
    }

    @Test
    void sqlEnforcesOwnershipPendingStateAndNoStartedWorkflow() throws Exception
    {
        var source = new org.apache.ibatis.datasource.unpooled.UnpooledDataSource("org.h2.Driver",
                "jdbc:h2:mem:" + java.util.UUID.randomUUID() + ";MODE=MySQL;DB_CLOSE_DELAY=-1", "sa", "");
        try (var connection = source.getConnection(); var statement = connection.createStatement())
        {
            statement.execute("create table t_tal(tal_id bigint primary key,tal_user_id bigint,tal_status int,tal_process_instance_id bigint,tal_exam_record_id bigint)");
            statement.execute("create table t_app_record(app_id bigint primary key,app_candidate_id bigint,app_position_id bigint,app_status int,app_updated_at timestamp)");
            statement.execute("create table t_process_instance(pin_candidate_id bigint,pin_position_id bigint)");
            statement.execute("create table t_int_session(ses_candidate_id bigint,ses_position_id bigint)");
            statement.execute("create table t_exam_schedule(esd_id bigint,esd_position_id bigint)");
            statement.execute("create table t_exam_record(erc_candidate_id bigint,erc_schedule_id bigint)");
            statement.execute("insert into t_tal values(31,17,1,null,null),(32,18,1,null,null),(33,17,1,1,null),(34,17,2,null,null)");
            statement.execute("insert into t_app_record values(91,31,71,0,null),(92,32,71,0,null),(93,33,71,0,null),(94,31,72,3,null),(95,34,71,0,null),(96,31,74,0,null),(97,31,75,0,null)");
            statement.execute("insert into t_process_instance values(33,71),(31,72)");
            statement.execute("insert into t_int_session values(34,71),(31,74)");
            statement.execute("insert into t_exam_schedule values(81,75)");
            statement.execute("insert into t_exam_record values(31,81)");
        }
        var config = new org.apache.ibatis.session.Configuration(new org.apache.ibatis.mapping.Environment("test",
                new org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory(), source));
        String resource = "mapper/agent/AgentApplicationMapper.xml";
        try (var xml = getClass().getClassLoader().getResourceAsStream(resource))
        { new org.apache.ibatis.builder.xml.XMLMapperBuilder(xml, config, resource, config.getSqlFragments()).parse(); }
        try (var session = new org.apache.ibatis.session.SqlSessionFactoryBuilder().build(config).openSession())
        {
            var sql = session.getMapper(AgentApplicationMapper.class);
            assertEquals(31L, sql.lockWithdrawalCandidate(17L, 91L));
            assertNull(sql.lockWithdrawalCandidate(17L, 92L));
            for (long id : new long[]{92, 93, 94, 95, 96, 97, 999}) assertEquals(0, sql.withdrawApplication(17L, id));
            assertEquals(1, sql.withdrawApplication(17L, 91L));
            assertEquals(0, sql.withdrawApplication(17L, 91L));
        }
    }
}
