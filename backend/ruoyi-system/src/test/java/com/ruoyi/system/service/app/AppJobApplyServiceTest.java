package com.ruoyi.system.service.app;

import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.mapper.app.AppJobMapper;
import com.ruoyi.system.service.app.impl.AppJobServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AppJobApplyServiceTest
{
    private final AppJobMapper mapper = mock(AppJobMapper.class);
    private final AppJobServiceImpl service = new AppJobServiceImpl();

    @BeforeEach
    void setup()
    {
        ReflectionTestUtils.setField(service, "jobMapper", mapper);
        when(mapper.selectCompanyIdByPositionId(91L)).thenReturn(71L);
        when(mapper.selectCandidateId(17L, 71L)).thenReturn(31L);
        when(mapper.insertApplication(eq(31L), eq(91L), anyLong())).thenReturn(1);
    }

    @Test
    void selectedNonDefaultResumeIsUsedForApplication()
    {
        when(mapper.selectOwnedResumeId(17L, 52L)).thenReturn(52L);
        service.apply(17L, 91L, 52L);
        verify(mapper).insertApplication(31L, 91L, 52L);
        verify(mapper, never()).selectDefaultResumeId(anyLong());
    }

    @Test
    void missingOrForeignResumeCannotFallBackToDefault()
    {
        when(mapper.selectOwnedResumeId(17L, 999L)).thenReturn(null);
        assertThrows(ServiceException.class, () -> service.apply(17L, 91L, 999L));
        verify(mapper, never()).selectDefaultResumeId(anyLong());
        verify(mapper, never()).insertApplication(anyLong(), anyLong(), anyLong());
        verify(mapper, never()).insertCandidate(anyLong(), anyLong(), anyLong());
    }

    @Test
    void oldClientsMayStillApplyWithDefaultResume()
    {
        when(mapper.selectDefaultResumeId(17L)).thenReturn(51L);
        service.apply(17L, 91L);
        verify(mapper).insertApplication(31L, 91L, 51L);
    }

    @Test
    void resumeLookupSqlOnlyReturnsActiveOwnedRows() throws Exception
    {
        var source = new org.apache.ibatis.datasource.unpooled.UnpooledDataSource("org.h2.Driver",
                "jdbc:h2:mem:" + java.util.UUID.randomUUID() + ";MODE=MySQL;DB_CLOSE_DELAY=-1", "sa", "");
        try (var connection = source.getConnection(); var statement = connection.createStatement())
        {
            statement.execute("create table t_res_base(rbs_id bigint primary key,rbs_user_id bigint,rbs_status int)");
            statement.execute("insert into t_res_base values(51,17,1),(52,17,1),(53,18,1),(54,17,0)");
        }
        var config = new org.apache.ibatis.session.Configuration(new org.apache.ibatis.mapping.Environment("test",
                new org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory(), source));
        String resource = "mapper/app/AppJobMapper.xml";
        try (var xml = getClass().getClassLoader().getResourceAsStream(resource))
        { new org.apache.ibatis.builder.xml.XMLMapperBuilder(xml, config, resource, config.getSqlFragments()).parse(); }
        try (var session = new org.apache.ibatis.session.SqlSessionFactoryBuilder().build(config).openSession())
        {
            var sqlMapper = session.getMapper(AppJobMapper.class);
            assertEquals(52L, sqlMapper.selectOwnedResumeId(17L, 52L));
            assertNull(sqlMapper.selectOwnedResumeId(17L, 53L));
            assertNull(sqlMapper.selectOwnedResumeId(17L, 54L));
            assertNull(sqlMapper.selectOwnedResumeId(17L, 999L));
        }
    }

    @Test
    void duplicateApplicationDoesNotInsertAgain()
    {
        when(mapper.selectOwnedResumeId(17L, 52L)).thenReturn(52L);
        when(mapper.countApplication(31L, 91L)).thenReturn(1);
        assertThrows(ServiceException.class, () -> service.apply(17L, 91L, 52L));
        verify(mapper, never()).insertApplication(anyLong(), anyLong(), anyLong());
    }
}
