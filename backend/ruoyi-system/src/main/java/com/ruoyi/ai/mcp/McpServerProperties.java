package com.ruoyi.ai.mcp;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * MCP 外部工具接入配置。
 *
 * <p>默认关闭；启用后按 allowTools 白名单注册，未列出的工具不会暴露给模型。</p>
 */
@Component
@ConfigurationProperties(prefix = "mcp")
public class McpServerProperties
{
    private boolean enabled;

    private List<Server> servers = new ArrayList<>();

    public boolean isEnabled()
    {
        return enabled;
    }

    public void setEnabled(boolean enabled)
    {
        this.enabled = enabled;
    }

    public List<Server> getServers()
    {
        return servers;
    }

    public void setServers(List<Server> servers)
    {
        this.servers = servers;
    }

    public static class Server
    {
        private String name;

        private String command;

        private List<String> args = new ArrayList<>();

        private String workDir;

        /** 是否继承后端 JVM 全部环境变量；默认 false，只保留基础系统变量。 */
        private boolean inheritEnv = false;

        /** 显式注入给子进程的环境变量，优先级高于系统变量。 */
        private Map<String, String> env = new HashMap<>();

        private List<String> allowTools = new ArrayList<>();

        private int timeoutSeconds = 30;

        public String getName()
        {
            return name;
        }

        public void setName(String name)
        {
            this.name = name;
        }

        public String getCommand()
        {
            return command;
        }

        public void setCommand(String command)
        {
            this.command = command;
        }

        public List<String> getArgs()
        {
            return args;
        }

        public void setArgs(List<String> args)
        {
            this.args = args;
        }

        public String getWorkDir()
        {
            return workDir;
        }

        public void setWorkDir(String workDir)
        {
            this.workDir = workDir;
        }

        public boolean isInheritEnv()
        {
            return inheritEnv;
        }

        public void setInheritEnv(boolean inheritEnv)
        {
            this.inheritEnv = inheritEnv;
        }

        public Map<String, String> getEnv()
        {
            return env;
        }

        public void setEnv(Map<String, String> env)
        {
            this.env = env;
        }

        public List<String> getAllowTools()
        {
            return allowTools;
        }

        public void setAllowTools(List<String> allowTools)
        {
            this.allowTools = allowTools;
        }

        public int getTimeoutSeconds()
        {
            return timeoutSeconds;
        }

        public void setTimeoutSeconds(int timeoutSeconds)
        {
            this.timeoutSeconds = timeoutSeconds;
        }
    }
}
