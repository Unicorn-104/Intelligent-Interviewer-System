package com.ruoyi.web.controller.ai;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import com.github.pagehelper.PageHelper;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.service.IModelProviderService;

/** Synthetic rows only; the provider service is mocked, no database or model is used. */
class AiModelStatusStatsTest
{
    private final IModelProviderService service = mock(IModelProviderService.class);

    private MockMvc mvc;

    @BeforeEach
    void setup()
    {
        AiModelController controller = new AiModelController();
        ReflectionTestUtils.setField(controller, "modelProviderService", service);
        mvc = MockMvcBuilders.standaloneSetup(controller).build();
    }

    @AfterEach
    void cleanup()
    {
        PageHelper.clearPage();
    }

    @Test
    void statsTreatsStatusOneAsEnabled() throws Exception
    {
        when(service.selectModelProviderList(any()))
                .thenReturn(List.of(provider(1L, 1), provider(2L, 0), provider(3L, null)));

        mvc.perform(get("/ai/model/stats"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(3))
                .andExpect(jsonPath("$.data.enabled").value(1))
                .andExpect(jsonPath("$.data.disabled").value(2));
    }

    @Test
    void listFiltersByStatusParameter() throws Exception
    {
        when(service.selectModelProviderList(any()))
                .thenReturn(List.of(provider(1L, 1), provider(2L, 0)));

        mvc.perform(get("/ai/model/list").param("status", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rows.length()").value(1))
                .andExpect(jsonPath("$.rows[0].modelId").value(1));

        mvc.perform(get("/ai/model/list").param("status", "0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rows.length()").value(1))
                .andExpect(jsonPath("$.rows[0].modelId").value(2));
    }

    private ModelProvider provider(Long id, Integer status)
    {
        ModelProvider provider = new ModelProvider();
        provider.setMppId(id);
        provider.setMppName("synthetic-" + id);
        provider.setMppStatus(status);
        return provider;
    }
}
