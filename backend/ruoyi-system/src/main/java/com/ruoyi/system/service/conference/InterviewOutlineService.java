package com.ruoyi.system.service.conference;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.mapper.ConferenceMapper;
import com.ruoyi.system.service.app.ai.AgentModelClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 纯AI 面试自动出题：场次没有任何提纲时，按岗位要求调用模型生成题目并写入 t_int_outline；
 * 模型不可用或解析失败时回退为岗位技能题，保证面试始终有题可答。
 * 日志只输出场次ID与失败类型，不输出 Prompt 或模型响应。
 *
 * @author ruoyi
 */
@Component
public class InterviewOutlineService
{
    private static final Logger log = LoggerFactory.getLogger(InterviewOutlineService.class);

    /** 面试模式：1-纯AI */
    private static final int MODE_AI_ONLY = 1;
    /** 自动出题数量 */
    private static final int QUESTION_COUNT = 5;
    /** 岗位 JD 进入 Prompt 的最大长度 */
    private static final int MAX_JD_CHARS = 600;
    /** 模型输出上限 */
    private static final int MAX_OUTPUT_TOKENS = 1200;
    /** 单次模型调用超时（秒） */
    private static final int CALL_TIMEOUT_SECONDS = 60;

    private static final String SYSTEM = """
        你是资深面试官，为一场纯 AI 视频面试命题。
        题目必须围绕岗位要求，问题开放、适合口头作答，不涉及姓名、性别、年龄、婚育、籍贯等敏感信息，也不要求候选人编造经历。
        只输出 JSON，不要 Markdown，格式：
        {"questions":[{"topic":"不超过20字","description":"提问要点，不超过80字","dimension":1}]}
        dimension 取值：1-技术能力，2-逻辑思维，3-沟通表达，4-性格匹配，5-稳定性。
        """;

    @Autowired
    private ConferenceMapper conferenceMapper;

    @Autowired
    private AgentModelClient model;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private final ObjectMapper json = new ObjectMapper();

    /**
     * 补齐纯AI 场次的面试题目；已有题目或非纯AI 场次直接跳过，重复调用幂等。
     */
    public void ensureQuestions(Long sessionId)
    {
        if (sessionId == null)
        {
            return;
        }
        try
        {
            Map<String, Object> ctx = conferenceMapper.selectSessionContext(sessionId);
            if (ctx == null || ctx.isEmpty() || toInt(ctx.get("mode")) != MODE_AI_ONLY)
            {
                return;
            }
            if (conferenceMapper.countOutlineQuestions(sessionId) > 0)
            {
                return;
            }
            List<Map<String, Object>> questions = buildQuestions(ctx);
            if (questions.isEmpty())
            {
                return;
            }
            TransactionTemplate transaction = new TransactionTemplate(transactionManager);
            transaction.executeWithoutResult(status ->
            {
                // 建场与开考可能同时触发，锁场次行后复查，避免重复写题
                conferenceMapper.lockSessionForUpdate(sessionId);
                if (conferenceMapper.countOutlineQuestions(sessionId) > 0)
                {
                    return;
                }
                int order = 1;
                for (Map<String, Object> question : questions)
                {
                    Map<String, Object> params = new LinkedHashMap<>(question);
                    params.put("sessionId", sessionId);
                    params.put("order", order++);
                    conferenceMapper.insertOutlineQuestion(params);
                }
                conferenceMapper.updateMeetingTotalQuestions(sessionId, questions.size());
            });
            log.info("纯AI面试自动出题完成，sessionId={}，题目数={}", sessionId, questions.size());
        }
        catch (Throwable error)
        {
            log.warn("纯AI面试自动出题失败，sessionId={}，原因={}", sessionId, error.getClass().getSimpleName());
        }
    }

    /** 模型出题，不可用或失败时回退技能题 */
    List<Map<String, Object>> buildQuestions(Map<String, Object> ctx)
    {
        List<Map<String, Object>> generated = generateByModel(ctx);
        return generated.isEmpty() ? fallbackQuestions(ctx) : generated;
    }

    private List<Map<String, Object>> generateByModel(Map<String, Object> ctx)
    {
        try
        {
            ModelProvider provider = model.resolve();
            ArrayNode messages = json.createArrayNode();
            messages.addObject().put("role", "system").put("content", SYSTEM);
            messages.addObject().put("role", "user").put("content", buildPrompt(ctx));
            StringBuilder content = new StringBuilder();
            long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(CALL_TIMEOUT_SECONDS);
            model.complete(provider, messages, null, content::append, deadline, MAX_OUTPUT_TOKENS);
            return parseQuestions(content.toString());
        }
        catch (Throwable error)
        {
            log.warn("面试题模型生成失败，回退技能题，sessionId={}", ctx.get("sessionId"));
            return List.of();
        }
    }

