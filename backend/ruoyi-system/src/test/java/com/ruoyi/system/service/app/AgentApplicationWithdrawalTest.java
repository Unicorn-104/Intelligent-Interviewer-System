package com.ruoyi.system.service.app;

import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.service.ApplicationStatusService;
import com.ruoyi.system.domain.agent.AgentApplication;
import com.ruoyi.system.mapper.agent.AgentApplicationMapper;
import com.ruoyi.system.service.impl.agent.AgentApplicationServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * 候选人撤回投递测试。
 *
 * <p>撤回已收口到状态机：service 仅做归属与可撤回资格校验，随后委托
 * {@link ApplicationStatusService#withdraw} 落 0→5/CANDIDATE_WITHDRAWN；
 * mapper.withdrawApplication 已降级为只读 COUNT 资格校验，不再直接写 app_status。</p>
 */
class AgentApplicationWithdrawalTest
{
    private final AgentApplicationMapper mapper = mock(AgentApplicationMapper.class);
    private final ApplicationStatusService statusService = mock(ApplicationStatusService.class);
    private final AgentApplicationServiceImpl service = new AgentApplicationServiceImpl();

    @BeforeEach
    void setup()
    {
        ReflectionTestUtils.setField(service, "applicationMapper", mapper);
        ReflectionTestUtils.setField(service, "applicationStatusService", statusService);
    }

    private AgentApplication application(int status, boolean canWithdraw)
    {
        var item = new AgentApplication();
        item.setId(91L);
        item.setCandidateId(31L);
        item.setJobId(71L);
        item.setStatusCode(status);
        item.setCanWithdraw(canWithdraw);
        return item;
    }

    @Test
    void withdrawalDelegatesToStatusMachineAndReturnsLatestApplication()
    {
        when(mapper.lockWithdrawalCandidate(17L, 91L)).thenReturn(31L);
        when(mapper.selectApplicationById(17L, 91L))
            .thenReturn(application(0, true), application(5, false));
        when(statusService.withdraw(31L, 71L, 17L)).thenReturn(true);

        AgentApplication result = service.withdrawApplication(17L, 91L);
        assertEquals(5, result.getStatusCode());
        assertFalse(result.getCanWithdraw());
        verify(statusService).withdraw(31L, 71L, 17L);
    }

    @Test
    void foreignApplicationIsRejectedBeforeAnyMutation()
    {
        when(mapper.lockWithdrawalCandidate(18L, 91L)).thenReturn(null);
        assertThrows(ServiceException.class,
            () -> service.withdrawApplication(18L, 91L));
        verify(statusService, never()).withdraw(anyLong(), anyLong(), anyLong());
    }

    @Test
    void applicationInProgressIsRejectedWithoutStatusChange()
    {
        when(mapper.lockWithdrawalCandidate(17L, 91L)).thenReturn(31L);
        when(mapper.selectApplicationById(17L, 91L)).thenReturn(application(3, false));
        assertThrows(ServiceException.class,
            () -> service.withdrawApplication(17L, 91L));
        verify(statusService, never()).withdraw(anyLong(), anyLong(), anyLong());
    }

    @Test
    void repeatedWithdrawalIsRejectedWithoutStatusChange()
    {
        when(mapper.lockWithdrawalCandidate(17L, 91L)).thenReturn(31L);
        when(mapper.selectApplicationById(17L, 91L)).thenReturn(application(5, false));
        assertThrows(ServiceException.class,
            () -> service.withdrawApplication(17L, 91L));
        verify(statusService, never()).withdraw(anyLong(), anyLong(), anyLong());
    }

    @Test
    void mapperEnforcesOwnershipAndReadonlyCountInH2() throws Exception
    {
        // H2 内存库：仅验证归属 FOR UPDATE 与只读 COUNT，不连持久化库、不触网
        var source = new org.apache.ibatis.datasource.unpooled.UnpooledDataSource("org.h2.Driver",
            "jdbc:h2:mem:" + java.util.UUID.randomUUID() + ";MODE=MySQL;DB_CLOSE_DELAY=-1", "sa", "");
        try (var connection = source.getConnection(); var statement = connection.createStatement())
        {
            statement.execute("create table t_tal(tal_id bigint primary key,tal_user_id bigint)");
            statement.execute("create table t_app_record(app_id bigint primary key,app_candidate_id bigint,"
                + "app_position_id bigint,app_status int)");
            statement.execute("insert into t_tal values(31,17),(32,18),(33,17),(34,17)");
            statement.execute("insert into t_app_record values(91,31,71,0),(92,32,71,0),(93,33,71,0),"
                + "(94,31,72,3),(95,34,71,0),(96,31,74,0),(97,31,75,0)");
        }
        var config = new org.apache.ibatis.session.Configuration(new org.apache.ibatis.mapping.Environment("test",
            new org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory(), source));
        String resource = "mapper/agent/AgentApplicationMapper.xml";
        try (var xml = getClass().getClassLoader().getResourceAsStream(resource))
        {
            new org.apache.ibatis.builder.xml.XMLMapperBuilder(xml, config, resource, config.getSqlFragments()).parse();
        }
        try (var session = new org.apache.ibatis.session.SqlSessionFactoryBuilder().build(config).openSession())
        {
            var sql = session.getMapper(AgentApplicationMapper.class);
            assertEquals(31L, sql.lockWithdrawalCandidate(17L, 91L));
            assertNull(sql.lockWithdrawalCandidate(17L, 92L));
            // withdrawApplication 现为只读 COUNT：app_status=0 且归属本人才计 1
            assertEquals(1, sql.withdrawApplication(17L, 91L));
            assertEquals(0, sql.withdrawApplication(17L, 92L));
            assertEquals(1, sql.withdrawApplication(17L, 93L));
            assertEquals(0, sql.withdrawApplication(17L, 94L));
            assertEquals(1, sql.withdrawApplication(17L, 95L));
            assertEquals(0, sql.withdrawApplication(17L, 999L));
        }
    }
}
