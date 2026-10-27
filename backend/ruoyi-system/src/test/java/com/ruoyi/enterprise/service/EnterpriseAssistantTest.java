package com.ruoyi.enterprise.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.nio.charset.StandardCharsets;
import java.sql.Timestamp;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Consumer;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.EnterpriseAssistantMapper;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.service.app.ai.AgentModelClient;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

/** Synthetic H2 data only. Does not connect to production or a real model. */
public class EnterpriseAssistantTest
{
    private static final String REQUEST = "a".repeat(24);
    private final ObjectMapper json = new ObjectMapper();
    private JdbcTemplate db;
    private EnterpriseAssistantMapper mapper;
    private DashboardMapper companies;
    private AgentModelClient model;
    private EnterpriseAssistantService service;

    public static String dateFormat(Timestamp value, String ignored)
    {
        return value.toLocalDateTime().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
    }

    @BeforeEach void setup() throws Exception
    {
        var ds = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
            + ";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1", "sa", "");
        db = new JdbcTemplate(ds);
        db.execute("create alias date_format for 'com.ruoyi.enterprise.service.EnterpriseAssistantTest.dateFormat'");
        db.execute("create table t_ai_chat_session(acs_id bigint auto_increment primary key,acs_user_id bigint not null,acs_status tinyint,acs_started_at timestamp default current_timestamp,acs_ended_at timestamp,acs_updated_at timestamp default current_timestamp)");
        db.execute("create table t_ai_chat_message(acm_id bigint auto_increment primary key,acm_session_id bigint not null references t_ai_chat_session(acs_id),acm_role tinyint not null,acm_content text not null,acm_intent varchar(30),acm_created_at timestamp default current_timestamp)");
        db.execute("create table t_pos(pos_id bigint primary key,pos_company_id bigint,pos_title varchar(100),pos_work_city varchar(50),pos_status int,pos_salary_min int,pos_salary_max int,pos_experience_required int,pos_education_required int,pos_jd_json text)");
        db.execute("insert into t_pos values(11,81,'合成研发岗位','合成城市',1,8000,12000,1,3,'脱敏合成JD'),(12,82,'其他企业岗位','合成城市',1,9000,15000,2,4,'不可读取')");
        String xml = new String(new ClassPathResource("mapper/enterprise/EnterpriseAssistantMapper.xml")
            .getInputStream().readAllBytes(), StandardCharsets.UTF_8)
            .replace("date_sub(current_timestamp,interval 150 second)", "dateadd('SECOND',-150,current_timestamp)");
        var factory = new SqlSessionFactoryBean();
        factory.setDataSource(ds);
        factory.setMapperLocations(new ByteArrayResource(xml.getBytes(StandardCharsets.UTF_8)));
        mapper = new SqlSessionTemplate(factory.getObject()).getMapper(EnterpriseAssistantMapper.class);
        companies = mock(DashboardMapper.class);
        when(companies.selectCompanyIdByUser(101L)).thenReturn(81L);
        when(companies.selectCompanyIdByUser(102L)).thenReturn(82L);
        model = mock(AgentModelClient.class);
        when(model.resolve()).thenReturn(new ModelProvider());
        doAnswer(invocation -> {
            Consumer<String> delta = invocation.getArgument(3);
            delta.accept("合成回答");
            return new AgentModelClient.Reply(json.readTree("{\"role\":\"assistant\",\"content\":\"合成回答\"}"), 1);
        }).when(model).complete(any(), any(), any(), any(), anyLong());
        service = new EnterpriseAssistantService(mapper, companies, model, new DataSourceTransactionManager(ds));
    }

    @AfterEach void close() { if (service != null) service.close(); }
    private long create(long user) { return ((Number) service.create(user).get("id")).longValue(); }
    private int count(String table) { return db.queryForObject("select count(*) from " + table, Integer.class); }
    private void completed(long run) throws Exception
    {
        long end = System.nanoTime() + TimeUnit.SECONDS.toNanos(4);
        while (System.nanoTime() < end) {
            if (!"R".equals(service.run(101L, run).get("state"))) return;
            Thread.sleep(10);
        }
        fail("Synthetic model run did not finish");
    }

    @Test void openingHistoryDoesNotCreateSessionsAndCreationAddsScopedMarker()
    {
        assertEquals(List.of(), service.sessions(101L, null).get("items"));
        assertEquals(0, count("t_ai_chat_session"));
        long id = create(101L);
        assertEquals(1, count("t_ai_chat_session"));
        assertEquals("enterprise:81", db.queryForObject("select acm_intent from t_ai_chat_message where acm_session_id=?", String.class, id));
        assertEquals(7, db.queryForObject("select acs_status from t_ai_chat_session where acs_id=?", Integer.class, id));
        verifyNoInteractions(model);
    }

    @Test void ownerAndCompanyAreBothRequiredAndCandidateSessionsAreExcluded()
    {
        long id = create(101L);
        assertThrows(ServiceException.class, () -> service.messages(102L, id, null));
        assertThrows(ServiceException.class, () -> service.delete(102L, id));
        when(companies.selectCompanyIdByUser(101L)).thenReturn(82L);
        assertThrows(ServiceException.class, () -> service.messages(101L, id, null));
        when(companies.selectCompanyIdByUser(101L)).thenReturn(81L);
        db.update("insert into t_ai_chat_session(acs_user_id,acs_status) values(101,1),(101,7)");
        assertEquals(1, ((List<?>) service.sessions(101L, null).get("items")).size());
        assertThrows(ServiceException.class, () -> service.create(999L));
    }

    @Test void messagesPersistAndDuplicateRequestIsIdempotent() throws Exception
    {
        long session = create(101L);
        var first = service.start(101L, session, REQUEST, "合成问题");
        long run = ((Number) first.get("id")).longValue();
        completed(run);
        var second = service.start(101L, session, REQUEST, "合成问题");
        assertEquals(first.get("id"), second.get("id"));
        assertEquals("C", second.get("state"));
        assertEquals("合成回答", second.get("content"));
        assertEquals(3, count("t_ai_chat_message")); // marker, question, answer
        assertEquals(true, service.request(101L, session, REQUEST).get("found"));
        assertEquals(false, service.request(101L, session, "b".repeat(24)).get("found"));
        assertThrows(ServiceException.class, () -> service.start(101L, session, REQUEST, "不同内容"));
        verify(model, times(1)).complete(any(), any(), any(), any(), anyLong());
        assertThrows(ServiceException.class, () -> service.run(102L, run));
        assertThrows(ServiceException.class, () -> service.cancel(102L, run));
    }

    @Test void invalidInputAndUnboundUserNeverReachModelOrWriteMessages()
    {
        long session = create(101L);
        for (String input : List.of(" ", "x".repeat(4001), "bad\u0000input"))
            assertThrows(ServiceException.class, () -> service.start(101L, session, REQUEST, input));
        assertThrows(ServiceException.class, () -> service.start(101L, session, "invalid", "合成"));
        assertThrows(ServiceException.class, () -> service.sessions(101L, 0L));
        assertEquals(1, count("t_ai_chat_message"));
        verifyNoInteractions(model);
    }

    @Test void cancellationIsTerminalAndPreventsConcurrentRunsOrDelete() throws Exception
    {
        var entered = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        doAnswer(invocation -> {
            Consumer<String> delta = invocation.getArgument(3);
            delta.accept("已生成部分"); entered.countDown(); release.await(3, TimeUnit.SECONDS);
            return new AgentModelClient.Reply(json.readTree("{\"role\":\"assistant\",\"content\":\"结束\"}"), 1);
        }).when(model).complete(any(), any(), any(), any(), anyLong());
        long session = create(101L);
        long run = ((Number) service.start(101L, session, REQUEST, "合成问题").get("id")).longValue();
        assertTrue(entered.await(2, TimeUnit.SECONDS));
        assertEquals(run, ((Number) service.start(101L, session, REQUEST, "合成问题").get("id")).longValue());
        assertThrows(ServiceException.class, () -> service.start(101L, session, "b".repeat(24), "并发问题"));
        assertThrows(ServiceException.class, () -> service.delete(101L, session));
        assertEquals("X", service.cancel(101L, run).get("state"));
        release.countDown();
        assertEquals("X", service.cancel(101L, run).get("state"));
        assertEquals("已生成部分", service.run(101L, run).get("content"));
        service.delete(101L, session);
        assertEquals(0, count("t_ai_chat_message"));
        assertEquals(0, count("t_ai_chat_session"));
    }

    @Test void failedReservationReleasesOnlyItsOwnUserToken() throws Exception
    {
        long session = create(101L);
        db.update("insert into t_ai_chat_message(acm_session_id,acm_role,acm_content,acm_intent) values(?,2,'','r:999:R')", session);
        assertThrows(ServiceException.class, () -> service.start(101L, session, REQUEST, "合成问题"));
        db.update("update t_ai_chat_message set acm_created_at=dateadd('SECOND',-200,current_timestamp) where acm_role=2");
        long run = ((Number) service.start(101L, session, REQUEST, "合成问题").get("id")).longValue();
        completed(run);
        assertEquals("C", service.run(101L, run).get("state"));
    }

    @Test void modelToolsReadOnlyCurrentCompanyJobs() throws Exception
    {
        AtomicInteger calls = new AtomicInteger();
        doAnswer(invocation -> {
            ArrayNode context = invocation.getArgument(1);
            if (calls.getAndIncrement() == 0) {
                assertFalse(context.toString().contains("不可读取"));
                return new AgentModelClient.Reply(json.readTree("{\"role\":\"assistant\",\"content\":null,\"tool_calls\":[{\"id\":\"call1\",\"type\":\"function\",\"function\":{\"name\":\"list_company_jobs\",\"arguments\":\"{}\"}},{\"id\":\"call2\",\"type\":\"function\",\"function\":{\"name\":\"get_company_job\",\"arguments\":\"{\\\"id\\\":12}\"}}]}"), 1);
            }
            assertTrue(context.toString().contains("合成研发岗位"));
            assertFalse(context.toString().contains("其他企业岗位"));
            assertTrue(context.toString().contains("岗位不存在或不属于当前企业"));
            Consumer<String> delta = invocation.getArgument(3); delta.accept("合成岗位建议");
            return new AgentModelClient.Reply(json.readTree("{\"role\":\"assistant\",\"content\":\"合成岗位建议\"}"), 1);
        }).when(model).complete(any(), any(), any(), any(), anyLong());
        long session = create(101L);
        long run = ((Number) service.start(101L, session, REQUEST, "核对合成岗位").get("id")).longValue();
        completed(run);
        assertEquals("C", service.run(101L, run).get("state"));
        assertEquals(2, count("t_pos"));
    }

    @Test void sessionAndMessageCursorsHaveBoundedStablePages()
    {
        long session = 0;
        for (int i=0; i<22; i++) session=create(101L);
        var page=service.sessions(101L,null);
        assertEquals(20, ((List<?>) page.get("items")).size());
        assertEquals(2, ((List<?>) service.sessions(101L, ((Number) page.get("nextCursor")).longValue()).get("items")).size());
        for (int i=0;i<42;i++) db.update("insert into t_ai_chat_message(acm_session_id,acm_role,acm_content) values(?,1,?)",session,"合成问题"+i);
        var messages=service.messages(101L,session,null);
        assertEquals(40, ((List<?>) messages.get("items")).size());
        assertEquals(2, ((List<?>) service.messages(101L,session,((Number)messages.get("nextCursor")).longValue()).get("items")).size());
    }
    @RestController
    public static class SyntheticStreamEndpoint
    {
        private final EnterpriseAssistantService service;
        SyntheticStreamEndpoint(EnterpriseAssistantService service) { this.service = service; }
        @GetMapping(value="/synthetic/stream/{id}", produces="text/event-stream;charset=UTF-8")
        public SseEmitter events(@PathVariable Long id) { return service.events(101L, id); }
    }

    @Test void sseDeliversPartialTextBeforeGenerationFinishesAndClosesAtTerminal() throws Exception
    {
        var entered = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        doAnswer(invocation -> {
            Consumer<String> delta = invocation.getArgument(3);
            delta.accept("第一段合成文本");
            entered.countDown();
            if (!release.await(5, TimeUnit.SECONDS)) throw new IllegalStateException("synthetic timeout");
            delta.accept("，随后生成第二段");
            return new AgentModelClient.Reply(json.readTree("{\"role\":\"assistant\",\"content\":\"合成完整回答\"}"), 1);
        }).when(model).complete(any(),any(),any(),any(),anyLong());
        long session = create(101L);
        long run = ((Number)service.start(101L,session,REQUEST,"合成流式问题").get("id")).longValue();
        assertTrue(entered.await(2,TimeUnit.SECONDS));
        assertThrows(ServiceException.class, () -> service.events(102L,run));
        var mvc = MockMvcBuilders.standaloneSetup(new SyntheticStreamEndpoint(service)).build();
        var result = mvc.perform(get("/synthetic/stream/"+run)).andExpect(request().asyncStarted()).andReturn();
        try
        {
            long deadline = System.nanoTime()+TimeUnit.SECONDS.toNanos(2);
            while(!new String(result.getResponse().getContentAsByteArray(), StandardCharsets.UTF_8).contains("第一段合成文本") && System.nanoTime()<deadline)
                Thread.sleep(10);
            assertTrue(new String(result.getResponse().getContentAsByteArray(), StandardCharsets.UTF_8).contains("第一段合成文本"), "Synthetic SSE: " + new String(result.getResponse().getContentAsByteArray(), StandardCharsets.UTF_8));
            assertEquals("R",service.run(101L,run).get("state"));
        }
        finally { release.countDown(); }
        result.getAsyncResult(4000);
        mvc.perform(asyncDispatch(result)).andExpect(status().isOk()).andExpect(content().contentTypeCompatibleWith("text/event-stream"));
        String wire=new String(result.getResponse().getContentAsByteArray(), StandardCharsets.UTF_8);
        assertTrue(wire.contains("event:run"));
        assertTrue(wire.contains("第一段合成文本，随后生成第二段"));
        assertTrue(wire.contains("\"state\":\"C\""));
        verify(model,times(1)).complete(any(),any(),any(),any(),anyLong());
    }

    @Test void sseCanRestoreCompletedAnswerWithoutCallingModelAgain() throws Exception
    {
        long session=create(101L);
        long run=((Number)service.start(101L,session,REQUEST,"合成已完成问题").get("id")).longValue();
        completed(run);
        var mvc=MockMvcBuilders.standaloneSetup(new SyntheticStreamEndpoint(service)).build();
        var result=mvc.perform(get("/synthetic/stream/"+run)).andExpect(request().asyncStarted()).andReturn();
        result.getAsyncResult(3000);
        mvc.perform(asyncDispatch(result)).andExpect(status().isOk());
        assertTrue(new String(result.getResponse().getContentAsByteArray(), StandardCharsets.UTF_8).contains("合成回答"), "Synthetic SSE: " + new String(result.getResponse().getContentAsByteArray(), StandardCharsets.UTF_8));
        assertTrue(new String(result.getResponse().getContentAsByteArray(), StandardCharsets.UTF_8).contains("\"state\":\"C\""));
        verify(model,times(1)).complete(any(),any(),any(),any(),anyLong());
    }

}
