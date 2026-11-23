package com.ruoyi.enterprise.service;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.Outcome;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.SourceFile;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.SourcePdfReader;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.EnterprisePdfTarget;
import com.ruoyi.system.service.app.pdf.ResumePdfStorage;
import com.ruoyi.system.service.storage.S3FileStorage;

/**
 * 历史投递 PDF 迁移命令行入口。
 *
 * <p><b>启动连库结论（静态核查）：</b>本类是 {@link CommandLineRunner}，运行 {@code ruoyi-admin.jar}
 * 会初始化完整 Spring Boot 容器——Druid 数据源 {@code initialSize=5} 在启动阶段即向配置库建立连接，
 * ruoyi-quartz 调度器与 Redis 也随容器启动。即使本 Runner 默认禁用，也无法阻止容器本身连库。
 * 因此<b>禁止在能访问生产库的环境直接用该 jar 运行迁移</b>；必须先按隔离方案执行
 * （独立数据源指向隔离库 + 主机网络隔离，详见交付报告），本类不提供可直接连生产的运行命令。</p>
 *
 * <p>双保险：默认禁用（{@code enterprise.migration.historical-resume.enabled=false}），
 * 且 dry-run 默认 true（{@code ...dry-run=true}，只读不写）。源读取只读、企业写入仅发生在
 * 独立命名空间且 CREATE_NEW 不覆盖。清单逐行校验 companyId/appId/sourceRef 等关键字段。
 * 核心逻辑由 {@link HistoricalResumePdfMigrator} 的 Mockito 单测覆盖，本类本轮<b>不运行</b>。</p>
 */
@Component
public class HistoricalResumeMigrationConsole implements CommandLineRunner
{
    private static final Logger log = LoggerFactory.getLogger(HistoricalResumeMigrationConsole.class);

    private final ResumePdfStorage resumePdfStorage;
    private final EnterpriseResumeStorage enterpriseStorage;

    @Value("${enterprise.migration.historical-resume.enabled:false}")
    private boolean enabled;

    /** dry-run 默认开启：只读源并输出计划，不写企业对象；需显式设 false 才会真实写入 */
    @Value("${enterprise.migration.historical-resume.dry-run:true}")
    private boolean dryRun;

    public HistoricalResumeMigrationConsole(ResumePdfStorage resumePdfStorage,
            EnterpriseResumeStorage enterpriseStorage)
    {
        this.resumePdfStorage = resumePdfStorage;
        this.enterpriseStorage = enterpriseStorage;
    }

    @Override
    public void run(String... args) throws Exception
    {
        if (!enabled)
        {
            log.debug("历史 PDF 迁移未启用，跳过。需显式设置 enterprise.migration.historical-resume.enabled=true");
            return;
        }
        String manifest = argValue(args, "manifest");
        if (manifest == null) throw new IllegalStateException("缺少 --manifest=<迁移清单CSV路径>");
        String outputArg = argValue(args, "output-dir");
        Path outputDir = Path.of(outputArg == null
                ? Path.of(manifest).toAbsolutePath().getParent().toString() : outputArg);
        Files.createDirectories(outputDir);

        List<SourceFile> sources = parseManifest(Path.of(manifest));
        List<Outcome> outcomes = new ArrayList<>();

        SourcePdfReader sourceReader = buildSourceReader();
        EnterprisePdfTarget target = buildTarget();
        FileMigrationRecordStore recordStore =
                new FileMigrationRecordStore(outputDir.resolve("migration_records.csv"));
        HistoricalResumePdfMigrator migrator =
                new HistoricalResumePdfMigrator(sourceReader, target, recordStore);

        for (SourceFile source : sources)
        {
            // dry-run 走只读 plan（不写企业对象、不写迁移记录）；真实运行才走 migrateOne
            Outcome outcome = dryRun ? migrator.plan(source) : migrator.migrateOne(source);
            outcomes.add(outcome);
            log.info("历史 PDF {}-{} appId={} status={} detail={}",
                    dryRun ? "dry-run" : "迁移", dryRun ? "只读" : "写入",
                    outcome.appId(), outcome.status(), outcome.detail());
        }

        // 14 列文件验证清单：真实读取源/目标字节，反映真实文件证据（两种模式都生成）
        PdfFileVerification verification = new PdfFileVerification(sourceReader, target, recordStore);
        List<PdfFileVerification.VerificationRow> verificationRows = new ArrayList<>();
        for (SourceFile source : sources) verificationRows.add(verification.verify(source));
        writeVerificationManifest(outputDir.resolve(dryRun
                ? "dry_run_file_verification_manifest.csv"
                : "migration_file_verification_manifest.csv"), verificationRows);

        writeResultCsv(outputDir.resolve(dryRun ? "dry_run_result.csv" : "migration_result.csv"), outcomes);
        writeManualReview(outputDir.resolve("manual_review.csv"), sources, outcomes, verificationRows);
        // dry-run 无任何写入，不生成状态回写 SQL
        if (!dryRun)
        {
            writeStatusUpdateSql(outputDir.resolve("06_update_snapshot_status.sql"),
                    sources, verificationRows);
        }
        log.info("历史 PDF {} 处理完成：共 {} 条，结果见 {}",
                dryRun ? "dry-run 只读预检" : "迁移", outcomes.size(), outputDir);
    }

