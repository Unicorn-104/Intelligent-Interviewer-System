package com.ruoyi.enterprise.service.impl;

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
import com.ruoyi.enterprise.service.IExamAiService;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.service.app.ai.AgentModelClient;

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

    private static final String SYSTEM_PROMPT = """
        你是题库审校助手。请阅读题目信息（题型、题干、选项、标准答案），完成两件事：
        1. 生成简洁准确的答案解析：说明正确答案为什么正确，必要时说明其他选项错在哪里。
        2. 检查题目本身是否正确：标准答案是否与选项匹配、选项是否缺失或重复、题干是否有歧义、题型与作答形式是否一致、答案是否与题干矛盾。
        只输出如下 JSON，不要输出任何其他文字或代码块标记：
        {"analysis":"答案解析正文","valid":true,"issues":["发现的问题，没有则为空数组"]}
        若题目没有明显问题，valid 为 true 且 issues 为空数组。
        """;

    @Autowired
    private AgentModelClient model;

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
        payload.put("type", typeLabel(asInt(body.get("type"), 0)));
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

    private String typeLabel(int type)
    {
        return switch (type)
        {
            case 1 -> "单选";
            case 2 -> "多选";
            case 3 -> "判断";
            case 4 -> "简答";
            case 5 -> "编程";
            case 6 -> "自定义";
            default -> "未知";
        };
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
