package com.ruoyi.ai.core;

import java.util.List;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;

/**
 * 按端组装的工具包。编排层只依赖本接口，不知道具体有哪些工具。
 */
public interface AgentToolPackage
{
    /** 端标识：admin / enterprise / seeker / exam。 */
    String scope();

    List<AgentTool> tools();

    default AgentTool find(String name)
    {
        if (name == null)
        {
            return null;
        }
        for (AgentTool tool : tools())
        {
            if (tool.name().equals(name))
            {
                return tool;
            }
        }
        return null;
    }

    default ArrayNode definitions(ObjectMapper json)
    {
        ArrayNode array = json.createArrayNode();
        for (AgentTool tool : tools())
        {
            array.add(tool.definition(json));
        }
        return array;
    }
}
