package com.ruoyi.system.service.app.ai;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.config.AppAiMemoryVectorProperties;
import org.springframework.stereotype.Component;

/** Qdrant REST adapter. It stores vectors and owner-filter metadata, never memory text. */
@Component
public class QdrantMemoryIndex
{
    public record Hit(String id, double score) { }
    private final AppAiMemoryVectorProperties properties;
    private final ObjectMapper json = new ObjectMapper();
    private final HttpClient http;
    private volatile boolean collectionReady;

    public QdrantMemoryIndex(AppAiMemoryVectorProperties properties)
    {
        this.properties = properties;
        validateBase(properties.getQdrantUrl(), properties.getQdrantApiKey());
        if (properties.getEmbeddingUrl() != null && !properties.getEmbeddingUrl().isBlank())
            validateBase(properties.getEmbeddingUrl(), properties.getEmbeddingApiKey());
        if (properties.getDimension() < 32 || properties.getDimension() > 8192)
            throw new IllegalArgumentException("AI memory vector dimension is invalid");
        http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(properties.getConnectTimeoutSeconds()))
                .followRedirects(HttpClient.Redirect.NEVER).build();
    }

    public List<Double> embed(String text, boolean query) throws Exception
    {
        if (!properties.isConfigured()) return List.of();
        ObjectNode body = json.createObjectNode().put("model", properties.getEmbeddingModel())
                .put("input_type", query ? "query" : "passage");
        body.putArray("input").add(text);
        JsonNode root = json.readTree(send("POST", properties.getEmbeddingUrl(), body,
                properties.getEmbeddingApiKey(), "Authorization", 200));
        JsonNode vector = root.path("data").path(0).path("embedding");
        if (!vector.isArray() || vector.size() != properties.getDimension())
            throw new IllegalStateException("EMBEDDING_DIMENSION_MISMATCH");
        List<Double> result = new ArrayList<>(vector.size());
        for (JsonNode value : vector)
        {
            if (!value.isNumber() || !Double.isFinite(value.asDouble()))
                throw new IllegalStateException("EMBEDDING_VECTOR_INVALID");
            result.add(value.asDouble());
        }
        return result;
    }

    public void upsert(String id, long userId, String memoryType, long revision, List<Double> vector) throws Exception
    {
        if (vector == null || vector.size() != properties.getDimension())
            throw new IllegalStateException("EMBEDDING_VECTOR_INVALID");
        ensureCollection();
        ObjectNode point = json.createObjectNode().put("id", id);
        ArrayNode values = point.putArray("vector");
        vector.forEach(values::add);
        point.putObject("payload").put("user_id", userId).put("status", "ACTIVE")
                .put("memory_type", memoryType).put("revision", revision);
        ObjectNode body = json.createObjectNode();
        body.putArray("points").add(point);
        send("PUT", collectionUrl() + "/points?wait=true", body, properties.getQdrantApiKey(), 200, 201);
    }

    public List<Hit> search(long userId, List<Double> vector, int limit) throws Exception
    {
        ensureCollection();
        ObjectNode body = json.createObjectNode();
        ArrayNode values = json.createArrayNode();
        vector.forEach(values::add);
        body.set("query", values);
        body.put("limit", Math.min(10, Math.max(1, limit)));
        body.put("with_payload", false);
        body.put("with_vector", false);
        ObjectNode filter = body.putObject("filter");
        ArrayNode must = filter.putArray("must");
        ObjectNode owner = must.addObject().put("key", "user_id");
        owner.putObject("match").put("value", userId);
        must.addObject().put("key", "status").putObject("match").put("value", "ACTIVE");
        JsonNode root = json.readTree(send("POST", collectionUrl() + "/points/query", body,
                properties.getQdrantApiKey(), 200));
        List<Hit> hits = new ArrayList<>();
        for (JsonNode row : root.path("result").path("points"))
        {
            String id = row.path("id").asText();
            double score = row.path("score").asDouble(-1);
            if (id.matches("[0-9a-fA-F-]{36}") && score >= properties.getMinScore()) hits.add(new Hit(id, score));
        }
        return hits;
    }

    public void delete(String id) throws Exception
    {
        if (!collectionReady && !collectionExists()) return;
        ObjectNode body = json.createObjectNode();
        body.putArray("points").add(id);
        send("POST", collectionUrl() + "/points/delete?wait=true", body, properties.getQdrantApiKey(), 200, 202);
    }

    private synchronized void ensureCollection() throws Exception
    {
        if (collectionReady) return;
        if (!collectionExists())
        {
            ObjectNode body = json.createObjectNode();
            body.putObject("vectors").put("size", properties.getDimension()).put("distance", "Cosine");
            send("PUT", collectionUrl(), body, properties.getQdrantApiKey(), 200, 201);
        }
        index("user_id", "integer");
        index("status", "keyword");
        index("memory_type", "keyword");
        collectionReady = true;
    }

    private boolean collectionExists() throws Exception
    {
        HttpResponse<String> response = request(collectionUrl(), null, properties.getQdrantApiKey());
        if (response.statusCode() == 404) return false;
        require(response, 200);
        JsonNode root = json.readTree(response.body());
        int dimension = root.path("result").path("config").path("params").path("vectors").path("size").asInt(-1);
        String distance = root.path("result").path("config").path("params").path("vectors").path("distance").asText();
        if (dimension != properties.getDimension() || !"Cosine".equalsIgnoreCase(distance))
            throw new IllegalStateException("QDRANT_COLLECTION_SCHEMA_MISMATCH");
        return true;
    }

    private void index(String field, String type) throws Exception
    {
        ObjectNode body = json.createObjectNode().put("field_name", field).put("field_schema", type);
        send("PUT", collectionUrl() + "/index", body, properties.getQdrantApiKey(), 200, 202);
    }

    private String collectionUrl()
    { return properties.getQdrantUrl().replaceAll("/$", "") + "/collections/" + properties.getCollection(); }

    private String send(String method, String url, ObjectNode body, String key, int... allowed) throws Exception
    { return send(method, url, body, key, "api-key", allowed); }

    private String send(String method, String url, ObjectNode body, String key, String authHeader, int... allowed) throws Exception
    {
        HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(properties.getRequestTimeoutSeconds())).header("Accept", "application/json")
                .header("Content-Type", "application/json");
        if (key != null && !key.isBlank())
            builder.header(authHeader, "Authorization".equals(authHeader) ? "Bearer " + key : key);
        builder.method(method, HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)));
        HttpResponse<String> response = http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
        require(response, allowed);
        return response.body();
    }

    private HttpResponse<String> request(String url, String body, String key) throws Exception
    {
        HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(properties.getRequestTimeoutSeconds())).header("Accept", "application/json");
        if (key != null && !key.isBlank()) builder.header("api-key", key);
        if (body == null) builder.GET();
        else builder.header("Content-Type", "application/json").POST(HttpRequest.BodyPublishers.ofString(body));
        return http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }

    private static void require(HttpResponse<?> response, int... allowed)
    {
        for (int code : allowed) if (response.statusCode() == code) return;
        throw new IllegalStateException("QDRANT_HTTP_" + response.statusCode());
    }

    private static void validateBase(String value, String key)
    {
        URI uri = URI.create(value);
        if (!List.of("http", "https").contains(uri.getScheme()) || uri.getHost() == null
                || uri.getUserInfo() != null || uri.getFragment() != null)
            throw new IllegalArgumentException("AI memory endpoint is invalid");
        boolean loopback = "localhost".equalsIgnoreCase(uri.getHost()) || "127.0.0.1".equals(uri.getHost())
                || "::1".equals(uri.getHost());
        if (!"https".equalsIgnoreCase(uri.getScheme()) && !loopback && key != null && !key.isBlank())
            throw new IllegalArgumentException("AI memory API keys require HTTPS outside loopback");
    }
}
