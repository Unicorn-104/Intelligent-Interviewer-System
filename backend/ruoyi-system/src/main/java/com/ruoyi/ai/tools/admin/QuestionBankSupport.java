package com.ruoyi.ai.tools.admin;

import java.util.Map;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.common.exception.ServiceException;

/**
 * 题库工具共享的口径与参数归一逻辑。改动题库编码规则时只改这里。
 */
final class QuestionBankSupport
{
    static final String SCOPE = "admin";

    static final int MAX_ITEMS = 50;
    static final int MAX_CONTENT = 2000;
    static final int MAX_IDS = 200;
    static final int MAX_BATCHES = 20;

    /** 题型：1 单选、2 多选、3 判断、4 简答、5 编程。 */
    static final Map<Integer, String> TYPE_NAMES = Map.of(
            1, "单选", 2, "多选", 3, "判断", 4, "简答", 5, "编程");

    private QuestionBankSupport()
    {
    }

    /** bankType=platform 只看系统题库，enterprise 只看企业题库，其余不过滤。 */
    static String bankScope(String bankType, String column)
    {
        if ("platform".equals(bankType))
        {
            return " AND " + column + " IS NULL";
        }
        if ("enterprise".equals(bankType))
        {
            return " AND " + column + " IS NOT NULL";
        }
        return "";
    }

    /** 企业题库必须显式指定 companyId，避免把企业题写进系统题库。 */
    static Long companyIdOf(String bankType, JsonNode args)
    {
        if (!"enterprise".equals(bankType))
        {
            return null;
        }
        JsonNode node = args.path("companyId");
        if (node.canConvertToLong() && node.asLong() > 0)
        {
            return node.asLong();
        }
        throw new ServiceException("企业题库必须指定 companyId", 400);
    }

    /**
     * 归一 items：兼容模型把 items 序列化成字符串、或把单题字段平铺在顶层。
     * 归一后仍不是非空数组时，由调用方给出提示。
     */
    static JsonNode itemsNode(ObjectMapper json, JsonNode args)
    {
        JsonNode itemsNode = args.path("items");
        if (itemsNode.isTextual())
        {
            try
            {
                itemsNode = json.readTree(itemsNode.asText(""));
            }
            catch (Exception ignore)
            {
                itemsNode = json.createArrayNode();
            }
        }
        if (itemsNode.isObject() || !itemsNode.isArray())
        {
            JsonNode single = itemsNode.isObject() ? itemsNode : args;
            if (!single.path("content").asText("").isBlank())
            {
                itemsNode = json.createArrayNode().add(single);
            }
        }
        return itemsNode;
    }

    /** 卡片摘要：与原实现一致，保留换行，超长截断。 */
    static String summarize(String text)
    {
        return text.length() > 220 ? text.substring(0, 220) + "…" : text;
    }
}
