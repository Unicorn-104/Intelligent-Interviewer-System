package com.ruoyi.enterprise.ai.knowledge;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.system.config.AppAiMemoryVectorProperties;
import com.ruoyi.system.service.app.ai.QdrantMemoryIndex;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Company-scoped Qdrant index. MySQL remains authoritative; vectors and
 * company/document metadata are rebuildable, and chunk text never enters Qdrant.
 */
@Component
public class EnterpriseKnowledgeVectorIndex
{
    public record Hit(String id, double score) { }

    private final AppAiMemoryVectorProperties properties;
    private final QdrantMemoryIndex embeddings;
    private final String collection;
    private final ObjectMapper json = new ObjectMapper();
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3))
            .followRedirects(HttpClient.Redirect.NEVER).build();
    private volatile boolean ready;

    public EnterpriseKnowledgeVectorIndex(AppAiMemoryVectorProperties properties,
            @Value("${app.ai.enterprise.rag.collection:enterprise_knowledge_bge_small_zh_v1}") String collection)
    {
        if (!collection.matches("[a-zA-Z0-9_-]{1,100}") || collection.equals(properties.getCollection()))
            throw new IllegalArgumentException("ENTERPRISE_KNOWLEDGE_COLLECTION");
        this.properties = properties;
        this.collection = collection;
        var config = new AppAiMemoryVectorProperties();
        config.setEmbeddingUrl(properties.getEmbeddingUrl());
        config.setEmbeddingApiKey(properties.getEmbeddingApiKey());
        config.setEmbeddingModel(properties.getEmbeddingModel());
        config.setDimension(properties.getDimension());
        config.setRequestTimeoutSeconds(10);
        embeddings = new QdrantMemoryIndex(config);
    }

    public boolean configured() { return properties.isConfigured(); }

    public List<Double> embedQuery(String text) throws Exception
    {
        if (!configured()) throw new IllegalStateException("EMBEDDING_NOT_CONFIGURED");
        var vector = embeddings.embed(text, true);
        if (vector.isEmpty()) throw new IllegalStateException("EMBEDDING_NOT_CONFIGURED");
        return vector;
    }

    public List<List<Double>> embedPassages(List<String> texts) throws Exception
    {
        if (!configured()) throw new IllegalStateException("EMBEDDING_NOT_CONFIGURED");
        var vectors = embeddings.embedBatch(texts, false);
        if (vectors.size() != texts.size()) throw new IllegalStateException("EMBEDDING_RESPONSE_INVALID");
        return vectors;
    }

    public void upsertBatch(long companyId, String documentId, List<String> chunkIds,
            List<List<Double>> vectors) throws Exception
    {
        if (chunkIds.size() != vectors.size()) throw new IllegalStateException("KNOWLEDGE_VECTOR_COUNT");
        ensure();
        var body = json.createObjectNode();
        var points = body.putArray("points");
        for (int i = 0; i < chunkIds.size(); i++)
        {
            List<Double> vector = vectors.get(i);
            if (vector == null || vector.size() != properties.getDimension())
                throw new IllegalStateException("EMBEDDING_VECTOR_INVALID");
            var point = points.addObject().put("id", chunkIds.get(i));
            var values = point.putArray("vector");
            vector.forEach(values::add);
            point.putObject("payload").put("company_id", companyId).put("document_id", documentId);
        }
        send("PUT", "/points?wait=true", body);
    }

    public List<Hit> search(long companyId, List<Double> vector, int limit) throws Exception
    {
        ensure();
        var body = json.createObjectNode().put("limit", Math.min(20, Math.max(1, limit)))
                .put("with_payload", false).put("with_vector", false);
        var query = body.putArray("query");
        vector.forEach(query::add);
        var must = body.putObject("filter").putArray("must");
        must.addObject().put("key", "company_id").putObject("match").put("value", companyId);
        JsonNode root = json.readTree(send("POST", "/points/query", body));
        List<Hit> hits = new ArrayList<>();
        for (JsonNode row : root.path("result").path("points"))
        {
            double score = row.path("score").asDouble(-1);
            if (score >= properties.getMinScore()) hits.add(new Hit(row.path("id").asText(), score));
        }
        return hits;
    }

    public void deleteDocument(long companyId, String documentId) throws Exception
    {
        var probe = get("");
        if (probe.statusCode() == 404) return;
        require(probe);
        var body = json.createObjectNode();
        var must = body.putObject("filter").putArray("must");
        must.addObject().put("key", "company_id").putObject("match").put("value", companyId);
        must.addObject().put("key", "document_id").putObject("match").put("value", documentId);
        send("POST", "/points/delete?wait=true", body);
    }

    private synchronized void ensure() throws Exception
    {
        if (ready) return;
        var response = get("");
        if (response.statusCode() == 404)
        {
            var body = json.createObjectNode();
            body.putObject("vectors").put("size", properties.getDimension()).put("distance", "Cosine");
            send("PUT", "", body);
        }
        else
        {
            require(response);
            JsonNode vectors = json.readTree(response.body()).path("result").path("config").path("params").path("vectors");
            if (vectors.path("size").asInt() != properties.getDimension()
                    || !"Cosine".equals(vectors.path("distance").asText()))
                throw new IllegalStateException("KNOWLEDGE_COLLECTION_SCHEMA");
        }
        send("PUT", "/index", json.createObjectNode().put("field_name", "company_id").put("field_schema", "integer"));
        send("PUT", "/index", json.createObjectNode().put("field_name", "document_id").put("field_schema", "keyword"));
        ready = true;
    }

    private HttpResponse<String> get(String suffix) throws Exception
    {
        var uri = URI.create(properties.getQdrantUrl().replaceAll("/$", "") + "/collections/" + collection + suffix);
        var builder = HttpRequest.newBuilder(uri).timeout(Duration.ofSeconds(5))
                .header("Accept", "application/json");
        String key = properties.getQdrantApiKey();
        if (key != null && !key.isBlank())
        {
            if (!"https".equals(uri.getScheme()) && !List.of("127.0.0.1", "localhost", "::1").contains(uri.getHost()))
                throw new IllegalArgumentException("QDRANT_ENDPOINT_TLS");
            builder.header("api-key", key);
        }
        builder.GET();
        return http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }

    private String send(String method, String suffix, ObjectNode body) throws Exception
    {
        var uri = URI.create(properties.getQdrantUrl().replaceAll("/$", "") + "/collections/" + collection + suffix);
        var builder = HttpRequest.newBuilder(uri).timeout(Duration.ofSeconds(5))
                .header("Accept", "application/json").header("Content-Type", "application/json");
        String key = properties.getQdrantApiKey();
        if (key != null && !key.isBlank())
        {
            if (!"https".equals(uri.getScheme()) && !List.of("127.0.0.1", "localhost", "::1").contains(uri.getHost()))
                throw new IllegalArgumentException("QDRANT_ENDPOINT_TLS");
            builder.header("api-key", key);
        }
        builder.method(method, HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)));
        var response = http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
        require(response);
        return response.body();
    }

    private static void require(HttpResponse<?> response)
    {
        int status = response.statusCode();
        if (status < 200 || status >= 300) throw new IllegalStateException("KNOWLEDGE_INDEX_UNAVAILABLE");
    }
}