    private HistoricalResumePdfMigrator.SourcePdfReader buildSourceReader()
    {
        return (sourceResumeId, ref) ->
        {
            long ownerUserId = extractOwnerUserId(ref);
            try (InputStream in = resumePdfStorage.readResource(ownerUserId, ref).getInputStream())
            {
                return in.readAllBytes();
            }
            catch (ServiceException error)
            {
                // 仅明确 Not Found（404）按“源缺失”返回 null；403/超时/5xx 抛异常进 MANUAL_REVIEW
                if (isNotFound(error)) return null;
                throw new IllegalStateException("读取源 PDF 失败", error);
            }
            catch (IOException error)
            {
                throw new IllegalStateException("读取源 PDF 失败", error);
            }
        };
    }

    private HistoricalResumePdfMigrator.EnterprisePdfTarget buildTarget()
    {
        return new HistoricalResumePdfMigrator.EnterprisePdfTarget()
        {
            @Override
            public EnterpriseResumeStorage.StoredPdf store(long companyId, long appId, byte[] bytes,
                    String originalName)
            {
                return enterpriseStorage.store(companyId, appId, bytes, originalName);
            }

            @Override
            public byte[] readBack(String targetRef)
            {
                try (InputStream in = enterpriseStorage.read(targetRef).getInputStream())
                {
                    return in.readAllBytes();
                }
                catch (ServiceException error)
                {
                    // 仅明确 Not Found（404）返回 null 表示目标不存在；其他错误抛异常
                    if (isNotFound(error)) return null;
                    throw new IllegalStateException("读回企业 PDF 失败", error);
                }
                catch (IOException error)
                {
                    throw new IllegalStateException("读回企业 PDF 失败", error);
                }
            }

            @Override
            public void deleteOwn(String targetRef)
            {
                enterpriseStorage.delete(targetRef);
            }
        };
    }

    /** 按明确错误码判断 Not Found（不依赖异常消息文本）。 */
    private static boolean isNotFound(ServiceException error)
    {
        return error.getCode() != null && error.getCode() == S3FileStorage.NOT_FOUND_CODE;
    }

    /** 从引用路径解析归属用户：private-resume/{userId}/...；s3 引用先取 key。 */
    private static long extractOwnerUserId(String ref)
    {
        String key = S3FileStorage.isReference(ref) ? S3FileStorage.key(ref) : ref;
        String[] parts = key.split("/");
        return Long.parseLong(parts[1]);
    }

