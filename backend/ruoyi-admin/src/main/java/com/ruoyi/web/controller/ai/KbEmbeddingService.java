package com.ruoyi.web.controller.ai;

import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.openai.OpenAiEmbeddingModel;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.util.List;
import java.util.Map;

/**
 * RAG Embedding服务：调火山方舟把文本变成向量，算余弦相似度。
 */
@Service
public class KbEmbeddingService {

    private final JdbcTemplate jdbc;
    private EmbeddingModel embeddingModel;

    // 火山方舟配置：地址与模型给默认值，密钥必须由环境变量 ARK_API_KEY 注入，禁止硬编码
    @Value("${rag.embedding.base-url:https://ark.cn-beijing.volces.com/api/v3}")
    private String arkBaseUrl;

    @Value("${rag.embedding.api-key:}")
    private String arkApiKey;

    @Value("${rag.embedding.model:doubao-embedding}")
    private String modelName;

    public KbEmbeddingService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @PostConstruct
    public void init() {
        if (arkApiKey == null || arkApiKey.isBlank()) {
            System.err.println("[RAG] 未配置 rag.embedding.api-key（环境变量 ARK_API_KEY），Embedding 服务不可用");
            return;
        }
        try {
            embeddingModel = OpenAiEmbeddingModel.builder()
                    .baseUrl(arkBaseUrl)
                    .apiKey(arkApiKey)
                    .modelName(modelName)
                    .build();
            System.out.println("[RAG] Embedding服务初始化成功: " + modelName);
        } catch (Exception e) {
            System.err.println("[RAG] Embedding初始化失败: " + e.getMessage());
        }
    }

    /** 把一段文字变成向量 */
    public float[] embed(String text) {
        if (embeddingModel == null) return null;
        return embeddingModel.embed(text).content().vector();
    }

    /** 上传知识时：存向量 */
    public void saveVector(Long kbId, String content) {
        try {
            float[] vec = embed(content);
            if (vec == null) return;
            // 转成JSON数组字符串
            StringBuilder sb = new StringBuilder("[");
            for (int i = 0; i < vec.length; i++) {
                if (i > 0) sb.append(",");
                sb.append(vec[i]);
            }
            sb.append("]");
            jdbc.update("INSERT INTO t_ai_kb_vector (kb_id, content, embedding) VALUES (?,?,?)",
                    kbId, content, sb.toString());
        } catch (Exception e) {
            System.err.println("[RAG] saveVector失败: " + e.getMessage());
        }
    }

    /** 查询时：问题向量化，和库里所有向量算余弦相似度，返回Top3 */
    public List<String> search(String question, int topK) {
        if (embeddingModel == null) return List.of();
        try {
            float[] qVec = embed(question);
            if (qVec == null) return List.of();

            // 取所有向量（数据量小，全表算）
            List<Map<String, Object>> rows = jdbc.queryForList(
                    "SELECT id, content, embedding FROM t_ai_kb_vector");

            // 算每条的相似度
            record Scored(String content, double score) {}
            List<Scored> scored = new java.util.ArrayList<>();
            for (Map<String, Object> row : rows) {
                float[] docVec = parseJsonArray((String) row.get("embedding"));
                if (docVec == null || docVec.length != qVec.length) continue;
                double sim = cosineSimilarity(qVec, docVec);
                scored.add(new Scored((String) row.get("content"), sim));
            }

            // 按相似度排序取TopK
            return scored.stream()
                    .sorted((a, b) -> Double.compare(b.score(), a.score()))
                    .limit(topK)
                    .map(Scored::content)
                    .toList();
        } catch (Exception e) {
            System.err.println("[RAG] search失败: " + e.getMessage());
            return List.of();
        }
    }

    /** 余弦相似度 */
    private double cosineSimilarity(float[] a, float[] b) {
        double dot = 0, normA = 0, normB = 0;
        for (int i = 0; i < a.length; i++) {
            dot += a[i] * b[i];
            normA += a[i] * a[i];
            normB += b[i] * b[i];
        }
        return dot / (Math.sqrt(normA) * Math.sqrt(normB));
    }

    /** 把MySQL JSON字符串转成float数组 */
    private float[] parseJsonArray(String json) {
        try {
            String[] parts = json.replace("[", "").replace("]", "").split(",");
            float[] arr = new float[parts.length];
            for (int i = 0; i < parts.length; i++) arr[i] = Float.parseFloat(parts[i].trim());
            return arr;
        } catch (Exception e) {
            return null;
        }
    }
}
