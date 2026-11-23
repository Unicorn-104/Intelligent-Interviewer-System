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
class AdminQuestionDetailToolTest
{
    private final ObjectMapper json = new ObjectMapper();
    private final ToolContext ctx = ToolContext.of("admin", "synthetic");
    private JdbcTemplate jdbc;
    private GetQuestionDetailTool tool;

    @BeforeEach
    void setup()
    {
        var dataSource = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
                + ";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1", "sa", "");
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("CREATE TABLE t_exam_question ("
                + "eqs_id BIGINT PRIMARY KEY, eqs_type INT, eqs_type_name VARCHAR(20), eqs_category INT, "
                + "eqs_content VARCHAR(2000), eqs_options_json VARCHAR(2000), eqs_answer VARCHAR(2000), "
                + "eqs_analysis VARCHAR(2000), eqs_difficulty INT, eqs_score DECIMAL(5,2), "
                + "eqs_skill_tag VARCHAR(100), eqs_company_id BIGINT)");
        jdbc.update("INSERT INTO t_exam_question VALUES (1, 1, '单选', 2, '下列哪个不是 Java 的基本数据类型？', "
                + "'[\"int\", \"String\", \"double\", \"boolean\"]', 'B', 'String 是引用类型。', 1, 5.00, "
                + "'Java基础', NULL)");
        jdbc.update("INSERT INTO t_exam_question VALUES (2, 4, '简答', 3, '简述 synchronized 与 ReentrantLock 的区别。', "
                + "NULL, '前者是关键字，后者是 JUC 下的类。', '可从公平锁与可中断两点展开。', 2, 20.00, NULL, NULL)");
        jdbc.update("INSERT INTO t_exam_question VALUES (3, 1, '单选', 1, '企业题：Spring 默认作用域？', "
                + "'[\"singleton\", \"prototype\"]', 'A', NULL, 1, 4.00, NULL, 81)");
        jdbc.update("INSERT INTO t_exam_question VALUES (4, 3, '判断', 5, '存量题：选项不是 JSON。', "
                + "'正确/错误', '错', NULL, 1, 2.00, NULL, NULL)");
        tool = new GetQuestionDetailTool();
        ReflectionTestUtils.setField(tool, "jdbc", jdbc);
    }

    @Test
    void platformDetailExposesAnswerOptionsAndScore()
    {
        ToolResult result = tool.execute(ctx, args("platform", null, 1));
        String text = result.getText();
        assertFalse(result.hasPending());
        assertTrue(text.contains("#1 [单选"));
        assertTrue(text.contains("题干：下列哪个不是 Java 的基本数据类型"));
        assertTrue(text.contains("选项：A. int | B. String | C. double | D. boolean"));
        assertTrue(text.contains("答案：B"));
        assertTrue(text.contains("解析：String 是引用类型"));
        assertTrue(text.contains("难度1"));
        assertTrue(text.contains("5.00分"));
        assertTrue(text.contains("技能标签：Java基础"));
    }

    @Test
    void nonJsonOptionsFallBackToRawText()
    {
        ToolResult result = tool.execute(ctx, args("platform", null, 4));
        assertTrue(result.getText().contains("选项：正确/错误"));
    }

    @Test
    void enterpriseDetailRequiresCompanyAndCannotCrossScope()
    {
        ToolResult platform = tool.execute(ctx, args("platform", null, 3));
        assertTrue(platform.getText().contains("都不存在"));

        assertThrows(ServiceException.class, () -> tool.execute(ctx, args("enterprise", null, 3)));

        ToolResult enterprise = tool.execute(ctx, args("enterprise", 81L, 3));
        assertTrue(enterprise.getText().contains("企业题：Spring 默认作用域"));
        assertTrue(enterprise.getText().contains("归属企业：81"));
        assertFalse(enterprise.getText().contains("#1 ["));
    }

    @Test
    void missingIdsAreReportedWithoutLosingFoundRows()
    {
        ToolResult result = tool.execute(ctx, args("platform", null, 1, 999));
        assertTrue(result.getText().contains("有 1 个题号不存在"));
        assertTrue(result.getText().contains("#1 [单选"));
        assertFalse(result.getText().contains("#999"));
    }

    @Test
    void emptyOrOversizedIdListsAreRejected()
    {
        assertTrue(tool.execute(ctx, args("platform", null)).getText().contains("请提供要查看的题号"));

        ObjectNode tooMany = json.createObjectNode().put("bankType", "platform");
        ArrayNode ids = tooMany.putArray("ids");
        for (int i = 1; i <= 6; i++)
        {
            ids.add(i);
        }
        assertTrue(tool.execute(ctx, tooMany).getText().contains("一次最多查看 5 题"));
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
}