    private List<SourceFile> parseManifest(Path manifest) throws IOException
    {
        // 读取完整文本后用合规 CSV 解析，正确支持引号、字段内逗号与换行
        String content = Files.readString(manifest, StandardCharsets.UTF_8);
        List<List<String>> rows;
        try
        {
            rows = CsvRecords.parse(content);
        }
        catch (IllegalArgumentException error)
        {
            throw new IllegalStateException("清单 CSV 格式非法，已停止：" + error.getMessage());
        }

        List<SourceFile> result = new ArrayList<>();
        int recordNo = 0;
        for (List<String> p : rows)
        {
            recordNo++;
            String first = p.isEmpty() ? "" : p.get(0).trim();
            if (first.isEmpty() || first.startsWith("ers_id") || first.startsWith("#")) continue;
            if (p.size() < 7)
                throw new IllegalStateException("清单第 " + recordNo + " 条记录列数不足 7，已停止，请核对清单");
            long snapshotId = requirePositiveId(p.get(0), "snapshotId", recordNo);
            long appId = requirePositiveId(p.get(1), "appId", recordNo);
            long companyId = requirePositiveId(p.get(2), "companyId", recordNo);
            long sourceResumeId = requirePositiveId(p.get(3), "sourceResumeId", recordNo);
            String sourceRef = p.get(4).trim();
            String sourceName = p.get(5).trim();
            if (sourceRef.isEmpty())
                throw new IllegalStateException("清单第 " + recordNo + " 条 sourceFileRef 为空，已停止");
            validateSourceRef(sourceRef, recordNo);
            Long expectedSize = parseNullableLong(p.get(6), recordNo);
            if (expectedSize != null && expectedSize < 0)
                throw new IllegalStateException("清单第 " + recordNo + " 条 expectedSize 非法，已停止");
            result.add(new SourceFile(snapshotId, appId, companyId, sourceResumeId,
                    sourceRef, sourceName, expectedSize));
        }
        if (result.isEmpty()) throw new IllegalStateException("清单无有效工作项，已停止，请核对 manifest");
        return result;
    }

    /**
     * 来源路径安全校验：禁止路径逃逸（..、绝对路径、盘符、反斜杠），
     * 且必须落在 C-App 简历命名空间（private-resume/）或合法 S3 引用内。
     */
    private static void validateSourceRef(String ref, int recordNo)
    {
        String key = S3FileStorage.isReference(ref) ? S3FileStorage.key(ref) : ref;
        boolean illegal = key.contains("..") || key.contains("\\")
                || key.startsWith("/") || key.matches("^[A-Za-z]:.*");
        if (illegal || !key.startsWith("private-resume/"))
            throw new IllegalStateException(
                    "清单第 " + recordNo + " 条来源路径非法或越出允许命名空间，已停止");
        for (String part : key.split("/"))
        {
            if (part.equals("..") || part.equals("."))
                throw new IllegalStateException(
                        "清单第 " + recordNo + " 条来源路径含非法片段，已停止");
        }
    }

    /** 解析清单中的标识字段，要求为合法正整数，否则带记录序号中止。 */
    private static long requirePositiveId(String raw, String field, int recordNo)
    {
        long value;
        try { value = Long.parseLong(raw.trim()); }
        catch (NumberFormatException error)
        {
            throw new IllegalStateException("清单第 " + recordNo + " 条 " + field + " 不是合法数字，已停止");
        }
        if (value <= 0) throw new IllegalStateException(
                "清单第 " + recordNo + " 条 " + field + " 必须为正数，已停止");
        return value;
    }

    private static Long parseNullableLong(String value, int recordNo)
    {
        String v = value == null ? "" : value.trim();
        if (v.isEmpty() || "NULL".equalsIgnoreCase(v)) return null;
        try { return Long.parseLong(v); }
        catch (NumberFormatException error)
        {
            throw new IllegalStateException("清单第 " + recordNo + " 条大小字段不是合法数字，已停止");
        }
    }

    private void writeVerificationManifest(Path file,
            List<PdfFileVerification.VerificationRow> rows) throws IOException
    {
        List<String> lines = new ArrayList<>();
        lines.add("source_path,target_path,source_exists,target_exists,source_size,target_size,"
                + "source_sha256,target_sha256,copy_verified,archive_integrity_verified,"
                + "archive_reference_sha256,authenticity_verified,final_classification,detail");
        for (PdfFileVerification.VerificationRow r : rows)
        {
            lines.add(CsvRecords.format(java.util.List.of(
                r.sourcePath(), r.targetPath(),
                boolText(r.sourceExists()), boolText(r.targetExists()),
                r.sourceSize() == null ? "" : String.valueOf(r.sourceSize()),
                r.targetSize() == null ? "" : String.valueOf(r.targetSize()),
                nullToEmpty(r.sourceSha256()), nullToEmpty(r.targetSha256()),
                boolText(r.copyVerified()), boolText(r.archiveIntegrityVerified()),
                nullToEmpty(r.archiveReferenceSha256()), boolText(r.authenticityVerified()),
                r.finalClassification(), nullToEmpty(r.detail()))));
        }
        Files.write(file, lines, StandardCharsets.UTF_8);
    }

