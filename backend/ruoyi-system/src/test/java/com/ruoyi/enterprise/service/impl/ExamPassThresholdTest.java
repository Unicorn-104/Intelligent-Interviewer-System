package com.ruoyi.enterprise.service.impl;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import com.ruoyi.common.exception.ServiceException;

class ExamPassThresholdTest
{
    @Test
    void convertsPercentageAgainstDifferentPaperTotals()
    {
        assertEquals(new BigDecimal("70.00"),
                ExamServiceImpl.resolvePassThreshold(new BigDecimal("100"), null, new BigDecimal("70")));
        assertEquals(new BigDecimal("65.80"),
                ExamServiceImpl.resolvePassThreshold(new BigDecimal("94"), null, new BigDecimal("70")));
        assertEquals(new BigDecimal("105.00"),
                ExamServiceImpl.resolvePassThreshold(new BigDecimal("150"), null, new BigDecimal("70")));
    }

    @Test
    void keepsAbsoluteThresholdForLegacyClients()
    {
        assertEquals(new BigDecimal("72.5"),
                ExamServiceImpl.resolvePassThreshold(new BigDecimal("100"), new BigDecimal("72.5"), null));
    }

    @Test
    void rejectsPercentageOutsideOneToHundred()
    {
        assertThrows(ServiceException.class,
                () -> ExamServiceImpl.resolvePassThreshold(new BigDecimal("100"), null, new BigDecimal("0")));
        assertThrows(ServiceException.class,
                () -> ExamServiceImpl.resolvePassThreshold(new BigDecimal("100"), null, new BigDecimal("101")));
    }

    @Test
    void rejectsThresholdAbovePaperTotal()
    {
        assertThrows(ServiceException.class,
                () -> ExamServiceImpl.resolvePassThreshold(new BigDecimal("30"), new BigDecimal("31"), null));
    }
}
