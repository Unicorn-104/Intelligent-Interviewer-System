package com.ruoyi.enterprise.ai.memory;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/** Optional cross-encoder reranker for enterprise memory recall. */
@Configuration
@ConfigurationProperties(prefix = "app.ai.enterprise.memory.rerank")
public class EnterpriseMemoryRerankProperties
{
    private boolean enabled = false;
    private String url = "";
    private String model = "BAAI/bge-reranker-base";
    private int timeoutSeconds = 3;
    private int topN = 5;

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    public String getUrl() { return url; }
    public void setUrl(String url) { this.url = url; }
    public String getModel() { return model; }
    public void setModel(String model) { this.model = model; }
    public int getTimeoutSeconds() { return timeoutSeconds; }
    public void setTimeoutSeconds(int timeoutSeconds) { this.timeoutSeconds = timeoutSeconds; }
    public int getTopN() { return topN; }
    public void setTopN(int topN) { this.topN = topN; }
}