    private static String boolText(boolean value) { return value ? "TRUE" : "FALSE"; }

    private void writeResultCsv(Path file, List<Outcome> outcomes) throws IOException
    {
        List<String> lines = new ArrayList<>();
        lines.add("app_id,status,target_ref,source_sha256,target_sha256,detail");
        for (Outcome o : outcomes)
        {
            lines.add(CsvRecords.format(java.util.List.of(
                    String.valueOf(o.appId()), o.status().name(),
                    nullToEmpty(o.targetRef()), nullToEmpty(o.sourceSha256()),
                    nullToEmpty(o.targetSha256()), nullToEmpty(o.detail()))));
        }
        Files.write(file, lines, StandardCharsets.UTF_8);
    }

    // 错误类：迁移成功但文件侧复核落入这些分类时，需标注“报告成功但复核异常”
    private static boolean isErrorClass(String cls)
    {
        return cls.equals("VERIFY_FAILED") || cls.equals("MANUAL_REVIEW")
                || cls.equals("ARCHIVE_HASH_MISMATCH");
    }

    // 成功类（文件事实成立）不进人工清单；其余分类（含待办/历史缺失）进
    private static boolean needsReview(String cls)
    {
        return !cls.equals("COPIED_UNVERIFIED") && !cls.equals("SOURCE_MISSING_BUT_ARCHIVED");
    }

    /**
     * 人工核查清单：同时考虑迁移 Outcome 与最终 VerificationRow，列结构保持 6 列兼容。
     * 成功类不进；VERIFY_FAILED/MANUAL_REVIEW/ARCHIVE_HASH_MISMATCH/ARCHIVED_UNVERIFIED 进，
     * SOURCE_MISSING_NO_FILE 列历史缺失待办、RECOVERABLE_PENDING 列待处理；同一 appId 只输出一行。
     */
    private void writeManualReview(Path file, List<SourceFile> sources, List<Outcome> outcomes,
            List<PdfFileVerification.VerificationRow> rows) throws IOException
    {
        List<String> lines = new ArrayList<>();
        lines.add("snapshot_id,app_id,source_resume_id,source_ref,status,detail");
        for (int i = 0; i < rows.size(); i++)
        {
            PdfFileVerification.VerificationRow r = rows.get(i);
            if (!needsReview(r.finalClassification())) continue;
            SourceFile s = sources.get(i);
            Outcome o = outcomes.get(i);
            boolean discrepancy = isErrorClass(r.finalClassification())
                    && (o.status() == HistoricalResumePdfMigrator.Status.MIGRATED
                        || o.status() == HistoricalResumePdfMigrator.Status.SKIPPED_IDEMPOTENT);
            String prefix = discrepancy
                    ? "迁移阶段" + o.status().name() + "，文件侧复核异常：" : "";
            lines.add(CsvRecords.format(java.util.List.of(
                    String.valueOf(s.snapshotId()), String.valueOf(s.appId()),
                    String.valueOf(s.sourceResumeId()), s.sourceRef(),
                    r.finalClassification(), prefix + nullToEmpty(r.detail()))));
        }
        Files.write(file, lines, StandardCharsets.UTF_8);
    }

