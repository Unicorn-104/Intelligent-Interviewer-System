package com.ruoyi.enterprise.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.ApplicationStatusMapper;
import com.ruoyi.enterprise.mapper.TalentPoolMapper;
import com.ruoyi.enterprise.service.EntResumeSnapshotService;
import com.ruoyi.enterprise.service.TalStatusService;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.service.IEnterpriseJobService;

/** reapplyTalent 必须以 useGeneratedKeys 回填的本次主键关联新快照，不再用 selectAppId 反查。 */
class ReapplyTalentApplicationTest
{
    private TalentPoolServiceImpl service;
    private TalentPoolMapper mapper;
    private DashboardMapper dashboard;
    private TalStatusService talStatusService;
    private IEnterpriseJobService enterpriseJobService;
    private EntResumeSnapshotService snapshotService;
    private ApplicationStatusMapper applicationStatusMapper;

    @BeforeEach void setup()
    {
        service = new TalentPoolServiceImpl();
        mapper = mock(TalentPoolMapper.class);
        dashboard = mock(DashboardMapper.class);
        talStatusService = mock(TalStatusService.class);
        enterpriseJobService = mock(IEnterpriseJobService.class);
        snapshotService = mock(EntResumeSnapshotService.class);
        applicationStatusMapper = mock(ApplicationStatusMapper.class);
        ReflectionTestUtils.setField(service, "talentPoolMapper", mapper);
        ReflectionTestUtils.setField(service, "dashboardMapper", dashboard);
        ReflectionTestUtils.setField(service, "talStatusService", talStatusService);
        ReflectionTestUtils.setField(service, "enterpriseJobService", enterpriseJobService);
        ReflectionTestUtils.setField(service, "entResumeSnapshotService", snapshotService);
        ReflectionTestUtils.setField(service, "applicationStatusMapper", applicationStatusMapper);
        when(dashboard.selectCompanyIdByUser(9L)).thenReturn(2L);
    }

    private Map<String, Object> talent()
    {
        Map<String, Object> talent = new LinkedHashMap<>();
        talent.put("talentId", 11L);
        talent.put("resumeId", 21L);
        talent.put("userId", 19L);
        return talent;
    }

    private void stubCommonGuards()
    {
        when(mapper.selectTalentById(2L, 11L)).thenReturn(talent());
        when(mapper.selectPositionInCompany(2L, 7L)).thenReturn(7);
        when(mapper.selectApplicationExists(11L, 7L)).thenReturn(null);
    }

    @Test void reapplyUsesGeneratedKeyAndLinksNewSnapshotWithoutSelectAppId()
    {
        stubCommonGuards();
        // 模拟 MyBatis useGeneratedKeys：把本次插入主键回填到参数 Map 的 appId
        when(mapper.insertApplication(any(Map.class))).thenAnswer(call -> {
            Map<String, Object> param = call.getArgument(0);
            param.put("appId", 101L);
            return 1;
        });
        when(talStatusService.change(anyLong(), anyInt(), anyList(), anyLong(), anyInt(), anyString(), anyLong()))
                .thenReturn(true);

        Map<String, Object> reply = service.reapplyTalent(9L, 11L, 7L);

        assertEquals(11L, reply.get("talentId"));
        // 快照必须用回填的本次主键 101，且其余上下文精确
        verify(snapshotService).createForApplication(101L, 19L, 11L, 2L, 7L, 21L);
        verify(enterpriseJobService).ensureProcessInstance(2L, 11L, 7L);
        // 关键：不再走不唯一的 selectAppId 反查
        verify(applicationStatusMapper, never()).selectAppId(anyLong(), anyLong());
    }

    @Test void reapplyFailsWhenGeneratedKeyMissingAndCreatesNoSnapshot()
    {
        stubCommonGuards();
        // 插入返回成功但未回填主键（异常驱动/配置错误场景）
        when(mapper.insertApplication(any(Map.class))).thenReturn(1);

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.reapplyTalent(9L, 11L, 7L));
        assertTrue(error.getMessage().contains("创建投递记录失败"));

        verify(snapshotService, never()).createForApplication(
                anyLong(), anyLong(), anyLong(), anyLong(), anyLong(), anyLong());
        verify(applicationStatusMapper, never()).selectAppId(anyLong(), anyLong());
    }

    @Test void reapplyRejectsExistingApplicationBeforeInsert()
    {
        when(mapper.selectTalentById(2L, 11L)).thenReturn(talent());
        when(mapper.selectPositionInCompany(2L, 7L)).thenReturn(7);
        when(mapper.selectApplicationExists(11L, 7L)).thenReturn(88);

        assertThrows(ServiceException.class, () -> service.reapplyTalent(9L, 11L, 7L));
        verify(mapper, never()).insertApplication(any(Map.class));
    }
}
