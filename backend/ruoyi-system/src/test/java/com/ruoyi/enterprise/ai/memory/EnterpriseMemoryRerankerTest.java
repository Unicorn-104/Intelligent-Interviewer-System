package com.ruoyi.enterprise.ai.memory;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.List;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class EnterpriseMemoryRerankerTest
{
    @Test
    void ranksByScoreAndKeepsTopN() throws Exception
    {
        var json=new ObjectMapper();
        var server=HttpServer.create(new InetSocketAddress("127.0.0.1",0),0);
        server.createContext("/rerank",exchange->{
            var body=json.readTree(exchange.getRequestBody());
            assertEquals("薪资怎么定",body.path("query").asText());
            assertEquals(2,body.path("texts").size());
            var response=json.createArrayNode();
            response.addObject().put("index",1).put("score",0.91);
            response.addObject().put("index",0).put("score",0.12);
            byte[] bytes=json.writeValueAsString(response).getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200,bytes.length);
            exchange.getResponseBody().write(bytes);exchange.close();
        });
        server.start();
        try {
            var properties=new EnterpriseMemoryRerankProperties();
            properties.setEnabled(true);
            properties.setUrl("http://127.0.0.1:"+server.getAddress().getPort()+"/rerank");
            properties.setTopN(1);
            var reranker=new EnterpriseMemoryReranker(properties);
            var ranks=reranker.rank("薪资怎么定",List.of("技术面只做一轮","薪资按岗位预算上限执行"));
            assertEquals(1,ranks.size());
            assertEquals(1,ranks.get(0).index());
            assertEquals(0.91,ranks.get(0).score(),0.0001);
        } finally { server.stop(0); }
    }

    @Test
    void disabledRerankerSkipsNetwork() throws Exception
    {
        var properties=new EnterpriseMemoryRerankProperties();
        var reranker=new EnterpriseMemoryReranker(properties);
        assertFalse(reranker.enabled());
        assertTrue(reranker.rank("q",List.of("a")).isEmpty());
    }
}
