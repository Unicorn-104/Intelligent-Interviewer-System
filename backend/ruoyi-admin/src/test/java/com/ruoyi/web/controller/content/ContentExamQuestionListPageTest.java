package com.ruoyi.web.controller.content;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.h2.jdbcx.JdbcDataSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.util.ReflectionTestUtils;

import com.ruoyi.common.core.page.TableDataInfo;

/** H2 内存库 + 合成题目，验证 JdbcTemplate 列表真实分页与总数。 */
class ContentExamQuestionListPageTest
{
    private ContentExamQuestionController controller;

    @BeforeEach
    void setup()
    {
        JdbcDataSource ds = new JdbcDataSource();
        ds.setURL("jdbc:h2:mem:exam_page_" + UUID.randomUUID().toString().replace("-", "")
                + ";MODE=MySQL;DB_CLOSE_DELAY=-1");
        JdbcTemplate jdbc = new JdbcTemplate(ds);
        jdbc.execute("CREATE TABLE t_exam_question (eqs_id BIGINT PRIMARY KEY, eqs_type INT, "
                + "eqs_type_name VARCHAR(32), eqs_content VARCHAR(255), eqs_options_json CLOB, "
                + "eqs_answer VARCHAR(255), eqs_analysis CLOB, eqs_score DECIMAL(10,2), "
                + "eqs_difficulty INT, eqs_company_id BIGINT, eqs_skill_tag VARCHAR(64), "
                + "eqs_category INT, eqs_created_at TIMESTAMP, eqs_updated_at TIMESTAMP)");
        jdbc.execute("CREATE TABLE t_cmp (cmp_id BIGINT PRIMARY KEY, cmp_name VARCHAR(64))");
        for (int i = 1; i <= 25; i++)
        {
            jdbc.update("INSERT INTO t_exam_question (eqs_id, eqs_type, eqs_type_name, eqs_content, "
                    + "eqs_answer, eqs_score, eqs_difficulty, eqs_category) VALUES (?, 1, '单选', ?, 'A', 2, 1, 1)",
                    i, "题目 " + i);
        }
        controller = new ContentExamQuestionController();
        ReflectionTestUtils.setField(controller, "jdbcTemplate", jdbc);
    }

    @Test
    void listReturnsOnePageAndRealTotal()
    {
        TableDataInfo page1 = controller.list("platform", null, null, null, null, null, 1, 10);
        assertEquals(25L, page1.getTotal());
        assertEquals(10, page1.getRows().size());
        assertEquals(25L, ((Number) ((Map<?, ?>) page1.getRows().get(0)).get("id")).longValue());

        TableDataInfo page3 = controller.list("platform", null, null, null, null, null, 3, 10);
        assertEquals(25L, page3.getTotal());
        assertEquals(5, page3.getRows().size());
        assertEquals(5L, ((Number) ((Map<?, ?>) page3.getRows().get(0)).get("id")).longValue());

        TableDataInfo capped = controller.list("platform", null, null, null, null, null, 1, 999);
        assertEquals(25, capped.getRows().size());
    }

    @Test
    void filtersApplyToBothCountAndRows()
    {
        TableDataInfo empty = controller.list("enterprise", 81L, null, null, null, null, 1, 10);
        assertEquals(0L, empty.getTotal());
        assertTrue(empty.getRows().isEmpty());

        TableDataInfo keyword = controller.list("platform", null, null, null, null, "题目 2", 1, 50);
        assertEquals(7L, keyword.getTotal());
        assertEquals(7, keyword.getRows().size());
        List<?> rows = keyword.getRows();
        rows.forEach(r -> assertTrue(String.valueOf(((Map<?, ?>) r).get("content")).contains("题目 2")));
    }
}
