package com.ruoyi.enterprise.ai.memory;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.stereotype.Component;

/**
 * Optional cross-encoder reranker. Any failure is local to recall: callers
 * keep the Qdrant order instead of failing the assistant request.
 */
@Component
public class EnterpriseMemoryReranker
{
    public record Rank(int index, double score) { }

    private final EnterpriseMemoryRerankProperties properties;
    private final ObjectMapper json = new ObjectMapper();
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .followRedirects(HttpClient.Redirect.NEVER)
            .build();

    public EnterpriseMemoryReranker(EnterpriseMemoryRerankProperties properties)
    {
        this.properties = properties;
        if (properties.isEnabled())
        {
            var uri = URI.create(properties.getUrl());
            if (!List.of("http", "https").contains(uri.getScheme()) || uri.getHost() == null
                    || uri.getUserInfo() != null || uri.getFragment() != null)
                throw new IllegalArgumentException("ENTERPRISE_MEMORY_RERANK_URL");
        }
    }

    public boolean enabled()
    { return properties.isEnabled() && properties.getUrl() != null && !properties.getUrl().isBlank(); }

    public List<Rank> rank(String query, List<String> texts) throws Exception
    {
        if (!enabled() || query == null || query.isBlank() || texts == null || texts.isEmpty())
            return List.of();
        ObjectNode body = json.createObjectNode().put("query", query).put("raw_scores", false)
                .put("truncate", true);
        ArrayNode values = body.putArray("texts");
        texts.forEach(values::add);
        HttpRequest request = HttpRequest.newBuilder(URI.create(properties.getUrl()))
                .timeout(Duration.ofSeconds(Math.max(1, properties.getTimeoutSeconds())))
                .header("Accept", "application/json")
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)))
                .build();
        HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() < 200 || response.statusCode() >= 300)
            throw new IllegalStateException("RERANK_HTTP_" + response.statusCode());
        JsonNode root = json.readTree(response.body());
        JsonNode rows = root.isArray() ? root : root.path("results");
        if (!rows.isArray()) throw new IllegalStateException("RERANK_RESPONSE_INVALID");
        List<Rank> ranks = new ArrayList<>();
        for (JsonNode row : rows)
        {
            int index = row.path("index").asInt(-1);
            double score = row.has("score") ? row.path("score").asDouble(-1)
                    : row.path("relevance_score").asDouble(-1);
            if (index >= 0 && index < texts.size() && Double.isFinite(score))
                ranks.add(new Rank(index, score));
        }
        ranks.sort(Comparator.comparingDouble(Rank::score).reversed());
        int top = Math.min(Math.max(1, properties.getTopN()), ranks.size());
        return ranks.subList(0, top);
    }
}
