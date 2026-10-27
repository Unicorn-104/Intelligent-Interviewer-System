package com.ruoyi.enterprise.service;

import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.enterprise.mapper.EnterpriseSystemNoticeMapper;

class EnterpriseSystemNoticeSchedulerTest
{
    @Test void schedulerKeepsOtherRecipientsWhenOneFailsAndCyclesCursor() {
        var mapper=mock(EnterpriseSystemNoticeMapper.class);
        var service=mock(EnterpriseSystemNoticeService.class);
        var scheduler=new EnterpriseSystemNoticeScheduler();
        ReflectionTestUtils.setField(scheduler,"mapper",mapper);ReflectionTestUtils.setField(scheduler,"notices",service);
        when(mapper.recipients(0L)).thenReturn(List.of(9L,10L));
        doThrow(new IllegalStateException("synthetic")).when(service).refresh(9L);
        assertDoesNotThrow(scheduler::refresh);verify(service).refresh(10L);
        scheduler.refresh();verify(service,times(2)).refresh(9L);
    }
    @Test void fullBatchContinuesFromLastAccountAndEmptyBatchResetsCursor() {
        var mapper=mock(EnterpriseSystemNoticeMapper.class);
        var service=mock(EnterpriseSystemNoticeService.class);
        var scheduler=new EnterpriseSystemNoticeScheduler();
        ReflectionTestUtils.setField(scheduler,"mapper",mapper);ReflectionTestUtils.setField(scheduler,"notices",service);
        when(mapper.recipients(0L)).thenReturn(java.util.stream.LongStream.rangeClosed(1,100).boxed().toList());
        when(mapper.recipients(100L)).thenReturn(List.of());
        scheduler.refresh();scheduler.refresh();scheduler.refresh();
        verify(mapper,times(2)).recipients(0L);verify(mapper).recipients(100L);
        verify(service,times(2)).refresh(100L);
    }
}
