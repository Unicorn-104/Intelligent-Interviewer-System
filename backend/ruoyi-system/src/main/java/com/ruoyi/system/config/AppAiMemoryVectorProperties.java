package com.ruoyi.system.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/** Local embedding and Qdrant configuration for private candidate memories. */
@Configuration
@ConfigurationProperties(prefix = "app.ai.memory.vector")
public class AppAiMemoryVectorProperties
{
    private boolean enabled = true;
    private String qdrantUrl = "http://127.0.0.1:6333";
    private String qdrantApiKey = "";
    private String collection = "capp_user_memory_bge_small_zh_v1";
    private String embeddingUrl = "";
    private String embeddingApiKey = "";
    private String embeddingModel = "BAAI/bge-small-zh-v1.5";
    private int dimension = 512;
    private double minScore = 0.45d;
    private int connectTimeoutSeconds = 3;
    private int requestTimeoutSeconds = 3;

    public boolean isConfigured()
    { return enabled && embeddingUrl != null && !embeddingUrl.isBlank() && embeddingModel != null && !embeddingModel.isBlank(); }

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    public String getQdrantUrl() { return qdrantUrl; }
    public void setQdrantUrl(String qdrantUrl) { this.qdrantUrl = qdrantUrl; }
    public String getQdrantApiKey() { return qdrantApiKey; }
    public void setQdrantApiKey(String qdrantApiKey) { this.qdrantApiKey = qdrantApiKey; }
    public String getCollection() { return collection; }
    public void setCollection(String collection) { this.collection = collection; }
    public String getEmbeddingUrl() { return embeddingUrl; }
    public void setEmbeddingUrl(String embeddingUrl) { this.embeddingUrl = embeddingUrl; }
    public String getEmbeddingApiKey() { return embeddingApiKey; }
    public void setEmbeddingApiKey(String embeddingApiKey) { this.embeddingApiKey = embeddingApiKey; }
    public String getEmbeddingModel() { return embeddingModel; }
    public void setEmbeddingModel(String embeddingModel) { this.embeddingModel = embeddingModel; }
    public int getDimension() { return dimension; }
    public void setDimension(int dimension) { this.dimension = dimension; }
    public double getMinScore() { return minScore; }
    public void setMinScore(double minScore) { this.minScore = minScore; }
    public int getConnectTimeoutSeconds() { return connectTimeoutSeconds; }
    public void setConnectTimeoutSeconds(int connectTimeoutSeconds) { this.connectTimeoutSeconds = connectTimeoutSeconds; }
    public int getRequestTimeoutSeconds() { return requestTimeoutSeconds; }
    public void setRequestTimeoutSeconds(int requestTimeoutSeconds) { this.requestTimeoutSeconds = requestTimeoutSeconds; }
}
