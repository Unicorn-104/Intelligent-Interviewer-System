package com.ruoyi.enterprise.ai.agent.exam;

import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.enterprise.mapper.ExamMapper;
import com.ruoyi.enterprise.ai.agent.exam.IExamAiService;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.enterprise.ai.agent.client.EnterpriseAgentModelClient;

/**
 * 题库 AI 辅助实现：复用 t_model_provider 中配置的模型服务。
 *
 * <p>输出被约束为 JSON：analysis（答案解析）、valid（题目是否正确）、issues（问题清单）。
 * 上游异常统一映射为不泄露密钥、提示词与题目原文的业务错误。</p>
 *
 * @author enterprise
 */
@Service
public class ExamAiServiceImpl implements IExamAiService
{
    private static final int MAX_TOKENS = 3000;
    private static final long CALL_TIMEOUT_SECONDS = 85;

    private static final int GEN_MAX_TOKENS = 8000;
    private static final long GEN_TIMEOUT_SECONDS = 170;

    private static final String PLAN_SYSTEM_PROMPT = """
        你是企业笔试命题规划专家。请根据岗位信息、题型配额、难度与重点方向占比，先制定知识点覆盖计划。
        规则：
        1. 只输出 JSON 对象，不要输出任何解释文字或代码块标记。
        2. 结构：{"note":"一句话命题策略","points":[{"skillTag":"知识点名称","weight":40,"focus":true}]}
        3. points 数量 3~8 个，weight 为整数且总和为 100。
        4. focusPoints 指定的重点方向约占总题量的 focusWeight%，对应 point 标记 focus:true；其余知识点覆盖岗位描述与技能标签中的其他核心技能。
        5. skillTag 用 2~12 个字的具体技术点名称（如 Spring Boot 事务、MySQL 索引、Java 并发）。
        """;

    private static final String TYPE_GEN_SYSTEM_PROMPT = """
        你是企业笔试命题专家。请严格按照知识点规划命制指定题型的题目。
        规则：
        1. 只输出 JSON 数组，不要输出任何解释文字或代码块标记；数组长度必须等于要求的题量。
        2. 每道题字段：type、content、options、answer、analysis、difficulty、skillTag。
           - type 固定为题目要求中的题型编号
           - 单选/多选 options 必须为 4 个互斥选项文本；判断题 options 固定 ["对","错"]；简答/编程为空数组
           - 单选 answer 为选项字母如 "A"；多选为字母组合如 "AC"；判断题填 "对" 或 "错"；简答/编程填参考答案要点
           - analysis：单选/多选必须解释正确选项为什么成立、并说明干扰选项错在哪里；判断题说明判断依据；简答题给出得分要点并解析；编程题给出评分要点与关键实现说明。客观题不得只写"答案是 X"，也不得写成评分要点口吻
           - difficulty：1简单 2中等 3困难
        3. 题目必须分布在知识点规划范围内，并参考各知识点 weight 占比；不得全部集中在单一知识点。
        4. 题干与考点不得重复，且不得与 avoidStems 中已有题目相同或近似。
        5. 不得在题干中泄露答案。
        """;

    private static final String REVIEW_SYSTEM_PROMPT = """
        你是笔试题审校专家。请逐题检查是否存在：题干与标准答案矛盾、选项与答案不匹配、选项缺失或重复、题干有歧义、判断题答案不是 对/错、答案格式错误、题干泄露答案、单选/多选/判断题解析未解释选项依据（例如只写「答案是 A」）。
        只输出 JSON 对象：{"invalid":[{"index":0,"reason":"问题说明"}]}；全部合格时输出 {"invalid":[]}。
        """;

    private static final String SYSTEM_PROMPT = """
        你是题库审校助手。请阅读题目信息（题型、题干、选项、标准答案），完成两件事：
        1. 生成简洁准确的答案解析：说明正确答案为什么正确，必要时说明其他选项错在哪里。
        2. 检查题目本身是否正确：标准答案是否与选项匹配、选项是否缺失或重复、题干是否有歧义、题型与作答形式是否一致、答案是否与题干矛盾。
        只输出如下 JSON，不要输出任何其他文字或代码块标记：
        {"analysis":"答案解析正文","valid":true,"issues":["发现的问题，没有则为空数组"]}
        若题目没有明显问题，valid 为 true 且 issues 为空数组。
        """;

    @Autowired
    private EnterpriseAgentModelClient model;

    @Autowired
    private ExamMapper examMapper;

