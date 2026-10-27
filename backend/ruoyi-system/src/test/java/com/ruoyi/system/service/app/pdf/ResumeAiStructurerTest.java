package com.ruoyi.system.service.app.pdf;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.net.InetSocketAddress;
import java.util.concurrent.atomic.AtomicReference;
import java.util.concurrent.atomic.AtomicInteger;
import com.sun.net.httpserver.HttpServer;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.config.ResumeStructureProperties;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.service.app.impl.AppResumeServiceImpl;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class ResumeAiStructurerTest
{
    static final String SYNTHETIC_TEXT = """
        职业蓝图：Java后端研发
        求学足迹：2020年9月到2024年6月，示例大学，计算机专业，本科
        实践轨迹：2024年7月至今，示例科技公司，研发工程师，搭建订单服务
        解决问题的经历：示例订单项目，使用Java和SQL
        工具箱：Java、SQL
        其他积累：示例证书
        """;
    private static final String RESULT = """
        {"jobDirection":"Java后端研发",
         "educations":[{"school":"示例大学","major":"计算机","degree":3,"startDate":"2020-09-01","endDate":"2024-06-01","gpa":null,"description":null}],
         "works":[{"company":"示例科技公司","position":"研发工程师","department":null,"startDate":"2024-07-01","endDate":null,"current":true,"salaryRange":null,"description":"搭建订单服务"}],
         "projects":[{"name":"示例订单项目","role":null,"startDate":null,"endDate":null,"description":"使用Java和SQL","techStack":"Java,SQL"}],
         "skills":[{"name":"Java","level":null},{"name":"SQL","level":null}],
         "unmappedText":"其他积累：示例证书","warnings":["原文日期仅有年月，日补为01"]}
        """;
    private HttpServer server;
    private ResumeStructureProperties properties;
    private final ObjectMapper mapper = new ObjectMapper();
    private final AtomicReference<JsonNode> captured = new AtomicReference<>();
    private final AtomicReference<String> auth = new AtomicReference<>();
    private volatile int status;
    private volatile String response;
    private volatile int delay;
    private final AtomicInteger calls = new AtomicInteger();
    private volatile String firstResponse;

    @BeforeEach
    void setup() throws Exception
    {
        status = 200;
        delay = 0;
        response = completion(RESULT, "stop");
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/chat/completions", exchange -> {
            int call = calls.incrementAndGet();
            captured.set(mapper.readTree(exchange.getRequestBody().readAllBytes()));
            auth.set(exchange.getRequestHeaders().getFirst("Authorization"));
            if (delay > 0)
            {
                try { Thread.sleep(delay); } catch (InterruptedException error) { Thread.currentThread().interrupt(); }
            }
            byte[] body = (call == 1 && firstResponse != null ? firstResponse : response).getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
            try
            {
                exchange.sendResponseHeaders(status, body.length);
                exchange.getResponseBody().write(body);
            }
            finally { exchange.close(); }
        });
        server.start();
        properties = new ResumeStructureProperties();
        properties.setApiUrl("http://127.0.0.1:" + server.getAddress().getPort() + "/chat/completions");
        properties.setApiKey("synthetic-api-credential");
    }

    @AfterEach
    void close() { if (server != null) server.stop(0); }

    private String completion(String content, String reason) throws Exception
    {
        ObjectNode node = mapper.createObjectNode();
        ObjectNode choice = node.putArray("choices").addObject();
        choice.put("finish_reason", reason);
        choice.putObject("message").put("content", content);
        return mapper.writeValueAsString(node);
    }

    @Test
    void agentRepairsInvalidFirstResultAndAutofillsAllSections() throws Exception
    {
        firstResponse = completion("not JSON", "stop");
        AppResume draft = new ResumeAiStructurer(properties).structure(SYNTHETIC_TEXT);
        assertEquals(2, calls.get());
        assertEquals("示例大学", draft.getEducations().get(0).getSchool());
        assertEquals("示例科技公司", draft.getWorks().get(0).getCompany());
        assertEquals("示例订单项目", draft.getProjects().get(0).getName());
        assertEquals("assistant", captured.get().path("messages").path(2).path("role").asText());
        assertTrue(captured.get().path("messages").path(3).path("content").asText().contains("将已有内容填入对应数组"));
    }

    @Test
    void emptyFirstResultIsRecompiledInsteadOfReturningBlankForm() throws Exception
    {
        firstResponse = completion("{\"jobDirection\":null,\"educations\":[],\"works\":[],\"projects\":[],\"skills\":[],\"unmappedText\":null,\"warnings\":[]}", "stop");
        AppResume draft = new ResumeAiStructurer(properties).structure(SYNTHETIC_TEXT);
        assertEquals(2, calls.get());
        assertEquals(1, draft.getEducations().size());
        assertEquals(1, draft.getWorks().size());
        assertEquals(1, draft.getProjects().size());
    }

    @Test
    void mapsUnconventionalHeadingsToSchemaAndPreservesUnknowns() throws Exception
    {
        AppResume draft = new ResumeAiStructurer(properties).structure(SYNTHETIC_TEXT);
        assertEquals("AI", draft.getStructureMethod());
        assertEquals("示例大学", draft.getEducations().get(0).getSchool());
        assertEquals(LocalDate.of(2020, 9, 1), draft.getEducations().get(0).getStartDate());
        assertEquals("示例科技公司", draft.getWorks().get(0).getCompany());
        assertTrue(draft.getWorks().get(0).getCurrent());
        assertEquals("示例订单项目", draft.getProjects().get(0).getName());
        assertNull(draft.getSkills().get(0).getLevel());
        assertEquals("其他积累：示例证书", draft.getUnmappedText());
        assertEquals(1, draft.getParseWarnings().size());
        assertEquals("Bearer synthetic-api-credential", auth.get());
        assertEquals("deepseek-chat", captured.get().path("model").asText());
        assertEquals("json_object", captured.get().path("response_format").path("type").asText());
        assertFalse(captured.get().path("stream").asBoolean());
        assertTrue(captured.get().path("messages").path(1).path("content").asText().endsWith(SYNTHETIC_TEXT));
    }

    @Test
    void acceptsCommonTypesAndKeepsOtherSectionsWhenOneValueIsInvalid() throws Exception
    {
        for (String content : new String[] {
                RESULT.replace("\"jobDirection\"", "\"userId\":1,\"jobDirection\""),
                RESULT.replace("\"degree\":3", "\"degree\":99"),
                RESULT.replace("2020-09-01", "2020-13-01"),
                RESULT.replace("\"current\":true", "\"current\":\"true\""),
                RESULT.replace("\"level\":null", "\"level\":8"),
                RESULT.replace("\"degree\":3", "\"degree\":\"本科\"") })
        {
            response = completion(content, "stop");
            AppResume draft = new ResumeAiStructurer(properties).structure(SYNTHETIC_TEXT);
            assertEquals("示例大学", draft.getEducations().get(0).getSchool());
            assertEquals("示例科技公司", draft.getWorks().get(0).getCompany());
            assertEquals("示例订单项目", draft.getProjects().get(0).getName());
            assertNull(draft.getUserId());
            assertNull(draft.getResumeId());
            assertNull(draft.getFilePath());
        }
    }

    @Test
    void keepsCompleteJsonEvenIfProviderReportsLengthLimitButRefusesEmptyContent() throws Exception
    {
        response = completion(RESULT, "length");
        AppResume draft = new ResumeAiStructurer(properties).structure(SYNTHETIC_TEXT);
        assertEquals(1, draft.getEducations().size());
        assertTrue(draft.getParseWarnings().stream().anyMatch(warning -> warning.contains("长度限制")));
        response = completion("", "stop");
        assertThrows(ServiceException.class, () -> new ResumeAiStructurer(properties).structure(SYNTHETIC_TEXT));
    }

    @Test
    void mapsWrappedAliasFieldsChineseDatesAndStringEnumsDirectly() throws Exception
    {
        String content = """
            {"data":{"education":{"schoolName":"示例大学","major":"计算机","degree":"本科", "startDate":"2020年9月", "endDate":"2024/06", "gpa":"3.8/4.0"},
             "workExperience":[{"companyName":"示例科技公司","jobTitle":"研发工程师","start_date":"2024.7","end_date":"至今","current":"true"}],
             "projectExperience":{"projectName":"示例项目","technologies":["Java","SQL"]},
             "skillTags":["Java","SQL"],"warnings":"这是提示","userId":123,"filePath":"../../ignored.pdf"}}
            """;
        response = completion(content, "stop");
        AppResume draft = new ResumeAiStructurer(properties).structure(SYNTHETIC_TEXT);
        assertEquals(1, calls.get());
        assertEquals(Integer.valueOf(3), draft.getEducations().get(0).getDegree());
        assertEquals(LocalDate.of(2020, 9, 1), draft.getEducations().get(0).getStartDate());
        assertEquals(LocalDate.of(2024, 6, 1), draft.getEducations().get(0).getEndDate());
        assertEquals(new java.math.BigDecimal("3.80"), draft.getEducations().get(0).getGpa());
        assertTrue(draft.getWorks().get(0).getCurrent());
        assertNull(draft.getWorks().get(0).getEndDate());
        assertEquals("Java、SQL", draft.getProjects().get(0).getTechStack());
        assertEquals("Java", draft.getSkills().get(0).getName());
        assertNull(draft.getUserId());
        assertNull(draft.getFilePath());
    }

    @Test
    void acceptsExistingDatabaseTableAndColumnNames() throws Exception
    {
        response = completion("""
            {"rbs_job_direction":"后端研发","t_res_education":{"edu_school":"示例大学","edu_major":"计算机","edu_degree":"3","edu_start_date":"2020-9","edu_gpa":"3.5"},
             "t_res_work":{"wrk_company":"示例科技公司","wrk_position":"研发工程师","wrk_is_current":"1"},
             "t_res_project":{"prj_name":"示例项目","prj_tech_stack":"Java"},
             "t_res_skill":[{"skl_name":"Java","skl_level":"熟悉"}]}
            """, "stop");
        AppResume draft = new ResumeAiStructurer(properties).structure(SYNTHETIC_TEXT);
        assertEquals("后端研发", draft.getJobDirection());
        assertEquals("示例大学", draft.getEducations().get(0).getSchool());
        assertEquals(Integer.valueOf(3), draft.getEducations().get(0).getDegree());
        assertEquals("研发工程师", draft.getWorks().get(0).getPosition());
        assertEquals("示例项目", draft.getProjects().get(0).getName());
        assertEquals(Integer.valueOf(2), draft.getSkills().get(0).getLevel());
    }

    @Test
    void percentageScoreAndLongFieldDoNotDiscardValidExperiences() throws Exception
    {
        String longCompany = "示例公司".repeat(40);
        response = completion(RESULT.replace("\"gpa\":null", "\"gpa\":\"88/100\"")
                .replace("示例科技公司", longCompany), "stop");
        AppResume draft = new ResumeAiStructurer(properties).structure(SYNTHETIC_TEXT);
        assertEquals("示例大学", draft.getEducations().get(0).getSchool());
        assertNull(draft.getEducations().get(0).getGpa());
        assertTrue(draft.getEducations().get(0).getDescription().contains("88/100"));
        assertEquals(100, draft.getWorks().get(0).getCompany().length());
        assertTrue(draft.getUnmappedText().contains(longCompany));
        assertEquals(1, draft.getProjects().size());
    }

    @Test
    void authenticationFailureDoesNotExposeProviderBodyOrCredential()
    {
        status = 401;
        response = "provider error containing synthetic-api-credential and private user text";
        ServiceException error = assertThrows(ServiceException.class,
                () -> new ResumeAiStructurer(properties).structure(SYNTHETIC_TEXT));
        assertTrue(error.getMessage().contains("鉴权失败"));
        assertFalse(error.getMessage().contains("synthetic-api-credential"));
        assertFalse(error.getMessage().contains("private user text"));
    }

    @Test
    void refusesMissingCredentialAndOversizedInputWithoutCallingApi()
    {
        properties.setApiKey("");
        assertThrows(ServiceException.class, () -> new ResumeAiStructurer(properties).structure(SYNTHETIC_TEXT));
        assertNull(captured.get());
        properties.setApiKey("synthetic-api-credential");
        properties.setMaxInputChars(10);
        assertThrows(ServiceException.class, () -> new ResumeAiStructurer(properties).structure(SYNTHETIC_TEXT));
        assertNull(captured.get());
    }

    @Test
    void timeoutHasReadableBusinessMessage()
    {
        delay = 1500;
        properties.setTimeoutSeconds(1);
        assertTrue(assertThrows(ServiceException.class, () -> new ResumeAiStructurer(properties).structure(SYNTHETIC_TEXT))
                .getMessage().contains("超时"));
    }

    @Test
    void parserCallsApiAfterExtractionWithoutCreatingBusinessOrFileRecords() throws Exception
    {
        ResumePdfParser parser = mock(ResumePdfParser.class);
        when(parser.parse(any(byte[].class))).thenReturn(new ResumePdfParser.Result(SYNTHETIC_TEXT, "OCR"));
        AppResumeServiceImpl service = new AppResumeServiceImpl();
        ReflectionTestUtils.setField(service, "pdfParser", parser);
        ReflectionTestUtils.setField(service, "aiStructurer", new ResumeAiStructurer(properties));
        ReflectionTestUtils.setField(service, "structureProperties", properties);
        AppResume draft = service.parsePdf(new byte[] {1}, "synthetic.pdf");
        assertEquals("AI", draft.getStructureMethod());
        assertEquals("OCR", draft.getParseMethod());
        assertEquals(SYNTHETIC_TEXT, draft.getExtractedText());
        assertEquals("synthetic", draft.getResumeName());
        assertNull(draft.getResumeId());
        assertNull(draft.getFilePath());
        assertFalse(draft.getIsDefault());
    }

    @Test
    void failedApiDoesNotReturnBlankManualDraft()
    {
        ResumePdfParser parser = mock(ResumePdfParser.class);
        when(parser.parse(any(byte[].class))).thenReturn(new ResumePdfParser.Result(SYNTHETIC_TEXT, "OCR"));
        ResumeAiStructurer ai = mock(ResumeAiStructurer.class);
        when(ai.structure(SYNTHETIC_TEXT)).thenThrow(new ServiceException("AI 简历编排超时"));
        AppResumeServiceImpl service = new AppResumeServiceImpl();
        ReflectionTestUtils.setField(service, "pdfParser", parser);
        ReflectionTestUtils.setField(service, "aiStructurer", ai);
        ReflectionTestUtils.setField(service, "structureProperties", properties);
        ServiceException error = assertThrows(ServiceException.class,
                () -> service.parsePdf(new byte[] {1}, "synthetic.pdf"));
        assertTrue(error.getMessage().contains("超时"));
    }
}
