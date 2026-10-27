package com.ruoyi.system.service.app.ai;

import java.util.Map;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.system.config.AppAiMemoryVectorProperties;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.mapper.app.AppAiMemoryMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;
import static com.ruoyi.system.service.app.ai.AgentTools.fields;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class AppAiLongTermMemoryServiceTest
{
    private final AppAiMemoryMapper mapper = mock(AppAiMemoryMapper.class);
    private final AgentModelClient model = mock(AgentModelClient.class);
    private final QdrantMemoryIndex index = mock(QdrantMemoryIndex.class);
    private AppAiLongTermMemoryService service;

    @BeforeEach
    void setup()
    {
        var manager = mock(PlatformTransactionManager.class);
        when(manager.getTransaction(any())).thenAnswer(call -> new SimpleTransactionStatus());
        service = new AppAiLongTermMemoryService(mapper, model, index, new AppAiMemoryVectorProperties(), manager);
        when(mapper.nextExtractionJob()).thenReturn(fields("runId", "synthetic-run", "userId", 17L,
                "sessionId", "synthetic-session", "attempts", 0));
        when(mapper.claimExtractionJob("synthetic-run")).thenReturn(1);
        when(mapper.extractionSource("synthetic-run", 17L)).thenReturn(source());
        when(mapper.lock(17L)).thenReturn(fields("enabled", 1, "revision", 0, "fence", 0L));
        when(mapper.findDuplicate(eq(17L), anyString())).thenReturn(null);
        when(mapper.nextVectorJob()).thenReturn(null);
        when(model.resolve()).thenReturn(new ModelProvider());
    }

    private Map<String, Object> source()
    { return fields("content", "我喜欢喝可乐", "sessionId", "synthetic-session", "messageId", 51L); }

    private void candidate(String evidence, String content) throws Exception
    {
        var json = new ObjectMapper();
        var result = json.createObjectNode();
        result.putArray("memories").addObject().put("memoryType", "arbitrary-model-type")
                .put("operation", "ADD").put("evidence", evidence).put("content", content);
        when(model.complete(any(), any(), any(), any(), anyLong(), anyInt()))
                .thenReturn(new AgentModelClient.Reply(json.createObjectNode().put("content", result.toString()), 12));
    }

    @Test
    void evidencedStablePreferenceIsStoredAsFactWithEvidenceAndVectorOutbox() throws Exception
    {
        candidate("我喜欢喝可乐", "用户喜欢喝可乐");
        service.processJobsSafely();
        verify(mapper).insertItem(argThat(item -> Long.valueOf(17).equals(item.get("userId"))
                && "fact".equals(item.get("memoryType")) && "用户喜欢喝可乐".equals(item.get("content"))));
        verify(mapper).addEvidence(argThat(item -> "我喜欢喝可乐".equals(item.get("evidence"))));
        verify(mapper).enqueueVector(anyString(), eq(17L), eq(1L), eq("UPSERT"));
        verify(mapper).completeExtractionJob("synthetic-run");
    }

    @Test
    void inventedEvidenceOrSensitiveContentCannotBecomeMemory() throws Exception
    {
        candidate("我是一名架构师", "用户是架构师");
        service.processJobsSafely();
        verify(mapper, never()).insertItem(anyMap());
        candidate("我喜欢喝可乐", "用户邮箱 synthetic@example.com");
        service.processJobsSafely();
        verify(mapper, never()).insertItem(anyMap());
        verify(mapper, never()).enqueueVector(anyString(), anyLong(), anyLong(), anyString());
    }

    @Test
    void duplicateFactOnlyAddsEvidence() throws Exception
    {
        candidate("我喜欢喝可乐", "用户喜欢喝可乐");
        when(mapper.findDuplicate(eq(17L), anyString())).thenReturn(fields("id", "synthetic-existing"));
        service.processJobsSafely();
        verify(mapper).addEvidence(argThat(item -> "synthetic-existing".equals(item.get("memoryId"))));
        verify(mapper, never()).insertItem(anyMap());
        verify(mapper, never()).enqueueVector(anyString(), anyLong(), anyLong(), anyString());
    }

    @Test
    void disablingMemoryPreventsNewExtractionAndRecall() throws Exception
    {
        when(mapper.state(17L)).thenReturn(fields("enabled", 0));
        service.enqueueExtraction(17L, "synthetic-session", "synthetic-run");
        assertTrue(service.recall(17L, "合成问题").isEmpty());
        verify(mapper, never()).enqueueExtraction(anyString(), anyLong(), anyString());
        verifyNoInteractions(index);
    }

    @Test
    void sourceFenceChangedDuringModelCallCannotStoreCandidate() throws Exception
    {
        candidate("我喜欢喝可乐", "用户喜欢喝可乐");
        when(mapper.extractionSource("synthetic-run", 17L)).thenReturn(source(), null);
        service.processJobsSafely();
        verify(mapper, never()).insertItem(anyMap());
    }
}