    private final ObjectMapper mapper = new ObjectMapper()
            .enable(JsonParser.Feature.STRICT_DUPLICATE_DETECTION)
            .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS);

    @Override
    public Map<String, Object> analyzeQuestion(Map<String, Object> body)
    {
        String content = asString(body.get("content"));
        if (StringUtils.isEmpty(content))
        {
            throw new ServiceException("题干不能为空");
        }
        ModelProvider provider = model.resolve();
        ObjectNode payload = mapper.createObjectNode();
        payload.put("type", analysisTypeLabel(asInt(body.get("type"), 0)));
        payload.put("typeName", asString(body.get("typeName")));
        payload.put("content", content);
        payload.put("answer", asString(body.get("answer")));
        payload.put("difficulty", asString(body.get("difficulty")));
        payload.put("skillTag", asString(body.get("skillTag")));
        Object options = body.get("options");
        if (options instanceof List<?> list)
        {
            ArrayNode array = payload.putArray("options");
            for (Object option : list)
            {
                array.add(asString(option));
            }
        }
        else if (options != null && !StringUtils.isEmpty(options.toString()))
        {
            payload.put("options", options.toString());
        }

        ArrayNode messages = mapper.createArrayNode();
        messages.addObject().put("role", "system").put("content", SYSTEM_PROMPT);
        messages.addObject().put("role", "user").put("content", "待审校题目：\n" + payload.toPrettyString());
        StringBuilder output = new StringBuilder();
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(CALL_TIMEOUT_SECONDS);
        try
        {
            model.complete(provider, messages, null, output::append, deadline, MAX_TOKENS);
        }
        catch (Throwable error)
        {
            throw friendly(error);
        }
        if (output.length() == 0)
        {
            throw new ServiceException("AI 未返回内容，请稍后重试");
        }
        return decode(output.toString());
    }

    @Override
    public Map<String, Object> planPaper(Map<String, Object> request)
    {
        Map<String, Object> fallback = new LinkedHashMap<>();
        fallback.put("note", "按岗位技能与重点方向比例直接命题");
        fallback.put("points", List.of());
        ModelProvider provider;
        try
        {
            provider = model.resolve("exam");
        }
        catch (RuntimeException error)
        {
            return fallback;
        }
        ArrayNode messages = mapper.createArrayNode();
        messages.addObject().put("role", "system").put("content", PLAN_SYSTEM_PROMPT);
        messages.addObject().put("role", "user").put("content", "岗位与命题参数：\n"
                + buildPayload(request).toPrettyString());
        StringBuilder output = new StringBuilder();
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(CALL_TIMEOUT_SECONDS);
        try
        {
            model.complete(provider, messages, null, output::append, deadline, MAX_TOKENS);
        }
        catch (Throwable error)
        {
            return fallback;
        }
        if (output.length() == 0)
        {
            return fallback;
        }
        try
        {
            JsonNode node = mapper.readTree(stripFence(output.toString()));
            if (!node.isObject())
            {
                return fallback;
            }
            Map<String, Object> plan = new LinkedHashMap<>();
            plan.put("note", text(node, "note"));
            List<Map<String, Object>> points = new ArrayList<>();
            for (JsonNode point : node.path("points"))
            {
                String skillTag = text(point, "skillTag");
                if (skillTag.isEmpty())
                {
                    continue;
                }
                Map<String, Object> item = new LinkedHashMap<>();
                item.put("skillTag", skillTag);
                item.put("weight", point.path("weight").asInt(0));
                item.put("focus", point.path("focus").asBoolean(false));
                points.add(item);
            }
            plan.put("points", points);
            return plan;
        }
        catch (IOException error)
        {
            return fallback;
        }
    }

    @Override
    public List<Map<String, Object>> generateQuestionsByType(Map<String, Object> request, int type,
            int count, Map<String, Object> plan, List<String> avoidStems)
    {
        ModelProvider provider = model.resolve("exam");
        ObjectNode payload = buildPayload(request);
        payload.put("type", analysisTypeLabel(type));
        payload.put("typeCode", type);
        payload.put("count", count);
        payload.set("plan", mapper.valueToTree(plan == null ? Map.of() : plan));
        ArrayNode avoid = payload.putArray("avoidStems");
        if (avoidStems != null)
        {
            for (String stem : avoidStems)
            {
                if (!StringUtils.isEmpty(stem))
                {
                    avoid.add(stem);
                }
            }
        }
        ArrayNode messages = mapper.createArrayNode();
        messages.addObject().put("role", "system").put("content", TYPE_GEN_SYSTEM_PROMPT);
        messages.addObject().put("role", "user").put("content", "命题要求（count 为本题型题量）：\n"
                + payload.toPrettyString());
        Object rawCompanyId = request.get("companyId");
        Long companyId = rawCompanyId == null ? null : Long.valueOf(String.valueOf(rawCompanyId));
        EnterpriseAgentModelClient.ToolExecutor executor = (name, arguments) -> {
            if (!"search_question_bank".equals(name))
            {
                return "{\"error\":\"未支持的工具\"}";
            }
            try
            {
                JsonNode args = mapper.readTree(arguments == null || arguments.isBlank() ? "{}" : arguments);
                String keyword = args.path("keyword").asText("").trim();
                int limit = Math.max(1, Math.min(10, args.path("limit").asInt(5)));
                if (keyword.isEmpty() || companyId == null)
                {
                    return "[]";
                }
                return mapper.writeValueAsString(examMapper.searchQuestionStems(companyId, keyword, limit));
            }
            catch (Exception error)
            {
                return "[]";
            }
        };
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(GEN_TIMEOUT_SECONDS);
        String content;
        try
        {
            content = model.chatWithTools(provider, messages, bankTools(), executor, deadline, GEN_MAX_TOKENS)
                    .message().path("content").asText("");
        }
        catch (Exception toolFailure)
        {
            // 兼容不支持 tools 的模型服务：退回单轮无工具生成
            ArrayNode plain = mapper.createArrayNode();
            plain.addObject().put("role", "system").put("content", TYPE_GEN_SYSTEM_PROMPT);
            plain.addObject().put("role", "user").put("content", "命题要求（count 为本题型题量）：\n"
                    + payload.toPrettyString());
            StringBuilder output = new StringBuilder();
            long plainDeadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(GEN_TIMEOUT_SECONDS);
            try
            {
                model.complete(provider, plain, null, output::append, plainDeadline, GEN_MAX_TOKENS);
            }
            catch (Throwable error)
            {
                throw friendly(error);
            }
            content = output.toString();
        }
        if (content.isEmpty())
        {
            throw new ServiceException("AI 未返回内容，请稍后重试");
        }
        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> question : decodeQuestions(content))
        {
            if (asInt(question.get("type"), 0) == type)
            {
                result.add(question);
            }
        }
        return result;
    }

    @Override
    public List<Integer> reviewQuestions(List<Map<String, Object>> questions, Map<String, Object> plan)
    {
        List<Integer> invalid = new ArrayList<>();
        if (questions == null || questions.isEmpty())
        {
            return invalid;
        }
        ModelProvider provider;
        try
        {
            provider = model.resolve("exam");
        }
        catch (RuntimeException error)
        {
            return invalid;
        }
        ObjectNode payload = mapper.createObjectNode();
        ArrayNode items = payload.putArray("questions");
        for (int i = 0; i < questions.size(); i++)
        {
            Map<String, Object> q = questions.get(i);
            ObjectNode item = items.addObject();
            item.put("index", i);
            item.put("type", analysisTypeLabel(asInt(q.get("type"), 0)));
            item.put("content", asString(q.get("content")));
            item.put("answer", asString(q.get("answer")));
            item.put("skillTag", asString(q.get("skillTag")));
            Object options = q.get("options");
            if (options instanceof List<?> list)
            {
                ArrayNode array = item.putArray("options");
                for (Object option : list)
                {
                    array.add(asString(option));
                }
            }
        }
        if (plan != null)
        {
            payload.set("plan", mapper.valueToTree(plan));
        }
        ArrayNode messages = mapper.createArrayNode();
        messages.addObject().put("role", "system").put("content", REVIEW_SYSTEM_PROMPT);
        messages.addObject().put("role", "user").put("content", payload.toPrettyString());
        StringBuilder output = new StringBuilder();
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(CALL_TIMEOUT_SECONDS);
        try
        {
            model.complete(provider, messages, null, output::append, deadline, 2000);
        }
        catch (Throwable error)
        {
            return invalid;
        }
        try
        {
            JsonNode node = mapper.readTree(stripFence(output.toString()));
            for (JsonNode item : node.path("invalid"))
            {
                int index = item.path("index").asInt(-1);
                if (index >= 0 && index < questions.size())
                {
                    invalid.add(index);
                }
            }
        }
        catch (IOException error)
        {
            return new ArrayList<>();
        }
        return invalid;
    }

    /** 组装岗位上下文与配额参数（规划与命题共用） */
    private ObjectNode buildPayload(Map<String, Object> request)
    {
        ObjectNode payload = mapper.createObjectNode();
        payload.put("positionTitle", asString(request.get("positionTitle")));
        payload.put("description", asString(request.get("description")));
        payload.put("skills", asString(request.get("skills")));
        payload.put("education", asString(request.get("education")));
        payload.put("experience", asString(request.get("experience")));
        payload.put("difficulty", difficultyLabel(asInt(request.get("difficulty"), 0)));
        payload.put("focusPoints", asString(request.get("focusPoints")));
        payload.put("focusWeight", asInt(request.get("focusWeight"), 40));
        Object counts = request.get("counts");
        if (counts instanceof Map<?, ?> map)
        {
            ObjectNode quota = payload.putObject("quotas");
            for (Map.Entry<?, ?> entry : map.entrySet())
            {
                quota.put(String.valueOf(entry.getKey()), String.valueOf(entry.getValue()));
            }
        }
        return payload;
    }

    private String analysisTypeLabel(int type)
    {
        return switch (type)
        {
            case 1 -> "单选题";
            case 2 -> "多选题";
            case 3 -> "判断题";
            case 4 -> "简答题";
            case 5 -> "编程题";
            default -> "未知题型";
        };
    }

    /** 命题阶段可调用的工具：题库关键词查重 */
    private ArrayNode bankTools()
    {
        ArrayNode tools = mapper.createArrayNode();
        ObjectNode function = tools.addObject().put("type", "function").putObject("function");
        function.put("name", "search_question_bank");
        function.put("description", "在企业可见题库中按技术关键词检索已有题干，用于出题前查重；返回题干文本数组");
        ObjectNode parameters = function.putObject("parameters");
        parameters.put("type", "object");
        ObjectNode properties = parameters.putObject("properties");
        properties.putObject("keyword").put("type", "string").put("description", "技术关键词，如 MySQL 索引");
        properties.putObject("limit").put("type", "integer").put("description", "返回条数 1~10，默认 5");
        parameters.putArray("required").add("keyword");
        return tools;
    }

    private List<Map<String, Object>> decodeQuestions(String content)
    {
        String json = stripFence(content);
        JsonNode node;
        try
        {
            node = mapper.readTree(json);
        }
        catch (IOException error)
        {
            throw new ServiceException("AI 返回格式错误，请重试");
        }
        JsonNode array = node != null && node.isArray() ? node : node == null ? null : node.path("questions");
        if (array == null || !array.isArray())
        {
            throw new ServiceException("AI 返回格式错误，请重试");
        }
        List<Map<String, Object>> result = new ArrayList<>();
        for (JsonNode item : array)
        {
            Map<String, Object> question = normalizeQuestion(item);
            if (question != null)
            {
                result.add(question);
            }
        }
        return result;
    }

    /** 校验并规范化 AI 返回的单道题目，不合法返回 null */
    private Map<String, Object> normalizeQuestion(JsonNode item)
    {
        int type = item.path("type").asInt(0);
        if (type < 1 || type > 5)
        {
            return null;
        }
        String content = text(item, "content");
        String answer = text(item, "answer");
        if (content.isEmpty() || answer.isEmpty())
        {
            return null;
        }
        List<String> options = new ArrayList<>();
        JsonNode optionNode = item.path("options");
        if (optionNode.isArray())
        {
            for (JsonNode option : optionNode)
            {
                String value = option.asText("").trim();
                if (!value.isEmpty())
                {
                    options.add(value);
                }
            }
        }
        if (type <= 2)
        {
            if (options.size() < 2)
            {
                return null;
            }
            answer = choiceLetters(answer, options.size(), type == 2);
            if (answer.isEmpty())
            {
                return null;
            }
        }
        else if (type == 3)
        {
            answer = judgeAnswer(answer);
            if (answer == null)
            {
                return null;
            }
            options = new ArrayList<>(List.of("对", "错"));
        }
        else
        {
            options = new ArrayList<>();
        }
        int difficulty = item.path("difficulty").asInt(2);
        if (difficulty < 1 || difficulty > 3)
        {
            difficulty = 2;
        }
        Map<String, Object> question = new LinkedHashMap<>();
        question.put("type", type);
        question.put("content", content);
        question.put("options", options);
        question.put("answer", answer);
        question.put("analysis", text(item, "analysis"));
        question.put("difficulty", difficulty);
        question.put("skillTag", text(item, "skillTag"));
        return question;
    }

    /** 单选取首个合法字母；多选取合法字母去重排序 */
    private String choiceLetters(String raw, int optionCount, boolean multiple)
    {
        StringBuilder letters = new StringBuilder();
        for (char ch : raw.toUpperCase().toCharArray())
        {
            if (ch >= 'A' && ch < 'A' + optionCount && letters.indexOf(String.valueOf(ch)) < 0)
            {
                letters.append(ch);
                if (!multiple)
                {
                    break;
                }
            }
        }
        if (multiple && letters.length() > 1)
        {
            char[] chars = letters.toString().toCharArray();
            java.util.Arrays.sort(chars);
            return new String(chars);
        }
        return letters.toString();
    }

    /** 判断题答案统一为 对/错 */
    private String judgeAnswer(String raw)
    {
        String value = raw.trim().toUpperCase();
        if ("对".equals(value) || "正确".equals(value) || "A".equals(value) || "TRUE".equals(value)
                || "T".equals(value) || "是".equals(value))
        {
            return "对";
        }
        if ("错".equals(value) || "错误".equals(value) || "B".equals(value) || "FALSE".equals(value)
                || "F".equals(value) || "否".equals(value))
        {
            return "错";
        }
        return null;
    }

    private String stripFence(String content)
    {
        String json = content.trim();
        if (json.startsWith("```json") && json.endsWith("```"))
        {
            return json.substring(7, json.length() - 3).trim();
        }
        if (json.startsWith("```") && json.endsWith("```"))
        {
            return json.substring(3, json.length() - 3).trim();
        }
        return json;
    }

    private String text(JsonNode node, String field)
    {
        return node.path(field).asText("").trim();
    }

    private String difficultyLabel(int difficulty)
    {
        return switch (difficulty)
        {
            case 1 -> "简单";
            case 2 -> "中等";
            case 3 -> "困难";
            default -> "混合难度（简单/中等/困难按 3:5:2 配比）";
        };
    }

    private Map<String, Object> decode(String content)
    {
        String json = content.trim();
        if (json.startsWith("```json") && json.endsWith("```"))
        {
            json = json.substring(7, json.length() - 3).trim();
        }
        else if (json.startsWith("```") && json.endsWith("```"))
        {
            json = json.substring(3, json.length() - 3).trim();
        }
        try
        {
            JsonNode node = mapper.readTree(json);
            if (!node.isObject() || node.path("analysis").isMissingNode())
            {
                throw new ServiceException("AI 返回格式错误，请重试");
            }
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("analysis", node.path("analysis").asText(""));
            result.put("valid", node.path("valid").asBoolean(true));
            List<String> issues = new ArrayList<>();
            JsonNode issueNode = node.path("issues");
            if (issueNode.isArray())
            {
                for (JsonNode issue : issueNode)
                {
                    String text = issue.asText("").trim();
                    if (!text.isEmpty())
                    {
                        issues.add(text);
                    }
                }
            }
            result.put("issues", issues);
            return result;
        }
        catch (IOException error)
        {
            throw new ServiceException("AI 返回格式错误，请重试");
        }
    }

    private ServiceException friendly(Throwable error)
    {
        if (error instanceof ServiceException service)
        {
            return service;
        }
        String marker = error instanceof IllegalStateException ? error.getMessage() : "";
        if (marker != null && marker.contains("MODEL_OUTPUT_LIMIT"))
        {
            return new ServiceException("题目内容过长，AI 未能完整输出，请精简后重试");
        }
        if (marker != null && marker.contains("MODEL_STREAM_INCOMPLETE"))
        {
            return new ServiceException("题目内容过长，AI 未能完整输出，请精简后重试");
        }
        if (marker != null && marker.contains("MODEL_HTTP_401")
                || marker != null && marker.contains("MODEL_HTTP_403"))
        {
            return new ServiceException("模型密钥无效或无权使用指定模型，请检查管理员配置");
        }
        if (marker != null && marker.contains("MODEL_HTTP_429"))
        {
            return new ServiceException("模型请求限流或额度不足，请稍后重试");
        }
        if (marker != null && marker.startsWith("MODEL_HTTP_"))
        {
            return new ServiceException("AI 服务暂不可用，请稍后重试");
        }
        if (error instanceof java.util.concurrent.TimeoutException)
        {
            return new ServiceException("AI 解析超时，请稍后重试");
        }
        if (error instanceof InterruptedException)
        {
            Thread.currentThread().interrupt();
            return new ServiceException("AI 解析已中断");
        }
        return new ServiceException("AI 服务连接失败，请稍后重试");
    }

    private String asString(Object value)
    {
        return value == null ? "" : value.toString().trim();
    }

    private int asInt(Object value, int defaultValue)
    {
        return value instanceof Number number ? number.intValue() : defaultValue;
    }
}
