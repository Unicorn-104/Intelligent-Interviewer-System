package com.ruoyi.enterprise.service.screening;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.system.config.JdAiProperties;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.service.IModelProviderService;
import com.ruoyi.system.service.app.ai.AgentModelClient;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

/** Opt-in only: one explicitly synthetic resume, never connects to a business database. */
@EnabledIfEnvironmentVariable(named = "SCREENING_LIVE_SMOKE", matches = "true")
class ScreeningAiLiveTest
{
    @Test void configuredProviderProducesEvidenceBackedScoresAndReason() throws Exception
    {
        ModelProvider provider = new ModelProvider();
        provider.setMppApiUrl(System.getenv("SCREENING_LIVE_URL"));
        provider.setMppApiKey(System.getenv("SCREENING_LIVE_KEY"));
        provider.setMppModelName(System.getenv("SCREENING_LIVE_MODEL"));
        IModelProviderService providers = mock(IModelProviderService.class);
        when(providers.selectModelProviderList(any())).thenReturn(List.of(provider));
        AgentModelClient client = new AgentModelClient(providers);
        var evaluator = new ScreeningAiEvaluator(new JdAiProperties(), client);
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
