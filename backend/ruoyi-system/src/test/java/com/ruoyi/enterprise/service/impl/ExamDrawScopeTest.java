package com.ruoyi.enterprise.service.impl;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.List;
import org.junit.jupiter.api.Test;
import com.ruoyi.common.exception.ServiceException;

class ExamDrawScopeTest
{
    @Test
    void keepsLegacyRulesOnBothBanks()
    {
        assertNull(ExamServiceImpl.resolveDrawScope(null));
    }

    @Test
    void resolvesSingleBank()
    {
        assertEquals("platform", ExamServiceImpl.resolveDrawScope(List.of("platform")));
        assertEquals("enterprise", ExamServiceImpl.resolveDrawScope("enterprise"));
        assertEquals("platform", ExamServiceImpl.resolveDrawScope(" platform, "));
    }

    @Test
    void treatsBothBanksAsUnrestrictedForBackwardCompatibility()
    {
        assertNull(ExamServiceImpl.resolveDrawScope(List.of("platform", "enterprise")));
        assertNull(ExamServiceImpl.resolveDrawScope(List.of("enterprise", "platform", "platform")));
    }

    @Test
    void rejectsEmptyOrUnknownBank()
    {
        assertThrows(ServiceException.class, () -> ExamServiceImpl.resolveDrawScope(List.of()));
        assertThrows(ServiceException.class, () -> ExamServiceImpl.resolveDrawScope("unknown"));
    }
}
