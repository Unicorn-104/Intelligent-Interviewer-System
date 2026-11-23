package com.ruoyi.enterprise.service;

import java.util.ArrayList;
import java.util.List;

/**
 * 符合 RFC 4180 习惯的 CSV 解析与编码工具（纯逻辑，不依赖 IO，便于单测）。
 *
 * <p>支持：双引号包裹字段、字段内逗号/换行、双引号转义（"" 表示一个引号）；
 * 编码时对含逗号/引号/换行的字段自动加引号。另提供电子表格公式注入防护：
 * 对以 =、+、-、@、制表符、回车开头的单元格前置单引号，避免被 Excel/WPS 当公式执行。</p>
 */
public final class CsvRecords
{
    private CsvRecords() {}

    /** 解析完整 CSV 文本为多行记录；引号内的换行不会错误断行，引号位置非法时抛出异常。 */
    public static List<List<String>> parse(String content)
    {
        List<List<String>> rows = new ArrayList<>();
        List<String> field = new ArrayList<>();
        StringBuilder sb = new StringBuilder();
        boolean inQuotes = false;
        boolean fieldStarted = false;
        boolean rowHasContent = false;

        for (int i = 0; i < content.length(); i++)
        {
            char c = content.charAt(i);
            if (inQuotes)
            {
                if (c == '"')
                {
                    if (i + 1 < content.length() && content.charAt(i + 1) == '"')
                    {
                        sb.append('"');
                        i++;
                    }
                    else
                    {
                        inQuotes = false;
                    }
                }
                else sb.append(c);
                continue;
            }
            if (c == '"')
            {
                if (fieldStarted && sb.length() > 0)
                    throw new IllegalArgumentException("字段中间出现非法引号");
                inQuotes = true;
                fieldStarted = true;
            }
            else if (c == ',')
            {
                field.add(sb.toString());
                sb.setLength(0);
                fieldStarted = false;
                rowHasContent = true;
            }
            else if (c == '\n' || c == '\r')
            {
                // 处理 CRLF：\r 后跟 \n 只算一次行结束
                if (c == '\r' && i + 1 < content.length() && content.charAt(i + 1) == '\n') i++;
                field.add(sb.toString());
                if (rowHasContent || !sb.toString().isEmpty()) rows.add(field);
                field = new ArrayList<>();
                sb.setLength(0);
                fieldStarted = false;
                rowHasContent = false;
            }
            else
            {
                sb.append(c);
                rowHasContent = true;
            }
        }
        if (inQuotes) throw new IllegalArgumentException("存在未闭合的引号字段");
        // 最后一行（无结尾换行）
        field.add(sb.toString());
        if (rowHasContent || field.size() > 1 || !sb.toString().isEmpty()) rows.add(field);
        return rows;
    }

    /** 将一条记录编码为合规 CSV 行（不含结尾换行）。 */
    public static String format(List<String> fields)
    {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < fields.size(); i++)
        {
            if (i > 0) sb.append(',');
            sb.append(escape(fields.get(i) == null ? "" : fields.get(i)));
        }
        return sb.toString();
    }

    /** 对输出到电子表格的文本做公式注入防护，并按 RFC 4180 决定是否加引号。 */
    public static String escape(String value)
    {
        String v = guardFormula(value);
        boolean needQuote = v.indexOf(',') >= 0 || v.indexOf('"') >= 0
                || v.indexOf('\n') >= 0 || v.indexOf('\r') >= 0;
        if (!needQuote) return v;
        return '"' + v.replace("\"", "\"\"") + '"';
    }

    /** 危险公式前缀（= + - @ 制表符 回车）前置单引号，防止电子表格执行。 */
    public static String guardFormula(String value)
    {
        if (value == null || value.isEmpty()) return "";
        char first = value.charAt(0);
        if (first == '=' || first == '+' || first == '-' || first == '@'
                || first == '\t' || first == '\r')
        {
            return "'" + value;
        }
        return value;
    }
}
