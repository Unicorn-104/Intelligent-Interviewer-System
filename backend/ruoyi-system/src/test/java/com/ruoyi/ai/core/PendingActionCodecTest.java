package com.ruoyi.ai.core;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

/** 草稿编解码：Long 不能被 JSON 化成 Integer，否则 apply 时强转会失败。 */
class PendingActionCodecTest
{
    @Test
    void roundTripKeepsTypes()
    {
        PendingAction action = new PendingAction()
                .put("ids", List.of(11L, 22L))
                .put("companyId", 81L)
                .put("threshold", 0.8D)
                .put("items", List.of(Map.of("content", "题干", "score", 2L)));
        action.scope = "admin";
        action.kind = "delete";
        action.title = "删除题目";
        action.operator = "admin";
        action.expireAt = 123456789L;

        String text = PendingActionCodec.encode(action);
        PendingAction back = PendingActionCodec.decode(text);

        assertEquals("admin", back.scope);
        assertEquals("delete", back.kind);
        assertEquals(List.of(11L, 22L), back.get("ids"));
        assertEquals(81L, ((Number) back.get("companyId")).longValue());
        assertEquals(0.8D, ((Number) back.get("threshold")).doubleValue());
        assertEquals(2L, ((Number) ((Map<?, ?>) ((List<?>) back.get("items")).get(0)).get("score")).longValue());
    }

    @Test
    void invalidPayloadDecodesToNull()
    {
        assertNull(PendingActionCodec.decode(null));
        assertNull(PendingActionCodec.decode(""));
        assertNull(PendingActionCodec.decode("not-a-valid-draft"));
    }

    @Test
    void idIsNotTrustedFromOutside()
    {
        PendingAction action = new PendingAction();
        String text = PendingActionCodec.encode(action);
        assertTrue(text.length() > 0);
        assertNull(action.id);
    }
}
