package com.ruoyi.system.domain;

import java.time.Instant;
import java.util.Date;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

import static org.junit.jupiter.api.Assertions.assertEquals;

class ImTimeSerializationTest
{
    private final JsonMapper mapper = JsonMapper.builder().build();

    @Test
    void messageAndSessionUseBeijingTimeInsteadOfDefaultUtc()
    {
        assertTimes("2026-11-02T01:39:00Z", "2026-11-02 09:39:00");
    }

    @Test
    void beijingMidnightUsesTheFollowingCalendarDay()
    {
        assertTimes("2026-11-01T16:00:00Z", "2026-11-02 00:00:00");
    }

    private void assertTimes(String instant, String expected)
    {
        Date timestamp = Date.from(Instant.parse(instant));
        ImMessage message = new ImMessage();
        message.setSendTime(timestamp);
        ImSession session = new ImSession();
        session.setLastMessageAt(timestamp);

        assertEquals(expected, mapper.readTree(mapper.writeValueAsString(message)).get("sendTime").asString());
        assertEquals(expected, mapper.readTree(mapper.writeValueAsString(session)).get("lastMessageAt").asString());
        assertEquals(timestamp, mapper.readValue("{\"sendTime\":\"" + expected + "\"}", ImMessage.class).getSendTime());
    }
}
