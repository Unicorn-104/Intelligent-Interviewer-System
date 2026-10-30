package com.ruoyi.system.service.impl;

import java.util.List;
import java.util.Map;
import java.util.stream.LongStream;
import jakarta.validation.Validation;
import org.junit.jupiter.api.Test;
import org.springframework.beans.MutablePropertyValues;
import org.springframework.format.support.DefaultFormattingConversionService;
import org.springframework.validation.DataBinder;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import static org.junit.jupiter.api.Assertions.*;

class AgentJobQueryTest
{
    @Test
    void bindsCommaSeparatedSavedIdsAsLongValues()
    {
        AgentJobQuery query = new AgentJobQuery();
        DataBinder binder = new DataBinder(query);
        binder.setConversionService(new DefaultFormattingConversionService());
        binder.bind(new MutablePropertyValues(Map.of("jobIds", "1,2,999")));
        assertFalse(binder.getBindingResult().hasErrors());
        assertEquals(List.of(1L, 2L, 999L), query.getJobIds());
    }

    @Test
    void rejectsInvalidIdsAndUnboundedBatches()
    {
        try (var factory = Validation.buildDefaultValidatorFactory())
        {
            AgentJobQuery query = new AgentJobQuery();
            query.setJobIds(List.of(0L, -1L));
            assertEquals(2, factory.getValidator().validate(query).size());
            query.setJobIds(LongStream.rangeClosed(1, 201).boxed().toList());
            assertFalse(factory.getValidator().validate(query).isEmpty());
            query.setJobIds(List.of(1L, 2L));
            assertTrue(factory.getValidator().validate(query).isEmpty());
        }
    }
}