    private String buildPrompt(Map<String, Object> ctx)
    {
        StringBuilder prompt = new StringBuilder();
        prompt.append("岗位：").append(text(ctx.get("positionTitle"))).append('\n');
        String jd = text(ctx.get("positionJd"));
        if (jd.length() > MAX_JD_CHARS)
        {
            jd = jd.substring(0, MAX_JD_CHARS);
        }
        if (!jd.isEmpty())
        {
            prompt.append("岗位要求：").append(jd).append('\n');
        }
        List<String> skills = positionSkills(ctx);
        prompt.append("核心技能：").append(skills.isEmpty() ? "未提供" : String.join("、", skills)).append('\n');
        prompt.append("请生成 ").append(QUESTION_COUNT).append(" 道面试题，覆盖不同维度，按考察顺序排列。");
        return prompt.toString();
    }

    private List<Map<String, Object>> parseQuestions(String content)
    {
        List<Map<String, Object>> result = new ArrayList<>();
        String text = content == null ? "" : content.trim();
        int start = text.indexOf('{');
        int end = text.lastIndexOf('}');
        if (start < 0 || end <= start)
        {
            return result;
        }
        try
        {
            JsonNode root = json.readTree(text.substring(start, end + 1));
            for (JsonNode item : root.path("questions"))
            {
                String topic = item.path("topic").asText("").trim();
                if (topic.isEmpty())
                {
                    continue;
                }
                if (topic.length() > 100)
                {
                    topic = topic.substring(0, 100);
                }
                String description = item.path("description").asText("").trim();
                if (description.length() > 500)
                {
                    description = description.substring(0, 500);
                }
                int dimension = item.path("dimension").asInt(1);
                result.add(question(topic, description, dimension < 1 || dimension > 5 ? 1 : dimension));
                if (result.size() >= QUESTION_COUNT)
                {
                    break;
                }
            }
        }
        catch (Exception ignored)
        {
            result.clear();
        }
        return result;
    }

    /** 模型不可用时的兜底：优先岗位技能题，不足部分用通用开放题补齐 */
    List<Map<String, Object>> fallbackQuestions(Map<String, Object> ctx)
    {
        List<Map<String, Object>> result = new ArrayList<>();
        for (String skill : positionSkills(ctx))
        {
            result.add(question("「" + skill + "」项目实践",
                    "请结合一个具体项目，说明你如何使用 " + skill + " 解决问题，以及最终结果。", 1));
            if (result.size() >= QUESTION_COUNT)
            {
                return result;
            }
        }
        List<Map<String, Object>> generic = List.of(
                question("自我介绍与岗位匹配", "请简要介绍你的经历，并说明为什么适合这个岗位。", 3),
                question("最有挑战的项目", "请描述一个你负责过的最有挑战的项目，说明难点和你的解决过程。", 2),
                question("团队协作与分歧", "请举例说明你与团队成员出现分歧时如何处理。", 3),
                question("面对压力的表现", "请说明在时间紧、任务重的情况下，你如何保证交付质量。", 5),
                question("职业规划", "请谈谈你未来一年的职业规划，以及希望在本岗位获得什么成长。", 4));
        for (Map<String, Object> item : generic)
        {
            if (result.size() >= QUESTION_COUNT)
            {
                break;
            }
            result.add(item);
        }
        return result;
    }

    private List<String> positionSkills(Map<String, Object> ctx)
    {
        Long positionId = toLong(ctx.get("positionId"));
        List<String> skills = new ArrayList<>();
        if (positionId == null)
        {
            return skills;
        }
        for (Map<String, Object> skill : conferenceMapper.selectPositionSkills(positionId))
        {
            String name = text(skill.get("name"));
            if (!name.isEmpty() && !skills.contains(name))
            {
                skills.add(name);
            }
        }
        return skills;
    }

    private Map<String, Object> question(String topic, String description, int dimension)
    {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("topic", topic);
        item.put("description", description);
        item.put("dimension", dimension);
        return item;
    }

    private static String text(Object value)
    {
        return value == null ? "" : String.valueOf(value).trim();
    }

    private static int toInt(Object value)
    {
        return value instanceof Number ? ((Number) value).intValue()
                : value == null ? 0 : Integer.parseInt(String.valueOf(value));
    }

    private static Long toLong(Object value)
    {
        if (value instanceof Number)
        {
            return ((Number) value).longValue();
        }
        return value == null ? null : Long.valueOf(String.valueOf(value));
    }
}
