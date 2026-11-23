package com.ruoyi.ai.core;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * 模型参数的防御式读取：模型可能少字段、把数字写成字符串、把数组序列化成文本。
 */
public final class ToolArgs
{
    private ToolArgs()
    {
    }

    public static JsonNode parse(ObjectMapper json, String argsJson)
    {
        try
        {
            JsonNode node = json.readTree(argsJson == null || argsJson.isBlank() ? "{}" : argsJson);
            return node == null ? json.createObjectNode() : node;
        }
        catch (Exception e)
        {
            return json.createObjectNode();
        }
    }

    public static String text(JsonNode node, String field, int max)
    {
        String value = node.path(field).asText("").trim();
        if (value.length() > max)
        {
            value = value.substring(0, max);
        }
        return value;
    }

    public static Integer integer(JsonNode node, String field)
    {
        return node.has(field) && node.path(field).canConvertToInt() ? node.path(field).asInt() : null;
    }

    public static int intValue(JsonNode node, String field, int fallback)
    {
        return node.has(field) && node.path(field).canConvertToInt() ? node.path(field).asInt() : fallback;
    }

    public static List<String> textList(JsonNode node)
    {
        List<String> list = new ArrayList<>();
        if (node != null && node.isArray())
        {
            for (JsonNode item : node)
            {
                String value = item.asText("").trim();
                if (!value.isEmpty())
                {
                    list.add(value);
                }
            }
        }
        return list;
    }

    public static Set<Long> longSet(JsonNode node)
    {
        Set<Long> set = new LinkedHashSet<>();
        if (node != null && node.isArray())
        {
            for (JsonNode item : node)
            {
                long value = item.asLong(0);
                if (value > 0)
                {
                    set.add(value);
                }
            }
        }
        return set;
    }

    public static String cut(String text, int max)
    {
        if (text == null)
        {
            return "";
        }
        String clean = text.replace('\n', ' ').replace('\r', ' ').trim();
        return clean.length() <= max ? clean : clean.substring(0, max) + "…";
    }
}