    /**
     * 生成默认全部注释的 06 回写 SQL，供用户审核后手动执行；程序本身不连库、不执行。
     *
     * <p>两类安全回写（均须独立证据，否则不生成）：
     * ① copyVerified 当前源、目标都可读且哈希一致；② archiveIntegrityVerified 源缺失但凭迁移时独立固化的
     * 参考哈希验证目标。文件事实回写只改 path/name/size/文件哈希，带原状态/原引用/幂等守卫，
     * 不改 status 与 version_verified。状态升级段单独成段且默认注释，仅在人工取得可靠原件证据后放开。
     * 归档完整性不等于原件核实；无独立参考、哈希不符、异常/歧义一律不生成回写。</p>
     */
    private void writeStatusUpdateSql(Path file, List<SourceFile> sources,
            List<PdfFileVerification.VerificationRow> rows) throws IOException
    {
        List<String> lines = new ArrayList<>();
        lines.add("-- =====================================================");
        lines.add("-- 仅供用户审核，未经批准不得执行；本文件所有语句默认全部注释。");
        lines.add("-- 用途：先回写文件事实；状态升级须人工取得可靠原件证据后单独放开。");
        lines.add("-- 边界：复制/归档完整性验证通过不等于原件已核实；未核实前保持 REBUILT_UNVERIFIED。");
        lines.add("-- 执行：逐条放开并核对影响行数，与“预期影响 1 行”一致后再继续。");
        lines.add("-- =====================================================");
        for (int i = 0; i < rows.size(); i++)
        {
            PdfFileVerification.VerificationRow r = rows.get(i);
            SourceFile s = sources.get(i);
            boolean viaCopy = r.copyVerified();
            boolean viaArchive = r.archiveIntegrityVerified();
            // 无独立证据（无参考/哈希不符/异常/歧义/未复制）不生成回写
            if (!viaCopy && !viaArchive) continue;
            String basis = viaCopy
                    ? "当前复制一致性验证通过" : "历史归档完整性验证通过（非原件核实）";

            lines.add("-- ------------------------------------------------");
            lines.add("-- 快照 ers_id=" + s.snapshotId() + " app_id=" + s.appId()
                    + "（" + basis + "，文件事实回写，预期影响 1 行）");
            lines.add("/*");
            lines.add("UPDATE t_ent_resume_snapshot");
            lines.add("SET ers_file_path = " + sqlUtf8Hex(r.targetPath()) + ",");
            lines.add("    ers_file_name = " + sqlUtf8Hex(s.sourceName()) + ",");
            lines.add("    ers_file_size = " + (r.targetSize() == null ? "NULL" : r.targetSize()) + ",");
            lines.add("    ers_content_hash = " + sqlUtf8Hex(r.targetSha256())
                    + "  -- v1 文件字节哈希，仅证明文件完整性，不代表原件");
            lines.add("WHERE ers_id = " + s.snapshotId());
            lines.add("  AND ers_app_id = " + s.appId());
            lines.add("  AND ers_snapshot_status = 'REBUILT_UNVERIFIED'  -- 原状态守卫");
            lines.add("  AND ers_version_verified IS NULL               -- 不覆盖已核实快照");
            lines.add("  AND ers_file_path IS NULL;                     -- 幂等：已回写不再改动");
            lines.add("*/");

            lines.add("-- 状态升级（预期影响 1 行）：必须人工取得可靠原件证据后再放开；");
            lines.add("-- " + basis + "不等于原件核实，无证据保持 REBUILT_UNVERIFIED。");
            lines.add("/*");
            lines.add("UPDATE t_ent_resume_snapshot");
            lines.add("SET ers_snapshot_status = 'COMPLETE',");
            lines.add("    ers_version_verified = 'MANUAL_VERIFIED'");
            lines.add("WHERE ers_id = " + s.snapshotId());
            lines.add("  AND ers_app_id = " + s.appId());
            lines.add("  AND ers_snapshot_status = 'REBUILT_UNVERIFIED'");
            lines.add("  AND ers_version_verified IS NULL");
            lines.add("  AND ers_file_path IS NOT NULL;  -- 必须已完成文件事实回写");
            lines.add("*/");
        }
        Files.write(file, lines, StandardCharsets.UTF_8);
    }

    /**
     * 动态字符串安全编码：显式字符集 introducer + UTF-8 字节的十六进制字面量。
     *
     * <p>形如 {@code _utf8mb4 X'616263'}；十六进制只含 [0-9A-F]，不可能出现引号、反斜杠、
     * 注释结束符（星号加斜杠）、换行或控制字符，从根本上杜绝字符串边界与块注释注入，且不依赖连接默认字符集
     * 与 NO_BACKSLASH_ESCAPES。null 输出关键字 NULL；空字符串输出 {@code _utf8mb4 X''}，二者区分。</p>
     */
    static String sqlUtf8Hex(String value)
    {
        if (value == null) return "NULL";
        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        StringBuilder sb = new StringBuilder("_utf8mb4 X'");
        for (byte b : bytes) sb.append(String.format("%02X", b & 0xFF));
        return sb.append("'").toString();
    }

    private static String argValue(String[] args, String name)
    {
        String prefix = "--" + name + "=";
        for (String arg : args)
        {
            if (arg.startsWith(prefix)) return arg.substring(prefix.length());
        }
        return null;
    }

    private static String nullToEmpty(String value) { return value == null ? "" : value; }
}
