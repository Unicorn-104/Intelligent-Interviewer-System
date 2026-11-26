package com.ruoyi.enterprise.ai.memory;

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
import org.springframework.stereotype.Component;

/**
 * Company/user-scoped Qdrant index for recruiter long-term facts. The index
 * stores only vectors and filter metadata; MySQL remains authoritative for
 * fact text, evidence and deletion state.
 */
@Component
public class EnterpriseMemoryVectorIndex
{
    public record Hit(String id, double score) { }
    public record Point(String id, long userId, String memoryType, String status, List<Double> vector) { }

    private final AppAiMemoryVectorProperties vectorProperties;
    private final QdrantMemoryIndex embeddings;
    private final EnterpriseMemoryProperties memoryProperties;
    private final String collection;
    private final ObjectMapper json = new ObjectMapper();
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3))
            .followRedirects(HttpClient.Redirect.NEVER).build();
    private volatile boolean ready;

    public EnterpriseMemoryVectorIndex(AppAiMemoryVectorProperties vectorProperties,
            QdrantMemoryIndex embeddings, EnterpriseMemoryProperties memoryProperties)
    {
        this.vectorProperties = vectorProperties;
        this.embeddings = embeddings;
        this.memoryProperties = memoryProperties;
        this.collection = memoryProperties.getCollection();
        if (!collection.matches("[a-zA-Z0-9_-]{1,100}") || collection.equals(vectorProperties.getCollection()))
            throw new IllegalArgumentException("ENTERPRISE_MEMORY_COLLECTION");
    }

    public boolean configured()
    { return vectorProperties.isConfigured() && memoryProperties.isEnabled(); }

    public List<Double> embedQuery(String text) throws Exception
    {
        var vector = embeddings.embed(text, true);
        if (vector.isEmpty()) throw new IllegalStateException("EMBEDDING_NOT_CONFIGURED");
        return vector;
    }

    public List<List<Double>> embedPassages(List<String> texts) throws Exception
    {
        var vectors = embeddings.embedBatch(texts, false);
        if (vectors.size() != texts.size()) throw new IllegalStateException("EMBEDDING_RESPONSE_INVALID");
        return vectors;
    }

    public void upsertBatch(long companyId, List<Point> points) throws Exception
    {
        if (points == null || points.isEmpty()) return;
        ensure();
        var body = json.createObjectNode();
        var rows = body.putArray("points");
        for (Point point : points)
        {
            if (point.vector() == null || point.vector().size() != vectorProperties.getDimension())
                throw new IllegalStateException("EMBEDDING_VECTOR_INVALID");
            var row = rows.addObject().put("id", point.id());
            var values = row.putArray("vector");
            point.vector().forEach(values::add);
            row.putObject("payload")
                    .put("company_id", companyId)
                    .put("user_id", point.userId())
                    .put("memory_type", point.memoryType())
                    .put("status", point.status());
        }
        send("PUT", "/points?wait=true", body);
    }

    public void upsert(long companyId, Point point) throws Exception
    { upsertBatch(companyId, List.of(point)); }

    public List<Hit> search(long companyId, long userId, List<Double> vector, int limit) throws Exception
    {
        if (vector == null || vector.isEmpty()) return List.of();
        ensure();
        int size = Math.min(50, Math.max(1, limit));
        var body = json.createObjectNode().put("limit", size)
                .put("with_payload", false).put("with_vector", false);
        var query = body.putArray("query");
        vector.forEach(query::add);
        var must = body.putObject("filter").putArray("must");
        must.addObject().put("key", "company_id").putObject("match").put("value", companyId);
        must.addObject().put("key", "user_id").putObject("match").put("value", userId);
        must.addObject().put("key", "status").putObject("match").put("value", "ACTIVE");
        JsonNode root = json.readTree(send("POST", "/points/query", body));
        List<Hit> hits = new ArrayList<>();
        for (JsonNode row : root.path("result").path("points"))
        {
            String id = row.path("id").asText();
            double score = row.path("score").asDouble(-1);
            if (id.matches("[0-9a-fA-F-]{36}") && score >= vectorProperties.getMinScore())
                hits.add(new Hit(id, score));
        }
        return hits;
    }

    public void deleteFact(long companyId, long userId, String id) throws Exception
    {
        if (!ensureExists()) return;
        var body = json.createObjectNode();
        var must = body.putObject("filter").putArray("must");
        must.addObject().put("key", "company_id").putObject("match").put("value", companyId);
        must.addObject().put("key", "user_id").putObject("match").put("value", userId);
        var ids = must.addObject().putArray("has_id");
        ids.add(id);
        send("POST", "/points/delete?wait=true", body);
    }

    public void deleteAll(long companyId, long userId) throws Exception
    {
        if (!ensureExists()) return;
        var body = json.createObjectNode();
        var must = body.putObject("filter").putArray("must");
        must.addObject().put("key", "company_id").putObject("match").put("value", companyId);
        must.addObject().put("key", "user_id").putObject("match").put("value", userId);
        send("POST", "/points/delete?wait=true", body);
    }

    /** Exact point count for the user, or -1 when Qdrant is unavailable. */
    public long count(long companyId, long userId)
    {
        try
        {
            if (!ensureExists()) return 0;
            var body = json.createObjectNode().put("exact", true);
            var must = body.putObject("filter").putArray("must");
            must.addObject().put("key", "company_id").putObject("match").put("value", companyId);
            must.addObject().put("key", "user_id").putObject("match").put("value", userId);
            JsonNode root = json.readTree(send("POST", "/points/count", body));
            return root.path("result").path("count").asLong(-1);
        }
        catch(Exception error) { return -1; }
    }

    private synchronized void ensure() throws Exception
    {
        if (ready) return;
        if (ensureExists()) validate();
        else
        {
            var body = json.createObjectNode();
            body.putObject("vectors").put("size", vectorProperties.getDimension()).put("distance", "Cosine");
            send("PUT", "", body);
        }
        send("PUT", "/index", json.createObjectNode().put("field_name", "company_id").put("field_schema", "integer"));
        send("PUT", "/index", json.createObjectNode().put("field_name", "user_id").put("field_schema", "integer"));
        send("PUT", "/index", json.createObjectNode().put("field_name", "memory_type").put("field_schema", "keyword"));
        send("PUT", "/index", json.createObjectNode().put("field_name", "status").put("field_schema", "keyword"));
        ready = true;
    }

    private boolean ensureExists() throws Exception
    {
        HttpResponse<String> response = get("");
        if (response.statusCode() == 404) return false;
        require(response);
        return true;
    }

    private void validate() throws Exception
    {
        HttpResponse<String> response = get("");
        require(response);
        JsonNode vectors = json.readTree(response.body()).path("result").path("config").path("params").path("vectors");
        if (vectors.path("size").asInt() != vectorProperties.getDimension()
                || !"Cosine".equalsIgnoreCase(vectors.path("distance").asText()))
            throw new IllegalStateException("ENTERPRISE_MEMORY_COLLECTION_SCHEMA");
    }

    private HttpResponse<String> get(String suffix) throws Exception
    { return request("GET", suffix, null); }

    private String send(String method, String suffix, ObjectNode body) throws Exception
    {
        var response = request(method, suffix, body);
        require(response);
        return response.body();
    }

    private HttpResponse<String> request(String method, String suffix, ObjectNode body) throws Exception
    {
        var uri = URI.create(vectorProperties.getQdrantUrl().replaceAll("/$", "")
                + "/collections/" + collection + suffix);
        var builder = HttpRequest.newBuilder(uri)
                .timeout(Duration.ofSeconds(vectorProperties.getRequestTimeoutSeconds()))
                .header("Accept", "application/json");
        String key = vectorProperties.getQdrantApiKey();
        if (key != null && !key.isBlank())
        {
            boolean loopback = List.of("127.0.0.1", "localhost", "::1").contains(uri.getHost());
            if (!"https".equalsIgnoreCase(uri.getScheme()) && !loopback)
                throw new IllegalArgumentException("ENTERPRISE_MEMORY_QDRANT_TLS");
            builder.header("api-key", key);
        }
        if (body == null) builder.GET();
        else builder.header("Content-Type", "application/json")
                .method(method, HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)));
        return http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }

    private static void require(HttpResponse<?> response)
    {
        int status = response.statusCode();
        if (status < 200 || status >= 300) throw new IllegalStateException("ENTERPRISE_MEMORY_INDEX_" + status);
    }
}
