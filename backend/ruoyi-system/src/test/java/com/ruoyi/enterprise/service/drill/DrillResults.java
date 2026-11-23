package com.ruoyi.enterprise.service.drill;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import com.ruoyi.enterprise.service.CsvRecords;

/** 场景结果收集器：内存累积，最终写出场景测试结果 CSV；status 仅允许 PASS/FAIL/BLOCKED/NOT_RUN。 */
final class DrillResults
{
    record Case(String scenario, String testCase, String expected, String actual,
                String status, String evidence, String detail) {}

    static final List<Case> CASES = new ArrayList<>();

    private DrillResults() {}

    static void add(String scenario, String testCase, String expected, String actual,
            String status, String evidence, String detail)
    {
        CASES.add(new Case(scenario, testCase, expected, actual, status, evidence, detail));
    }

    static void pass(String scenario, String testCase, String expected, String actual,
            String evidence, String detail)
    {
        add(scenario, testCase, expected, actual, "PASS", evidence, detail);
    }

    static void fail(String scenario, String testCase, String expected, String actual,
            String evidence, String detail)
    {
        add(scenario, testCase, expected, actual, "FAIL", evidence, detail);
    }

    static void blocked(String scenario, String testCase, String reason)
    {
        add(scenario, testCase, "需真实源表DDL", "未执行", "BLOCKED", "DDL缺失", reason);
    }

    static void writeCsv(Path file) throws Exception
    {
        List<String> lines = new ArrayList<>();
        lines.add(String.join(",", "scenario", "test_case", "expected_result", "actual_result",
                "status", "evidence", "detail"));
        for (Case c : CASES)
        {
            lines.add(CsvRecords.format(List.of(c.scenario(), c.testCase(), c.expected(),
                    c.actual(), c.status(), c.evidence(), c.detail())));
        }
        Files.write(file, lines, StandardCharsets.UTF_8);
    }
}
