package com.ruoyi.system.service.app.ai;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import java.util.List;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.service.IModelProviderService;
import org.junit.jupiter.api.Test;

/**
 * 场景化 Provider 解析：scene 匹配、缺省回退与异常配置的稳定性。
 */
class AgentModelResolveSceneTest
{
    private final IModelProviderService providers = mock(IModelProviderService.class);

    private final AgentModelClient client = new AgentModelClient(providers);

    private ModelProvider provider(Long id, Integer status, String key, String paramsJson)
    {
        ModelProvider provider = new ModelProvider();
        provider.setMppId(id);
        provider.setMppStatus(status);
        provider.setMppApiKey(key);
        provider.setMppParamsJson(paramsJson);
        provider.setMppModelName("model-" + id);
        return provider;
    }

    @Test
    void throwsWhenNoEnabledProvider()
    {
        when(providers.selectModelProviderList(any())).thenReturn(List.of());
        assertThrows(ServiceException.class, () -> client.resolve("screening"));
    }

    @Test
    void selectsScreeningSceneAndKeepsGeneralDefault()
    {
        when(providers.selectModelProviderList(any())).thenReturn(List.of(
                provider(9L, 1, "general-key", null),
                provider(8L, 1, "screening-key", "{\"scene\":\"screening\"}")));
        assertEquals(8L, client.resolve("screening").getMppId());
        assertEquals(9L, client.resolve().getMppId());
    }

    @Test
    void fallsBackToFirstWhenSceneMissing()
    {
        when(providers.selectModelProviderList(any())).thenReturn(List.of(
                provider(9L, 1, "general-key", null),
                provider(8L, 1, "report-key", "{\"scene\":\"report\"}")));
        assertEquals(9L, client.resolve("screening").getMppId());
    }

    @Test
    void fallsBackWhenSceneParamsIsInvalid()
    {
        when(providers.selectModelProviderList(any())).thenReturn(List.of(
                provider(9L, 1, "general-key", null),
                provider(8L, 1, "bad-key", "not-a-json")));
        assertEquals(9L, client.resolve("screening").getMppId());
    }

    @Test
    void ignoresDisabledOrKeylessSceneProvider()
    {
        when(providers.selectModelProviderList(any())).thenReturn(List.of(
                provider(9L, 1, "general-key", null),
                provider(8L, 0, "disabled-key", "{\"scene\":\"screening\"}"),
                provider(7L, 1, " ", "{\"scene\":\"screening\"}")));
        assertEquals(9L, client.resolve("screening").getMppId());
    }

    @Test
    void sceneMatchIgnoresCaseAndSpaces()
    {
        when(providers.selectModelProviderList(any())).thenReturn(List.of(
                provider(9L, 1, "general-key", null),
                provider(8L, 1, "screening-key", "{\"scene\":\" SCREENING \"}")));
        assertEquals(8L, client.resolve("screening").getMppId());
    }

    @Test
    void firstMatchedSceneProviderWins()
    {
        when(providers.selectModelProviderList(any())).thenReturn(List.of(
                provider(9L, 1, "screening-key-1", "{\"scene\":\"screening\"}"),
                provider(8L, 1, "screening-key-2", "{\"scene\":\"screening\"}")));
        assertEquals(9L, client.resolve("screening").getMppId());
    }
}
