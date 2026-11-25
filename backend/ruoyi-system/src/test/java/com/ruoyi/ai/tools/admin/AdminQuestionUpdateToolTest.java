package com.ruoyi.ai.tools.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigDecimal;
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
class AdminQuestionUpdateToolTest
{
    private final ObjectMapper json = new ObjectMapper();
    private final ToolContext ctx = ToolContext.of("admin", "synthetic");
    private JdbcTemplate jdbc;
    private UpdateQuestionsTool tool;
    private InMemoryAgentActionStore store;

    @BeforeEach
    void setup()
    {
        var dataSource = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
                + ";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1", "sa", "");
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("CREATE TABLE t_exam_question ("
                + "eqs_id BIGINT PRIMARY KEY, eqs_content VARCHAR(2000), eqs_answer VARCHAR(2000), "
                + "eqs_analysis VARCHAR(10000), eqs_difficulty INT, eqs_score DECIMAL(10,2), eqs_company_id BIGINT)");
        jdbc.update("INSERT INTO t_exam_question VALUES (1, '旧题干', 'A', '旧解析', 1, 2, NULL)");
        jdbc.update("INSERT INTO t_exam_question VALUES (2, '平台题二', 'B', '解析二', 2, 3, NULL)");
        jdbc.update("INSERT INTO t_exam_question VALUES (3, '企业题', 'A', '企业解析', 1, 4, 81)");
        tool = new UpdateQuestionsTool();
        ReflectionTestUtils.setField(tool, "jdbc", jdbc);
        store = new InMemoryAgentActionStore();
        ReflectionTestUtils.setField(tool, "actionStore", store);
    }

    @Test
    void platformUpdateWaitsForConfirmationAndConsumesOnce()
    {
        assertTrue(tool.definition(json).toString().contains("update_questions"));
        assertFalse(tool.definition(json).at(
                "/function/parameters/properties/items/items/properties/id").isMissingNode());
        ObjectNode args = args("platform", null);
        ObjectNode change = addItem(args, 1);
        change.put("content", "新题干");
        change.put("analysis", "新解析");
        change.put("difficulty", 3);
        change.put("score", 5.5);

        ToolResult draft = tool.execute(ctx, args);
        assertTrue(draft.hasPending());
        assertEquals("platform", draft.getPending().get("bankType"));
        assertEquals("旧题干", value(1, "eqs_content"));
        assertEquals(1, ((Number) value(1, "eqs_difficulty")).intValue());

        PendingAction pending = store.take(draft.getPending().id);
        assertNotNull(pending);
        assertNull(store.take(draft.getPending().id));
        Map<String, Object> result = tool.apply(pending, ctx);
        assertEquals(1, result.get("updated"));
        assertEquals(0, result.get("skipped"));
        assertEquals("新题干", value(1, "eqs_content"));
        assertEquals("新解析", value(1, "eqs_analysis"));
        assertEquals("A", value(1, "eqs_answer"));
        assertEquals(3, ((Number) value(1, "eqs_difficulty")).intValue());
        assertEquals(0, new BigDecimal("5.50").compareTo((BigDecimal) value(1, "eqs_score")));
        assertEquals("平台题二", value(2, "eqs_content"));
        assertEquals("企业题", value(3, "eqs_content"));
    }

    @Test
    void enterpriseUpdateRequiresExplicitCompanyAndCannotCrossScope()
    {
        ObjectNode crossScope = args("platform", null);
        addItem(crossScope, 3).put("answer", "C");
        ToolResult rejected = tool.execute(ctx, crossScope);
        assertFalse(rejected.hasPending());
        assertTrue(rejected.getText().contains("指定题库"));
        assertEquals("A", value(3, "eqs_answer"));

        ObjectNode missingCompany = args("enterprise", null);
        addItem(missingCompany, 3).put("answer", "B");
        assertThrows(ServiceException.class, () -> tool.execute(ctx, missingCompany));

        ObjectNode args = args("enterprise", 81L);
        addItem(args, 3).put("answer", "B");
        ToolResult draft = tool.execute(ctx, args);
        assertTrue(draft.hasPending());
        PendingAction pending = store.take(draft.getPending().id);
        assertNotNull(pending);
        assertEquals(1, tool.apply(pending, ctx).get("updated"));
        assertEquals("B", value(3, "eqs_answer"));
        assertEquals("A", value(1, "eqs_answer"));
    }

    @Test
    void invalidOrDuplicateChangesNeverCreatePendingAction()
    {
        ObjectNode invalidDifficulty = args("platform", null);
        addItem(invalidDifficulty, 1).put("difficulty", 4);
        ToolResult result = tool.execute(ctx, invalidDifficulty);
        assertFalse(result.hasPending());
        assertTrue(result.getText().contains("难度取值 1-3"));

        ObjectNode blankContent = args("platform", null);
        addItem(blankContent, 1).put("content", " ");
        assertFalse(tool.execute(ctx, blankContent).hasPending());

        ObjectNode noChanges = args("platform", null);
        addItem(noChanges, 1);
        assertFalse(tool.execute(ctx, noChanges).hasPending());

        ObjectNode duplicate = args("platform", null);
        addItem(duplicate, 1).put("answer", "A");
        addItem(duplicate, 1).put("answer", "B");
        ToolResult duplicated = tool.execute(ctx, duplicate);
        assertFalse(duplicated.hasPending());
        assertTrue(duplicated.getText().contains("重复"));
        assertEquals("旧题干", value(1, "eqs_content"));
        assertEquals("A", value(1, "eqs_answer"));
    }

    private ObjectNode args(String bankType, Long companyId)
    {
        ObjectNode args = json.createObjectNode().put("bankType", bankType);
        if (companyId != null)
        {
            args.put("companyId", companyId);
        }
        return args;
    }

    private ObjectNode addItem(ObjectNode args, long id)
    {
        ArrayNode items = args.withArray("items");
        return items.addObject().put("id", id);
    }

    private Object value(long id, String column)
    {
        return jdbc.queryForObject("SELECT " + column + " FROM t_exam_question WHERE eqs_id = ?",
                Object.class, id);
    }
}
