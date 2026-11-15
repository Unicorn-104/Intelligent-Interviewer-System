package com.ruoyi.system.service;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import org.springframework.stereotype.Service;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.service.app.ai.AgentModelClient;

/** 基于当前会话上下文生成企业端快捷回复建议；只读消息，不落库。 */
@Service
public class ImQuickReplyAiService
{
    private static final int CONTEXT_MESSAGES = 12;

    private static final int MAX_CONTENT_CHARS = 500;

    private static final int SUGGESTION_LIMIT = 3;

    private final AgentModelClient model;

    private final IImService imService;

    private final ObjectMapper json = new ObjectMapper();

    public ImQuickReplyAiService(AgentModelClient model, IImService imService)
    {
        this.model = model;
        this.imService = imService;
    }

    public List<String> suggest(Long sessionId, Long userId)
    {
        List<ImMessage> all = imService.selectMessageList(sessionId, userId);
        if (all == null || all.isEmpty())
        {
            throw new ServiceException("当前会话还没有消息，无法生成建议", 400);
        }
        List<ImMessage> recent = all.size() > CONTEXT_MESSAGES ? all.subList(all.size() - CONTEXT_MESSAGES, all.size()) : all;
        ArrayNode conversation = json.createArrayNode();
        for (ImMessage message : recent)
        {
            if (Integer.valueOf(1).equals(message.getIsRecalled())) continue;
            String content = message.getContent();
            if (content == null || content.isBlank()) continue;
            if (content.length() > MAX_CONTENT_CHARS) content = content.substring(0, MAX_CONTENT_CHARS);
            conversation.addObject()
                    .put("role", Boolean.TRUE.equals(message.getIsMine()) ? "招聘方" : "候选人")
                    .put("content", content);
        }
        if (conversation.isEmpty())
        {
            throw new ServiceException("当前会话没有可参考的文字消息", 400);
        }

        ArrayNode prompt = json.createArrayNode();
        prompt.addObject().put("role", "system").put("content",
                "你是招聘方的沟通助手。根据对话上下文为招聘方生成 3 条可直接发送的中文回复建议。"
                + "要求：礼貌专业、简洁（每条不超过60字）、3条角度互不重复、贴合上下文。"
                + "只输出 JSON 数组，形如 [\"建议1\",\"建议2\",\"建议3\"]，不输出任何其他内容。");
        prompt.addObject().put("role", "user").put("content",
                json.createObjectNode().set("conversation", conversation).toString());

        ModelProvider provider = model.resolve("im_reply");
        String answer;
        try
        {
            AgentModelClient.Reply reply = model.complete(provider, prompt, json.createArrayNode(), ignored -> { },
                    System.nanoTime() + TimeUnit.SECONDS.toNanos(30), 600);
            answer = reply.message().path("content").asText("");
        }
        catch (ServiceException e)
        {
            throw e;
        }
        catch (Exception e)
        {
            throw new ServiceException("AI 生成失败，请稍后重试", 503);
        }

        List<String> suggestions = parse(answer);
        if (suggestions.isEmpty())
        {
            throw new ServiceException("AI 未返回有效建议，请重试", 503);
        }
        return suggestions;
    }

    private List<String> parse(String answer)
    {
        List<String> result = new ArrayList<>();
        int start = answer.indexOf('[');
        int end = answer.lastIndexOf(']');
        if (start >= 0 && end > start)
        {
            try
            {
                JsonNode node = json.readTree(answer.substring(start, end + 1));
                if (node.isArray()) for (JsonNode item : node) add(result, item.asText(""));
            }
            catch (Exception ignored)
            {
                // 模型未按 JSON 输出时走下面的逐行兜底
            }
        }
        if (result.isEmpty())
        {
            for (String line : answer.split("\\r?\\n")) add(result, line.replaceFirst("^\\s*(\\d+[.、)]|[-*])\\s*", ""));
        }
        return result;
    }

    private void add(List<String> result, String value)
    {
        String text = value == null ? "" : value.trim().replaceAll("^\"|\"$", "").trim();
        if (!text.isEmpty() && result.size() < SUGGESTION_LIMIT && !result.contains(text))
        {
            result.add(text);
        }
    }
}
