package com.ruoyi.system.service.app.knowledge;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.system.config.AppAiMemoryVectorProperties;
import com.ruoyi.system.service.app.ai.QdrantMemoryIndex;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Shares the embedding transport, never the memory collection or its owner-only search filter. */
@Component
public class KnowledgeVectorIndex
{
    public record Hit(String id, double score) { }
    private final AppAiMemoryVectorProperties properties;
    private final QdrantMemoryIndex embeddings;
    private final String collection;
    private final ObjectMapper json = new ObjectMapper();
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3))
            .followRedirects(HttpClient.Redirect.NEVER).build();
    private volatile boolean ready;

    public KnowledgeVectorIndex(AppAiMemoryVectorProperties properties,
            @Value("${app.ai.knowledge.collection:capp_knowledge_bge_small_zh_v1}") String collection)
    {
        this.properties = properties;
        if (!collection.matches("[a-zA-Z0-9_-]{1,100}") || collection.equals(properties.getCollection()))
            throw new IllegalArgumentException("KNOWLEDGE_COLLECTION");
        this.collection = collection;
        var config = new AppAiMemoryVectorProperties();
        config.setEmbeddingUrl(properties.getEmbeddingUrl()); config.setEmbeddingApiKey(properties.getEmbeddingApiKey());
        config.setEmbeddingModel(properties.getEmbeddingModel()); config.setDimension(properties.getDimension());
        config.setRequestTimeoutSeconds(10);
        embeddings = new QdrantMemoryIndex(config);
    }

    public List<Double> embed(String text, boolean query) throws Exception
    {
        var vector = embeddings.embed(text, query);
        if (vector.isEmpty()) throw new IllegalStateException("EMBEDDING_NOT_CONFIGURED");
        return vector;
    }

    public void upsert(String id, long userId, String baseId, String documentId, int revision, List<Double> vector) throws Exception
    {
        ensure();
        var body = json.createObjectNode();
        var point = body.putArray("points").addObject().put("id", id);
        var values = point.putArray("vector"); vector.forEach(values::add);
        point.putObject("payload").put("user_id", userId).put("base_id", baseId)
                .put("document_id", documentId).put("revision", revision);
        send("PUT", "/points?wait=true", body);
    }

    public List<Hit> search(long userId, List<String> bases, List<Double> vector) throws Exception
    {
        ensure();
        var body = json.createObjectNode().put("limit", 20).put("with_payload", false).put("with_vector", false);
        var query = body.putArray("query"); vector.forEach(query::add);
        var must = body.putObject("filter").putArray("must");
        must.addObject().put("key", "user_id").putObject("match").put("value", userId);
        var any = must.addObject().put("key", "base_id").putObject("match").putArray("any");
        bases.forEach(any::add);
        var result = json.readTree(send("POST", "/points/query", body));
        List<Hit> hits = new ArrayList<>();
        for (var row : result.path("result").path("points"))
            if (row.path("score").asDouble() >= properties.getMinScore())
                hits.add(new Hit(row.path("id").asText(), row.path("score").asDouble()));
        return hits;
    }

    public void deleteDocument(long userId, String documentId) throws Exception
    {
        // A 404 means there is no vector data to clean up, not a reason to create a collection.
        var probe = request("GET", "", null);
        if (probe.statusCode() == 404) return;
        require(probe);
        var body = json.createObjectNode();
        var must = body.putObject("filter").putArray("must");
        must.addObject().put("key", "user_id").putObject("match").put("value", userId);
        must.addObject().put("key", "document_id").putObject("match").put("value", documentId);
        send("POST", "/points/delete?wait=true", body);
    }

    private synchronized void ensure() throws Exception
    {
        if (ready) return;
        var response = request("GET", "", null);
        if (response.statusCode() == 404)
        {
            var body = json.createObjectNode();
            body.putObject("vectors").put("size", properties.getDimension()).put("distance", "Cosine");
            send("PUT", "", body);
        }
        else
        {
            require(response);
            var vectors = json.readTree(response.body()).path("result").path("config").path("params").path("vectors");
            if (vectors.path("size").asInt() != properties.getDimension() || !"Cosine".equals(vectors.path("distance").asText()))
                throw new IllegalStateException("COLLECTION_SCHEMA");
        }
        for (String field : List.of("user_id", "base_id", "document_id"))
            send("PUT", "/index", json.createObjectNode().put("field_name", field)
                    .put("field_schema", field.equals("user_id") ? "integer" : "keyword"));
        ready = true;
    }

    private HttpResponse<String> request(String method, String suffix, ObjectNode body) throws Exception
    {
        var uri = URI.create(properties.getQdrantUrl().replaceAll("/$", "") + "/collections/" + collection + suffix);
        var builder = HttpRequest.newBuilder(uri).timeout(Duration.ofSeconds(5)).header("Content-Type", "application/json");
        String key = properties.getQdrantApiKey();
        if (key != null && !key.isBlank())
        {
            if (!"https".equals(uri.getScheme()) && !List.of("127.0.0.1", "localhost", "::1").contains(uri.getHost()))
                throw new IllegalArgumentException("ENDPOINT_TLS");
            builder.header("api-key", key);
        }
        builder.method(method, body == null ? HttpRequest.BodyPublishers.noBody()
                : HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)));
        return http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }
    private String send(String method, String suffix, ObjectNode body) throws Exception
    { var response = request(method, suffix, body); require(response); return response.body(); }
    private void require(HttpResponse<?> response)
    { if (response.statusCode() < 200 || response.statusCode() >= 300) throw new IllegalStateException("KNOWLEDGE_INDEX_UNAVAILABLE"); }
}
