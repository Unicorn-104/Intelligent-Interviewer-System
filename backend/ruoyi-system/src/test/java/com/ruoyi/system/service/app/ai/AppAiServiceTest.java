package com.ruoyi.system.service.app.ai;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.domain.app.ai.AgentRunRequest;
import com.ruoyi.system.mapper.app.AppAiMapper;
import com.ruoyi.system.mapper.app.AppAiMemoryMapper;
import org.apache.ibatis.builder.xml.XMLMapperBuilder;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.Configuration;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;
import org.mybatis.spring.SqlSessionTemplate;
import org.mybatis.spring.transaction.SpringManagedTransactionFactory;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.init.ScriptUtils;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class AppAiServiceTest
{
    private final AgentTools tools = mock(AgentTools.class);
    private final AgentModelClient model = mock(AgentModelClient.class);
    private final ObjectMapper json = new ObjectMapper();
    private AppAiService service;
    private AppAiMapper mapper;
    private AppAiMemoryMapper memories;
    private AppAiMemoryService memory;

    @BeforeEach
    void setup() throws Exception
    {
        var source = new UnpooledDataSource("org.h2.Driver", "jdbc:h2:mem:" + java.util.UUID.randomUUID()
                + ";MODE=MySQL;DATABASE_TO_UPPER=FALSE;DB_CLOSE_DELAY=-1", "sa", "");
        try (var connection = source.getConnection())
        {
            var migration = new org.springframework.core.io.FileSystemResource("../doc/migration_capp_ai_agent_20261020.sql");
            ScriptUtils.executeSqlScript(connection, migration);
            ScriptUtils.executeSqlScript(connection, migration);
            var memoryMigration = new org.springframework.core.io.FileSystemResource("../doc/migration_capp_ai_memory_20261021.sql");
            ScriptUtils.executeSqlScript(connection, memoryMigration);
            ScriptUtils.executeSqlScript(connection, memoryMigration);
            try (var statement = connection.createStatement())
            {
                statement.execute("ALTER TABLE t_capp_ai_session ADD COLUMN pinned TINYINT NOT NULL DEFAULT 0");
                statement.execute("ALTER TABLE t_capp_ai_run ADD COLUMN application_id BIGINT NULL");
                statement.execute("ALTER TABLE t_capp_ai_run ADD COLUMN task_type VARCHAR(32) NOT NULL DEFAULT 'chat'");
            }
        }
        Configuration config = new Configuration(new Environment("test", new SpringManagedTransactionFactory(), source));
        String resource = "mapper/app/AppAiMapper.xml";
        try (InputStream xml = getClass().getClassLoader().getResourceAsStream(resource))
        { new XMLMapperBuilder(xml, config, resource, config.getSqlFragments()).parse(); }
        String memoryResource = "mapper/app/AppAiMemoryMapper.xml";
        try (InputStream xml = getClass().getClassLoader().getResourceAsStream(memoryResource))
        { new XMLMapperBuilder(xml, config, memoryResource, config.getSqlFragments()).parse(); }
        SqlSessionFactory factory = new SqlSessionFactoryBuilder().build(config);
        mapper = new SqlSessionTemplate(factory).getMapper(AppAiMapper.class);
        memories = new SqlSessionTemplate(factory).getMapper(AppAiMemoryMapper.class);
        var manager = new DataSourceTransactionManager(source);
        memory = new AppAiMemoryService(memories, mapper, model, manager);
        service = new AppAiService(mapper, tools, model, manager, memory);
        when(model.resolve()).thenReturn(new ModelProvider());
        when(tools.definitions()).thenReturn(json.createArrayNode());
        when(tools.refreshCards(anyLong(), anySet())).thenReturn(List.of());
        when(tools.selectedContext(anyLong(), any(), any(), anyString())).thenAnswer(inv -> {
            var action = inv.<String>getArgument(3);
            var resume = inv.<Long>getArgument(1);
            return AgentTools.fields("action", action, "resumeId", resume);
        });
        when(model.complete(any(), any(), any(), any(), anyLong())).thenAnswer(invocation -> {
            invocation.<Consumer<String>>getArgument(3).accept("synthetic answer");
            return reply("{\"role\":\"assistant\",\"content\":\"synthetic answer\"}");
        });
    }

    @AfterEach
    void cleanup() { if (service != null) service.close(); }

    private AgentModelClient.Reply reply(String message) throws Exception
    { return new AgentModelClient.Reply(json.readTree(message), 20); }
    private String session() { return service.createSession(17L).get("id").toString(); }
    private AgentRunRequest request(String id) { return new AgentRunRequest(id, "synthetic question", null); }
    private Map<String, Object> await(String runId) throws Exception
    {
        for (int i = 0; i < 100; i++)
        {
            var run = service.run(17L, runId);
            if (!"RUNNING".equals(run.get("status"))) return run;
            Thread.sleep(20);
        }
        throw new AssertionError("run did not finish");
    }

    @Test
    void historyReturnsExplicitCreationDatesAndRenameIsOwnerScoped()
    {
        String id = session();
        var items = (List<Map<String, Object>>)service.sessions(17L, null).get("items");
        assertNotNull(java.time.Instant.parse(items.get(0).get("createdAt").toString()));
        assertEquals("synthetic title", service.rename(17L, id, " synthetic title ").get("title"));
        assertThrows(ServiceException.class, () -> service.rename(18L, id, "foreign title"));
        assertThrows(ServiceException.class, () -> service.rename(17L, id, " "));
        assertThrows(ServiceException.class, () -> service.rename(17L, id, "x".repeat(81)));
        assertEquals("synthetic title", mapper.session(id, 17L).get("title"));
        assertEquals(0, mapper.rename(id, 18L, "foreign title"));
    }

    @Test
    void historyActionsPersistAndDeleteOwnedConversationData()
    {
        String id = session();
        assertEquals(true, service.pin(17L, id, true).get("pinned"));
        assertEquals(1, ((Number)mapper.session(id, 17L).get("pinned")).intValue());
        assertThrows(ServiceException.class, () -> service.pin(18L, id, false));
        assertThrows(ServiceException.class, () -> service.delete(18L, id));
        service.delete(17L, id);
        assertNull(mapper.session(id, 17L));
        assertThrows(ServiceException.class, () -> service.deleteBatch(17L, List.of()));
    }

    @Test
    void handshakeFailureReturnsConnectionErrorWithoutSavingAnAnswer() throws Exception
    {
        doThrow(new javax.net.ssl.SSLHandshakeException("synthetic handshake failure"))
                .when(model).complete(any(), any(), any(), any(), anyLong());
        String id = session();
        String runId = service.start(17L, id, request("request-0000000001")).get("id").toString();
        var failed = await(runId);
        assertEquals("FAILED", failed.get("status"));
        assertEquals("CONNECTION_FAILED", failed.get("errorCode"));
        assertNull(mapper.session(id, 17L).get("activeRunId"));
        assertEquals(1, ((List<?>)service.messages(17L, id, null).get("items")).size());
        verify(model, times(2)).complete(any(), any(), any(), any(), anyLong());
        var events = mapper.events(runId, 17L, 0);
        assertTrue(events.get(events.size() - 1).get("data").toString().contains("CONNECTION_FAILED"));
    }

    @Test
    void modelTimeoutReturnsTimeoutRatherThanGenericUnavailable() throws Exception
    {
        doThrow(new java.net.http.HttpTimeoutException("synthetic timeout"))
                .when(model).complete(any(), any(), any(), any(), anyLong());
        String runId = service.start(17L, session(), request("request-0000000001")).get("id").toString();
        assertEquals("TIMEOUT", await(runId).get("errorCode"));
    }

    @Test
    void persistsLongAnswerBeyondPreviousCharacterLimit() throws Exception
    {
        String content = "模拟简历优势不足与修改建议".repeat(1600);
        doAnswer(invocation -> {
            invocation.<Consumer<String>>getArgument(3).accept(content);
            return new AgentModelClient.Reply(json.createObjectNode().put("role", "assistant")
                    .put("content", content), 8192);
        }).when(model).complete(any(), any(), any(), any(), anyLong());
        String id = session();
        String runId = service.start(17L, id, request("request-0000000001")).get("id").toString();
        assertEquals("COMPLETED", await(runId).get("status"));
        var messages = (List<Map<String, Object>>)service.messages(17L, id, null).get("items");
        assertEquals(content, messages.get(messages.size() - 1).get("content"));
    }

    @Test
    void outputLimitReturnsSpecificErrorWithoutRetryingOrSavingIncompleteAnswer() throws Exception
    {
        doAnswer(invocation -> {
            invocation.<Consumer<String>>getArgument(3).accept("模拟未完成回答");
            throw new AgentModelClient.OutputLimitException();
        }).when(model).complete(any(), any(), any(), any(), anyLong());
        String id = session();
        String runId = service.start(17L, id, request("request-0000000001")).get("id").toString();
        assertEquals("OUTPUT_LIMIT", await(runId).get("errorCode"));
        assertEquals(1, ((List<?>)service.messages(17L, id, null).get("items")).size());
        verify(model, times(1)).complete(any(), any(), any(), any(), anyLong());
    }

    @Test
    void connectionFailureAfterPartialOutputDoesNotRetryOrPersistPartialAnswer() throws Exception
    {
        doAnswer(inv -> {
            inv.<Consumer<String>>getArgument(3).accept("synthetic partial answer");
            throw new java.io.IOException("synthetic disconnect");
        }).when(model).complete(any(), any(), any(), any(), anyLong());
        String id = session();
        String runId = service.start(17L, id, request("request-0000000001")).get("id").toString();
        assertEquals("CONNECTION_FAILED", await(runId).get("errorCode"));
        verify(model, times(1)).complete(any(), any(), any(), any(), anyLong());
        assertEquals(1, ((List<?>)service.messages(17L, id, null).get("items")).size());
    }

    @Test
    void persistenceAndIdempotencyDoNotRepeatModelOrMessages() throws Exception
    {
        String id = session();
        var run = service.start(17L, id, request("request-0000000001"));
        String runId = run.get("id").toString();
        assertEquals("COMPLETED", await(runId).get("status"));
        assertEquals(runId, service.start(17L, id, request("request-0000000001")).get("id"));
        assertEquals(2, ((List<?>)service.messages(17L, id, null).get("items")).size());
        assertNull(mapper.session(id, 17L).get("activeRunId"));
        var events = mapper.events(runId, 17L, 0);
        assertEquals("done", events.get(events.size() - 1).get("type"));
        assertFalse(service.run(17L, runId).containsKey("inputText"));
        verify(model, times(1)).complete(any(), any(), any(), any(), anyLong());
    }

    @Test
    void privateSessionsMessagesRunsAndEventsAreOwnerScoped() throws Exception
    {
        String id = session();
        assertThrows(ServiceException.class, () -> service.messages(18L, id, null));
        assertThrows(ServiceException.class, () -> service.start(18L, id, request("request-0000000001")));
        String runId = service.start(17L, id, request("request-0000000001")).get("id").toString();
        await(runId);
        assertThrows(ServiceException.class, () -> service.run(18L, runId));
        assertThrows(ServiceException.class, () -> service.events(18L, runId, 0));
        assertThrows(ServiceException.class, () -> service.cancel(18L, runId));
        assertTrue(mapper.events(runId, 18L, 0).isEmpty());
        assertTrue(mapper.messages(id, 18L, null, 30).isEmpty());
        assertEquals(0, mapper.acquire(id, 18L, "foreign-run"));
    }

    @Test
    void loopsThroughModelSelectedToolAndFeedsItsResultBack() throws Exception
    {
        var counter = new java.util.concurrent.atomic.AtomicInteger();
        doAnswer(inv -> {
            if (counter.getAndIncrement() == 0)
                return reply("{\"role\":\"assistant\",\"content\":\"\",\"tool_calls\":[{\"id\":\"call1\",\"type\":\"function\",\"function\":{\"name\":\"list_resumes\",\"arguments\":\"{}\"}}]}");
            assertTrue(inv.getArgument(1).toString().contains("tool_call_id"));
            inv.<Consumer<String>>getArgument(3).accept("answer");
            return reply("{\"role\":\"assistant\",\"content\":\"answer\"}");
        }).when(model).complete(any(), any(), any(), any(), anyLong());
        when(tools.execute(eq(17L), isNull(), eq("list_resumes"), any())).thenReturn(List.of());
        String id = session();
        String runId = service.start(17L, id, request("request-0000000001")).get("id").toString();
        assertEquals("COMPLETED", await(runId).get("status"));
        verify(tools).execute(eq(17L), isNull(), eq("list_resumes"), any());
        assertEquals(2, ((Number)service.run(17L, runId).get("modelCalls")).intValue());
    }

    @Test
    void sixRoundLimitStopsRepeatedCallsAndReleasesSession() throws Exception
    {
        doReturn(reply(
                "{\"role\":\"assistant\",\"content\":\"\",\"tool_calls\":[{\"id\":\"call1\",\"function\":{\"name\":\"list_resumes\",\"arguments\":\"{}\"}}]}"))
                .when(model).complete(any(), any(), any(), any(), anyLong());
        String id = session();
        String runId = service.start(17L, id, request("request-0000000001")).get("id").toString();
        var done = await(runId);
        assertEquals("FAILED", done.get("status")); assertEquals("STEP_LIMIT", done.get("errorCode"));
        verify(model, times(6)).complete(any(), any(), any(), any(), anyLong());
        assertNull(mapper.session(id, 17L).get("activeRunId"));
    }

    @Test
    void cancelWinsAgainstLateModelCompletion() throws Exception
    {
        CountDownLatch started = new CountDownLatch(1), release = new CountDownLatch(1);
        doAnswer(inv -> {
            started.countDown(); release.await(3, TimeUnit.SECONDS);
            return reply("{\"role\":\"assistant\",\"content\":\"late\"}");
        }).when(model).complete(any(), any(), any(), any(), anyLong());
        String id = session();
        String runId = service.start(17L, id, request("request-0000000001")).get("id").toString();
        assertTrue(started.await(2, TimeUnit.SECONDS));
        assertThrows(ServiceException.class, () -> service.start(17L, id, request("request-0000000002")));
        service.cancel(17L, runId); release.countDown();
        assertEquals("CANCELLED", service.run(17L, runId).get("status"));
        assertEquals(1, ((List<?>)service.messages(17L, id, null).get("items")).size());
        assertNull(mapper.session(id, 17L).get("activeRunId"));
    }

    @Test
    void freeChatDoesNotPrefetchSelectedResume() throws Exception
    {
        String id = session();
        String runId = service.start(17L, id,
                new AgentRunRequest("request-0000000001", "Hello, explain recursion", 5L)).get("id").toString();
        assertEquals("COMPLETED", await(runId).get("status"));
        verify(tools, never()).execute(any(), any(), any(), any());
        var context = org.mockito.ArgumentCaptor.forClass(com.fasterxml.jackson.databind.node.ArrayNode.class);
        verify(model).complete(any(), context.capture(), any(), any(), anyLong());
        assertTrue(context.getValue().path(0).path("content").asText().contains("自由对话"));
    }

    @Test
    void interviewRunPersistsServerResolvedApplicationResumeAndAction() throws Exception
    {
        when(tools.selectedContext(17L, null, 91L, "interview_preparation"))
                .thenReturn(AgentTools.fields("action", "interview_preparation", "applicationId", 91L,
                        "resumeId", 7L, "job", Map.of("positionId", 42L, "title", "synthetic job")));
        String id = session();
        String runId = service.start(17L, id, new AgentRunRequest(
                "request-0000000001", "prepare for interview", null, 91L, "interview_preparation"))
                .get("id").toString();
        assertEquals("COMPLETED", await(runId).get("status"));
        var metadata = service.run(17L, runId);
        assertEquals(7L, ((Number)metadata.get("resumeId")).longValue());
        assertEquals(91L, ((Number)metadata.get("applicationId")).longValue());
        assertEquals("interview_preparation", metadata.get("action"));
        var context = org.mockito.ArgumentCaptor.forClass(com.fasterxml.jackson.databind.node.ArrayNode.class);
        verify(model).complete(any(), context.capture(), any(), any(), anyLong());
        assertTrue(context.getValue().toString().contains("synthetic job"));
        assertTrue(context.getValue().path(1).path("content").asText().contains("\"resumeId\":7"));
    }

    @Test
    void actionsRejectMissingPrerequisitesBeforePersistingMessages()
    {
        String id = session();
        for (String action : List.of("resume_analysis", "job_recommendation", "interview_preparation"))
            assertThrows(ServiceException.class, () -> service.start(17L, id,
                    new AgentRunRequest("request-0000000001", "synthetic question", null, null, action)));
        assertTrue(mapper.messages(id, 17L, null, 30).isEmpty());
        verify(model, never()).resolve();
    }

    @Test
    void newestQuestionSurvivesContextBudget() throws Exception
    {
        String id = session();
        for (int i = 0; i < 9; i++)
        {
            String old = "history-" + i;
            mapper.createRun(AgentTools.fields("id", old, "sessionId", id, "userId", 17L,
                    "requestId", old, "resumeId", null, "inputText", "old"));
            mapper.message(id, old, 17L, "user", "old-" + "x".repeat(3990), null);
            mapper.message(id, old, 17L, "assistant", "old-" + "y".repeat(3990), "[]");
            mapper.finish(old, 17L, "COMPLETED", null, 1, 0, 1);
        }
        doAnswer(inv -> {
            if (!inv.getArgument(1).toString().contains("将提供的旧摘要"))
                assertTrue(inv.getArgument(1).toString().contains("CURRENT_MARKER"));
            inv.<Consumer<String>>getArgument(3).accept("answer");
            return reply("{\"role\":\"assistant\",\"content\":\"answer\"}");
        }).when(model).complete(any(), any(), any(), any(), anyLong());
        String runId = service.start(17L, id,
                new AgentRunRequest("request-0000000001", "CURRENT_MARKER", null)).get("id").toString();
        assertEquals("COMPLETED", await(runId).get("status"));
    }

    @Test
    void missingProviderDoesNotPersistMessage() throws Exception
    {
        when(model.resolve()).thenThrow(new ServiceException("unavailable", 503));
        String id = session();
        assertThrows(ServiceException.class, () -> service.start(17L, id, request("request-0000000001")));
        assertTrue(((List<?>)service.messages(17L, id, null).get("items")).isEmpty());
    }

    @Test
    void confirmedPreferencesCrossSessionsButNeverCrossAccounts() throws Exception
    {
        memory.change(17L, new AppAiMemoryService.Change("save", "city", "SYNTHETIC_CITY", null, 0L));
        assertTrue(((List<?>)memory.read(18L).get("items")).isEmpty());
        String id = session();
        String runId = service.start(17L, id, request("request-0000000001")).get("id").toString();
        assertEquals("COMPLETED", await(runId).get("status"));
        var context = org.mockito.ArgumentCaptor.forClass(com.fasterxml.jackson.databind.node.ArrayNode.class);
        verify(model).complete(any(), context.capture(), any(), any(), anyLong());
        assertTrue(context.getValue().toString().contains("SYNTHETIC_CITY"));
        assertThrows(ServiceException.class, () -> memory.summary(18L, id));
        assertThrows(ServiceException.class, () -> memory.change(17L,
                new AppAiMemoryService.Change("save", "city", "another", null, 0L)));
    }

    @Test
    void forgettingFencesOldHistoryAndDeletesSummaries() throws Exception
    {
        String id = session();
        String runId = service.start(17L, id,
                new AgentRunRequest("request-0000000001", "FORGOTTEN_CITY", null)).get("id").toString();
        await(runId);
        memories.saveSummary(17L, id, "FORGOTTEN_CITY", 1, 0);
        memory.change(17L, new AppAiMemoryService.Change("save", "city", "FORGOTTEN_CITY", null, 0L));
        memory.change(17L, new AppAiMemoryService.Change("forget", "city", null, null, 1L));
        assertNull(memories.summary(17L, id));
        assertTrue(((List<?>)memory.read(17L).get("items")).isEmpty());
        clearInvocations(model);
        String next = service.start(17L, id, request("request-0000000002")).get("id").toString();
        assertEquals("COMPLETED", await(next).get("status"));
        var context = org.mockito.ArgumentCaptor.forClass(com.fasterxml.jackson.databind.node.ArrayNode.class);
        verify(model).complete(any(), context.capture(), any(), any(), anyLong());
        assertFalse(context.getValue().toString().contains("FORGOTTEN_CITY"));
        assertEquals(4, ((List<?>)service.messages(17L, id, null).get("items")).size());
    }

    @Test
    void activeRunMustBeStoppedBeforeMemoryChanges() throws Exception
    {
        CountDownLatch started = new CountDownLatch(1), release = new CountDownLatch(1);
        doAnswer(inv -> {
            started.countDown(); release.await(3, TimeUnit.SECONDS);
            return reply("{\"role\":\"assistant\",\"content\":\"late\"}");
        }).when(model).complete(any(), any(), any(), any(), anyLong());
        String runId = service.start(17L, session(), request("request-0000000001")).get("id").toString();
        assertTrue(started.await(2, TimeUnit.SECONDS));
        assertThrows(ServiceException.class, () -> memory.change(17L,
                new AppAiMemoryService.Change("clear", null, null, null, 0L)));
        service.cancel(17L, runId); release.countDown();
        memory.change(17L, new AppAiMemoryService.Change("clear", null, null, null, 0L));
        assertEquals(1L, ((Number)memory.read(17L).get("revision")).longValue());
    }

    @Test
    void memorySwitchPersistsAndDisabledMemoryIsExcludedFromContext() throws Exception
    {
        assertThrows(ServiceException.class, () -> memory.change(17L,
                new AppAiMemoryService.Change("save", "city", "fake@example.com", null, 0L)));
        memory.change(17L, new AppAiMemoryService.Change("save", "city", "SYNTHETIC_CITY", null, 0L));
        var settings = memory.change(17L,
                new AppAiMemoryService.Change("settings", null, null, false, 1L));
        assertEquals(false, settings.get("enabled"));
        assertFalse(settings.containsKey("items"));
        assertEquals(false, memory.read(17L).get("enabled"));
        assertEquals(false, memory.settings(17L).get("enabled"));
        String runId = service.start(17L, session(), request("request-0000000001")).get("id").toString();
        assertEquals("COMPLETED", await(runId).get("status"));
        var context = org.mockito.ArgumentCaptor.forClass(com.fasterxml.jackson.databind.node.ArrayNode.class);
        verify(model).complete(any(), context.capture(), any(), any(), anyLong());
        assertFalse(context.getValue().toString().contains("SYNTHETIC_CITY"));
        memory.change(17L, new AppAiMemoryService.Change("settings", null, null, true, 2L));
        assertEquals(true, memory.settings(17L).get("enabled"));
        assertThrows(ServiceException.class, () -> memory.change(17L,
                new AppAiMemoryService.Change("settings", null, null, false, 2L)));
    }

    @Test
    void longConversationGetsOwnerScopedRollingSummary() throws Exception
    {
        String id = session();
        seedSummaryHistory(id);
        String runId = service.start(17L, id, request("request-0000000001")).get("id").toString();
        assertEquals("COMPLETED", await(runId).get("status"));
        assertEquals("synthetic answer", memory.summary(17L, id).get("content"));
        assertEquals(2, ((Number)service.run(17L, runId).get("modelCalls")).intValue());
        assertEquals("", memory.summary(17L, session()).get("content"));
        memory.change(17L, new AppAiMemoryService.Change("reset_context", null, null, null, 0L));
        assertEquals("", memory.summary(17L, id).get("content"));
    }

    private void seedSummaryHistory(String id)
    {
        for (int i = 0; i < 8; i++)
        {
            String old = "summary-old-" + i;
            mapper.createRun(AgentTools.fields("id", old, "sessionId", id, "userId", 17L,
                    "requestId", old, "resumeId", null, "inputText", "synthetic history"));
            mapper.message(id, old, 17L, "user", "synthetic history", null);
            mapper.message(id, old, 17L, "assistant", "synthetic response", "[]");
            mapper.finish(old, 17L, "COMPLETED", null, 1, 0, 1);
        }
    }

    @Test
    void summaryFailureFallsBackToRecentConversation() throws Exception
    {
        String id = session();
        seedSummaryHistory(id);
        doAnswer(inv -> {
            if (inv.getArgument(1).toString().contains("将提供的旧摘要")) throw new java.io.IOException("synthetic timeout");
            assertTrue(inv.getArgument(1).toString().contains("synthetic question"));
            inv.<Consumer<String>>getArgument(3).accept("answer");
            return reply("{\"role\":\"assistant\",\"content\":\"answer\"}");
        }).when(model).complete(any(), any(), any(), any(), anyLong());
        String runId = service.start(17L, id, request("request-0000000001")).get("id").toString();
        assertEquals("COMPLETED", await(runId).get("status"));
        assertEquals("", memory.summary(17L, id).get("content"));
        assertEquals(2, ((Number)service.run(17L, runId).get("modelCalls")).intValue());
    }

    @Test
    void lateSummaryCannotResurrectMemoryAfterCancelAndClear() throws Exception
    {
        String id = session();
        seedSummaryHistory(id);
        String runId = "synthetic-summary-run";
        mapper.createRun(AgentTools.fields("id", runId, "sessionId", id, "userId", 17L,
                "requestId", runId, "resumeId", null, "inputText", "synthetic question"));
        doAnswer(inv -> {
            mapper.finish(runId, 17L, "CANCELLED", null, 0, 0, 0);
            memory.change(17L, new AppAiMemoryService.Change("clear", null, null, null, 0L));
            return reply("{\"role\":\"assistant\",\"content\":\"late private summary\"}");
        }).when(model).complete(any(), any(), any(), any(), anyLong());
        memory.prepare(17L, id, runId, new ModelProvider(), System.nanoTime() + TimeUnit.SECONDS.toNanos(20));
        assertEquals("", memory.summary(17L, id).get("content"));
        assertNull(memories.summary(17L, id));
    }
}
