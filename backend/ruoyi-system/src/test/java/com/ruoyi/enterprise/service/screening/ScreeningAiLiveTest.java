package com.ruoyi.enterprise.service.screening;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.system.config.JdAiProperties;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

/** Opt-in only: one explicitly synthetic resume, never connects to a business database. */
@EnabledIfEnvironmentVariable(named = "SCREENING_LIVE_SMOKE", matches = "true")
class ScreeningAiLiveTest
{
    @Test void configuredProviderProducesEvidenceBackedScoresAndReason() throws Exception
    {
        var properties = new JdAiProperties();
        properties.setBaseUrl(System.getenv("SCREENING_LIVE_URL"));
        properties.setModel(System.getenv("SCREENING_LIVE_MODEL"));
        properties.setApiKey(System.getenv("SCREENING_LIVE_KEY"));
        HttpClient real = HttpClient.newBuilder().followRedirects(HttpClient.Redirect.NEVER).build();
        HttpClient transport = mock(HttpClient.class);
        when(transport.send(any(HttpRequest.class), org.mockito.ArgumentMatchers.<HttpResponse.BodyHandler<String>>any()))
                .thenAnswer(call -> {
                    HttpResponse<String> response = real.send(call.getArgument(0), HttpResponse.BodyHandlers.ofString(java.nio.charset.StandardCharsets.UTF_8));
                    // This opt-in test submits synthetic data only; the envelope contains no business resumes.
                    Files.writeString(Path.of("target/ai-screening-live-synthetic-envelope.json"), response.body());
                    return response;
                });
        var evaluator = new ScreeningAiEvaluator(properties, transport);
        var candidate = Map.<String, Object>of("candidateId", 11L,
                "education", List.of(Map.of("degree", "硕士", "major", "计算机科学", "description", "演示数据：完成分布式系统课程研究，设计Raft一致性实验，获得校级科技创新竞赛二等奖。")),
                "skills", List.of("Java", "Spring Boot", "MySQL", "Redis"),
                "projects", List.of(Map.of("description", "演示数据：负责Java订单平台开发，使用Redis缓存、MySQL索引优化和RabbitMQ削峰，将接口P95延迟从420ms降至160ms。")),
                "workAndInternships", List.of(Map.of("description", "演示数据：6个月后端开发实习，负责Spring Boot接口、单元测试和数据库性能优化。")));
        var result = evaluator.evaluate(Map.of("title", "Java后端工程师（演示数据）", "requirements", "本科及以上计算机相关专业，熟悉Java、Spring Boot、MySQL、Redis，具有项目或实习经验，分布式系统研究优先。"), List.of(candidate));
        assertEquals(1, result.size());
        assertEquals("llm", result.get(0).get("source"));
        assertNotNull(result.get(0).get("totalScore"));
        assertTrue(result.get(0).get("recommendation").toString().length() >= 10);
        Files.writeString(Path.of("target/ai-screening-live-synthetic-result.json"), JSON.toJSONString(result.get(0)));
    }
}
