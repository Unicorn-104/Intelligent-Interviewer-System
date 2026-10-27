package com.ruoyi.system.service.app.ai;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.system.config.AppAiMemoryVectorProperties;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class QdrantMemoryIndexTest
{
    @Test
    void securedEmbeddingUsesBearerAndPreservesQueryPassageContract() throws Exception
    {
        var json = new ObjectMapper();
        var inputTypes = new ArrayList<String>();
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/embeddings", exchange -> {
            boolean authorized = "Bearer synthetic-embedding-token".equals(exchange.getRequestHeaders().getFirst("Authorization"));
            if (!authorized) { exchange.sendResponseHeaders(401, -1); exchange.close(); return; }
            var body = json.readTree(exchange.getRequestBody());
            inputTypes.add(body.path("input_type").asText());
            byte[] response = ("{\"data\":[{\"embedding\":" + json.writeValueAsString(Collections.nCopies(512, 0.1)) + "}]}")
                    .getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, response.length);
            exchange.getResponseBody().write(response); exchange.close();
        });
        server.start();
        try
        {
            var properties = new AppAiMemoryVectorProperties();
            properties.setEmbeddingUrl("http://127.0.0.1:" + server.getAddress().getPort() + "/v1/embeddings");
            properties.setEmbeddingApiKey("synthetic-embedding-token");
            var index = new QdrantMemoryIndex(properties);
            assertEquals(512, index.embed("合成查询", true).size());
            assertEquals(512, index.embed("合成事实", false).size());
            assertEquals(java.util.List.of("query", "passage"), inputTypes);
            properties.setEmbeddingApiKey("synthetic-wrong-token");
            assertThrows(IllegalStateException.class, () -> index.embed("合成查询", true));
        }
        finally { server.stop(0); }
    }
}
