package com.ruoyi.ai.tools.admin;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.util.ReflectionTestUtils;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;
import com.ruoyi.common.exception.ServiceException;

/** Synthetic H2 rows only; no server, business database or real model is used. */
class AdminQuestionDuplicateToolTest
{
    private final ObjectMapper json = new ObjectMapper();
    private final ToolContext ctx = ToolContext.of("admin", "synthetic");
    private JdbcTemplate jdbc;
    private CheckDuplicateQuestionsTool tool;

    @BeforeEach
    void setup()
    {
        var dataSource = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
                + ";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1", "sa", "");
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("CREATE TABLE t_exam_question ("
                + "eqs_id BIGINT PRIMARY KEY, eqs_content VARCHAR(2000), eqs_company_id BIGINT)");
        jdbc.update("INSERT INTO t_exam_question VALUES (1, '下列哪个不是 Java 的基本数据类型？', NULL)");
        jdbc.update("INSERT INTO t_exam_question VALUES (2, '下列哪个不是Java的基本数据类型', NULL)");
        jdbc.update("INSERT INTO t_exam_question VALUES (3, 'HTTP 状态码 404 表示什么？', NULL)");
        jdbc.update("INSERT INTO t_exam_question VALUES (4, 'Spring 默认作用域是？', 81)");
        tool = new CheckDuplicateQuestionsTool();
        ReflectionTestUtils.setField(tool, "jdbc", jdbc);
    }

    @Test
    void contentInputReportsExistingDuplicatesWithoutPending()
    {
        ObjectNode args = json.createObjectNode().put("bankType", "platform");
        args.putArray("contents").add("下列哪个不是 Java 的基本数据类型？");
        ToolResult result = tool.execute(ctx, args);
        assertFalse(result.hasPending());
        assertTrue(result.getText().contains("题库 3 题参与比对"));
        assertTrue(result.getText().contains("疑似重复"));
        assertTrue(result.getText().contains("#1 相似度 100%"));
        assertTrue(result.getText().contains("#2 相似度 100%"));
        assertTrue(result.getText().contains("只读比对，未修改任何题目"));
    }

    @Test
    void idInputExcludesTheCheckedQuestionItself()
    {
        ObjectNode args = json.createObjectNode().put("bankType", "platform");
        args.putArray("ids").add(1L);
        ToolResult result = tool.execute(ctx, args);
        assertTrue(result.getText().contains("#2 相似度 100%"));
        assertFalse(result.getText().contains("#1 相似度"));
    }

    @Test
    void enterpriseScopeIsIsolatedFromPlatform()
    {
        ObjectNode platform = json.createObjectNode().put("bankType", "platform");
        platform.putArray("contents").add("Spring 默认作用域是？");
        assertTrue(tool.execute(ctx, platform).getText().contains("未发现"));

        assertThrows(ServiceException.class, () -> tool.execute(ctx, enterprise(null, "Spring 默认作用域是？")));

        ObjectNode enterprise = enterprise(81L, "Spring 默认作用域是？");
        ToolResult result = tool.execute(ctx, enterprise);
        assertTrue(result.getText().contains("#4 相似度 100%"));
        assertTrue(result.getText().contains("题库 1 题参与比对"));
    }

    @Test
    void thresholdFiltersWeakerMatches()
    {
        ObjectNode loose = enterprise(null, null);
        loose.put("bankType", "platform");
        loose.put("threshold", 0.8);
        loose.putArray("contents").add("下列哪个不是Java的基本数据类型呢");
        assertTrue(tool.execute(ctx, loose).getText().contains("疑似重复"));

        ObjectNode strict = json.createObjectNode().put("bankType", "platform").put("threshold", 0.95);
        strict.putArray("contents").add("下列哪个不是Java的基本数据类型呢");
        assertTrue(tool.execute(ctx, strict).getText().contains("未发现"));
    }

    @Test
    void emptyMissingAndOversizedInputsAreReported()
    {
        assertTrue(tool.execute(ctx, json.createObjectNode().put("bankType", "platform"))
                .getText().contains("请提供待检题干"));

        ObjectNode missing = json.createObjectNode().put("bankType", "platform");
        missing.putArray("ids").add(999L);
        assertTrue(tool.execute(ctx, missing).getText().contains("都不存在"));

        ObjectNode tooMany = json.createObjectNode().put("bankType", "platform");
        ArrayNode contents = tooMany.putArray("contents");
        for (int i = 0; i < 6; i++)
        {
            contents.add("第 " + i + " 条不同内容的题干");
        }
        assertTrue(tool.execute(ctx, tooMany).getText().contains("一次最多检查 5 条"));
    }

    private ObjectNode enterprise(Long companyId, String content)
    {
        ObjectNode args = json.createObjectNode().put("bankType", "enterprise");
        if (companyId != null)
        {
            args.put("companyId", companyId);
        }
        if (content != null)
        {
            args.putArray("contents").add(content);
        }
        return args;
    }
}
