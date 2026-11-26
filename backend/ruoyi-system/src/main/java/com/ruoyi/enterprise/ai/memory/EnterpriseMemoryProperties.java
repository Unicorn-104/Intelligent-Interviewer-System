package com.ruoyi.enterprise.ai.memory;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/** Enterprise recruiter memory limits and vector collection configuration. */
@Configuration
@ConfigurationProperties(prefix = "app.ai.enterprise.memory")
public class EnterpriseMemoryProperties
{
    private boolean enabled = true;
    private String collection = "enterprise_memory_bge_small_zh_v1";
    private int recallLimit = 30;
    private int rerankTopN = 5;
    private int maxFacts = 500;

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    public String getCollection() { return collection; }
    public void setCollection(String collection) { this.collection = collection; }
    public int getRecallLimit() { return recallLimit; }
    public void setRecallLimit(int recallLimit) { this.recallLimit = recallLimit; }
    public int getRerankTopN() { return rerankTopN; }
    public void setRerankTopN(int rerankTopN) { this.rerankTopN = rerankTopN; }
    public int getMaxFacts() { return maxFacts; }
    public void setMaxFacts(int maxFacts) { this.maxFacts = maxFacts; }
}
