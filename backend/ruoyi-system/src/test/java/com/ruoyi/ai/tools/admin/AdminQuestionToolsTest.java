package com.ruoyi.ai.tools.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.util.ReflectionTestUtils;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.ai.core.InMemoryAgentActionStore;
import com.ruoyi.ai.core.PendingAction;
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;

/** Synthetic H2 data only. No business database or real model is involved. */
class AdminQuestionToolsTest
{
    private final ObjectMapper json = new ObjectMapper();
    private JdbcTemplate jdbc;
    private SearchQuestionsTool search;
    private ClassifyQuestionsTool classify;
    private InMemoryAgentActionStore store;

    @BeforeEach
    void setup()
    {
        var dataSource = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
                + ";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1", "sa", "");
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("CREATE TABLE t_exam_question ("
                + "eqs_id BIGINT PRIMARY KEY, eqs_type INT, eqs_type_name VARCHAR(20), "
                + "eqs_content VARCHAR(500), eqs_category INT, eqs_difficulty INT, eqs_company_id BIGINT)");
        for (int id = 1; id <= 12; id++)
        {
            jdbc.update("INSERT INTO t_exam_question VALUES (?, ?, ?, ?, ?, ?, ?)",
                    id, 1, "单选", "合成题目" + id, 1, 1, null);
        }
        search = new SearchQuestionsTool();
        ReflectionTestUtils.setField(search, "jdbc", jdbc);
        classify = new ClassifyQuestionsTool();
        ReflectionTestUtils.setField(classify, "jdbc", jdbc);
        store = new InMemoryAgentActionStore();
        ReflectionTestUtils.setField(classify, "actionStore", store);
    }

    @Test
    void explicitOldIdsCanBeVerifiedAndClassifiedOutsideLatestWindow()
    {
        ToolContext ctx = ToolContext.of("admin", "synthetic");
        ToolResult latest = search.execute(ctx, json.createObjectNode());
        assertFalse(latest.getText().contains("- #1 ["));
        assertFalse(latest.getText().contains("- #2 ["));
        assertTrue(latest.getText().contains("不能据此判断未列出的题号不存在"));
        assertTrue(search.definition(json).toString().contains("\"ids\""));

        ObjectNode exactArgs = json.createObjectNode();
        exactArgs.set("ids", json.createArrayNode().add(1).add(2));
        ToolResult exact = search.execute(ctx, exactArgs);
        assertTrue(exact.getText().contains("- #1 ["));
        assertTrue(exact.getText().contains("- #2 ["));

        ObjectNode draftArgs = json.createObjectNode();
        draftArgs.set("ids", json.createArrayNode().add(1).add(2));
        draftArgs.put("category", 3);
        ToolResult draft = classify.execute(ctx, draftArgs);
        assertTrue(draft.hasPending());
        assertTrue(draft.getText().contains("将对 2 题"));
        assertTrue(draft.getText().contains("0 个题号不存在"));
        assertEquals(1, categoryOf(1));

        PendingAction pending = store.take(draft.getPending().id);
        assertNotNull(pending);
        Map<String, Object> applied = classify.apply(pending, ctx);
        assertEquals(2, applied.get("updated"));
        assertEquals(3, categoryOf(1));
        assertEquals(3, categoryOf(2));
    }

    @Test
    void mixedIdsReportOnlyActuallyMissingQuestions()
    {
        ObjectNode args = json.createObjectNode();
        args.set("ids", json.createArrayNode().add(1).add(999));
        ToolResult exact = search.execute(ToolContext.of("admin", "synthetic"), args);
        assertTrue(exact.getText().contains("- #1 ["));
        assertTrue(exact.getText().contains("1 个指定题号不存在"));

        args.put("category", 2);
        ToolResult draft = classify.execute(ToolContext.of("admin", "synthetic"), args);
        assertTrue(draft.hasPending());
        assertTrue(draft.getText().contains("将对 1 题"));
        assertTrue(draft.getText().contains("1 个题号不存在"));
        assertEquals(1, categoryOf(1));
    }

    private int categoryOf(long id)
    {
        return jdbc.queryForObject("SELECT eqs_category FROM t_exam_question WHERE eqs_id = ?",
                Integer.class, id);
    }
}
