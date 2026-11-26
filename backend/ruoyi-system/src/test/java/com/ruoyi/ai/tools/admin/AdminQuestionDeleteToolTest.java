package com.ruoyi.ai.tools.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.util.ReflectionTestUtils;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.ai.core.InMemoryAgentActionStore;
import com.ruoyi.ai.core.PendingAction;
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;
import com.ruoyi.common.exception.ServiceException;

/** Synthetic H2 rows only; no server, business database or real model is used. */
class AdminQuestionDeleteToolTest
{
    private final ObjectMapper json = new ObjectMapper();
    private final ToolContext ctx = ToolContext.of("admin", "synthetic");
    private JdbcTemplate jdbc;
    private DeleteQuestionsTool tool;
    private InMemoryAgentActionStore store;

    @BeforeEach
    void setup()
    {
        var dataSource = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
                + ";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1", "sa", "");
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("CREATE TABLE t_exam_question ("
                + "eqs_id BIGINT PRIMARY KEY, eqs_content VARCHAR(2000), eqs_company_id BIGINT)");
        jdbc.execute("CREATE TABLE t_exam_paper_question (epq_question_id BIGINT)");
        jdbc.execute("CREATE TABLE t_exam_answer (ean_question_id BIGINT)");
        jdbc.update("INSERT INTO t_exam_question VALUES (1, '平台题一', NULL)");
        jdbc.update("INSERT INTO t_exam_question VALUES (2, '平台题二', NULL)");
        jdbc.update("INSERT INTO t_exam_question VALUES (3, '企业题', 81)");
        jdbc.update("INSERT INTO t_exam_question VALUES (4, '平台题四', NULL)");
        jdbc.update("INSERT INTO t_exam_paper_question VALUES (2)");
        jdbc.update("INSERT INTO t_exam_answer VALUES (4)");
        tool = new DeleteQuestionsTool();
        ReflectionTestUtils.setField(tool, "jdbc", jdbc);
        store = new InMemoryAgentActionStore();
        ReflectionTestUtils.setField(tool, "actionStore", store);
    }

    @Test
    void platformDeleteWaitsForConfirmationAndConsumesOnce()
    {
        assertTrue(tool.definition(json).toString().contains("delete_questions"));
        ToolResult draft = tool.execute(ctx, args("platform", null, 1));
        assertTrue(draft.hasPending());
        assertEquals(List.of(1L), draft.getPending().get("ids"));
        assertEquals(4, count());
        assertTrue(draft.getText().contains("尚未删除"));

        PendingAction pending = store.take(draft.getPending().id);
        assertNotNull(pending);
        assertNull(store.take(draft.getPending().id));
        Map<String, Object> result = tool.apply(pending, ctx);
        assertEquals(1, result.get("deleted"));
        assertEquals(0, result.get("skipped"));
        assertEquals(3, count());
    }

    @Test
    void referencedQuestionsAreKeptWithoutBlockingOthers()
    {
        ToolResult draft = tool.execute(ctx, args("platform", null, 1, 2, 4));
        assertTrue(draft.hasPending());
        assertEquals(List.of(1L), draft.getPending().get("ids"));
        assertTrue(draft.getText().contains("将保留 2 题"));

        Map<String, Object> result = tool.apply(store.take(draft.getPending().id), ctx);
        assertEquals(1, result.get("deleted"));
        assertEquals(2, result.get("referenced"));
        assertEquals(List.of(1L), result.get("ids"));
        assertEquals(3, count());
        assertEquals(2, jdbc.queryForObject(
                "SELECT COUNT(*) FROM t_exam_question WHERE eqs_id IN (2, 4)", Integer.class));
    }

    @Test
    void allReferencedOrMissingIdsNeverCreatePendingAction()
    {
        ToolResult allReferenced = tool.execute(ctx, args("platform", null, 2, 4));
        assertFalse(allReferenced.hasPending());
        assertTrue(allReferenced.getText().contains("引用"));
        assertEquals(4, count());

        ToolResult missing = tool.execute(ctx, args("platform", null, 999));
        assertFalse(missing.hasPending());
        assertTrue(missing.getText().contains("不存在"));
    }

    @Test
    void enterpriseDeleteRequiresCompanyAndCannotCrossScope()
    {
        ToolResult crossScope = tool.execute(ctx, args("platform", null, 3));
        assertFalse(crossScope.hasPending());
        assertEquals(4, count());

        assertThrows(ServiceException.class, () -> tool.execute(ctx, args("enterprise", null, 3)));

        ToolResult draft = tool.execute(ctx, args("enterprise", 81L, 3));
        assertTrue(draft.hasPending());
        assertEquals(1, tool.apply(store.take(draft.getPending().id), ctx).get("deleted"));
        assertEquals(0, jdbc.queryForObject(
                "SELECT COUNT(*) FROM t_exam_question WHERE eqs_id = 3", Integer.class));
        assertEquals(3, count());
    }

    @Test
    void invalidIdsAndOversizedBatchesAreRejected()
    {
        assertFalse(tool.execute(ctx, args("platform", null)).hasPending());

        ObjectNode tooMany = json.createObjectNode().put("bankType", "platform");
        ArrayNode ids = tooMany.putArray("ids");
        for (int i = 1; i <= 21; i++)
        {
            ids.add(i);
        }
        ToolResult oversized = tool.execute(ctx, tooMany);
        assertFalse(oversized.hasPending());
        assertTrue(oversized.getText().contains("最多删除 20 题"));

        ObjectNode textIds = json.createObjectNode().put("bankType", "platform").put("ids", "1, 999");
        ToolResult mixed = tool.execute(ctx, textIds);
        assertTrue(mixed.hasPending());
        assertTrue(mixed.getText().contains("不存在的题号 1 个"));
    }

    private ObjectNode args(String bankType, Long companyId, long... ids)
    {
        ObjectNode args = json.createObjectNode().put("bankType", bankType);
        if (companyId != null)
        {
            args.put("companyId", companyId);
        }
        if (ids.length > 0)
        {
            ArrayNode array = args.putArray("ids");
            for (long id : ids)
            {
                array.add(id);
            }
        }
        return args;
    }

    private int count()
    {
        return jdbc.queryForObject("SELECT COUNT(*) FROM t_exam_question", Integer.class);
    }
}
