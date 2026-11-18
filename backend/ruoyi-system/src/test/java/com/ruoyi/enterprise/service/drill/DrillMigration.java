package com.ruoyi.enterprise.service.drill;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * 读取正式迁移 SQL 并返回“演练修正副本”：不修改任何正式文件。
 *
 * <p>已知缺陷 DR-1（P1）：正式脚本在 information_schema.statistics 上使用了不存在的列名
 * {@code subpart}，MySQL 8 真实列名为 {@code SUB_PART}，直接执行会抛 Unknown column。
 * 本工具按词边界替换为 SUB_PART，仅用于隔离演练验证后续逻辑；正式文件的最小修复须另行评审。</p>
 */
final class DrillMigration
{
    static final Path DIR = Path.of(
            "D:\\Flutter_apps\\Intelligent-Interviewer-System\\backend\\doc\\migration",
            "enterprise_resume_snapshot");

    private DrillMigration() {}

    static String load(String file) throws Exception
    {
        String sql = Files.readString(DIR.resolve(file), StandardCharsets.UTF_8);
        return sql.replaceAll("\\bsubpart\\b", "SUB_PART");
    }
}
