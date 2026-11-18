package com.ruoyi.enterprise.service;

import java.util.List;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class CsvRecordsTest
{
    // 1. 最普通的逗号分隔行，含多列
    @Test
    void parsePlainCommaSeparated()
    {
        List<List<String>> rows = CsvRecords.parse("1,2,3\r\n4,5,6");
        assertEquals(2, rows.size());
        assertEquals(List.of("1", "2", "3"), rows.get(0));
        assertEquals(List.of("4", "5", "6"), rows.get(1));
    }

    // 2. 文件名含逗号：整字段用双引号包裹，不能错位
    @Test
    void parseFieldContainingComma()
    {
        List<List<String>> rows = CsvRecords.parse("11,\"张三,Java开发简历.pdf\",7");
        assertEquals(1, rows.size());
        assertEquals(3, rows.get(0).size());
        assertEquals("张三,Java开发简历.pdf", rows.get(0).get(1));
    }

    // 3. 引号内双引号转义（"" 表示一个引号）
    @Test
    void parseEscapedQuotes()
    {
        List<List<String>> rows = CsvRecords.parse("\"a\"\"b,c\"");
        assertEquals(1, rows.size());
        assertEquals("a\"b,c", rows.get(0).get(0));
    }

    // 4. 引号字段内含换行（CRLF），不应错误断行
    @Test
    void parseNewlineInsideQuotes()
    {
        List<List<String>> rows = CsvRecords.parse("\"line1\r\nline2\",x");
        assertEquals(1, rows.size());
        assertEquals("line1\r\nline2", rows.get(0).get(0));
        assertEquals("x", rows.get(0).get(1));
    }

    // 5. 未闭合引号必须报错，不允许静默产出
    @Test
    void throwOnUnclosedQuote()
    {
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> CsvRecords.parse("\"abc,1"));
        assertTrue(ex.getMessage().contains("未闭合"));
    }

    // 6. 引号字段闭合后再次出现引号（字段中间非法引号）必须报错
    @Test
    void throwOnIllegalQuote()
    {
        assertThrows(IllegalArgumentException.class, () -> CsvRecords.parse("\"abc\"x\""));
    }

    // 7. 空字段与尾部空列保留
    @Test
    void preserveEmptyFields()
    {
        List<List<String>> rows = CsvRecords.parse("a,,c,");
        assertEquals(List.of("a", "", "c", ""), rows.get(0));
    }

    // 8. 公式注入：危险前缀前置单引号
    @Test
    void guardFormulaPrefixes()
    {
        assertEquals("'=1+1", CsvRecords.guardFormula("=1+1"));
        assertEquals("'+1", CsvRecords.guardFormula("+1"));
        assertEquals("'-1", CsvRecords.guardFormula("-1"));
        assertEquals("'@cmd", CsvRecords.guardFormula("@cmd"));
        assertEquals("'\t1", CsvRecords.guardFormula("\t1"));
        assertEquals("'\r1", CsvRecords.guardFormula("\r1"));
        // 普通文本不被改动
        assertEquals("normal", CsvRecords.guardFormula("normal"));
    }

    // 9. 含逗号/引号的字段编码后再解析，内容往返一致
    @Test
    void formatThenParseRoundTrip()
    {
        List<String> original = List.of("11", "张三,简历.pdf", "say\"hi", "plain");
        String line = CsvRecords.format(original);
        List<List<String>> rows = CsvRecords.parse(line);
        assertEquals(original, rows.get(0));
    }

    // 10. 编码输出对危险公式做了防护，且整体仍可被正确解析
    @Test
    void escapeFormulaAndStillParsable()
    {
        String line = CsvRecords.format(List.of("=HYPERLINK(\"x\")", "ok"));
        List<List<String>> rows = CsvRecords.parse(line);
        assertEquals("'=HYPERLINK(\"x\")", rows.get(0).get(0));
        assertEquals("ok", rows.get(0).get(1));
    }

    // 11. 纯空行不计入记录；CRLF 与 LF 都能正确分行
    @Test
    void ignoreBlankLinesAndMixedLineEndings()
    {
        List<List<String>> rows = CsvRecords.parse("a,b\r\n\r\nc,d\n");
        assertEquals(2, rows.size());
        assertEquals(List.of("a", "b"), rows.get(0));
        assertEquals(List.of("c", "d"), rows.get(1));
    }
}
