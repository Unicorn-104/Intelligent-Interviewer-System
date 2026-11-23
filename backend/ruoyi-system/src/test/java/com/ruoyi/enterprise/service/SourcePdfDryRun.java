package com.ruoyi.enterprise.service;

import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Properties;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.core.exception.ApiCallAttemptTimeoutException;
import software.amazon.awssdk.core.exception.ApiCallTimeoutException;
import software.amazon.awssdk.core.exception.SdkClientException;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.S3Exception;

/**
 * 历史源 PDF 只读核验与隔离 Dry Run（独立入口，不启动 Spring/Druid/MySQL/Redis/Quartz）。
 *
 * <p>本类只有 {@code main} 方法，手动装配 S3 兼容客户端（RustFS），全程仅执行 GetObject 只读调用：
 * 不写企业对象、不写迁移记录、不执行任何 SQL、不连接数据库。读取失败严格区分类型，
 * 只有明确 {@link NoSuchKeyException}（404/NoSuchKey）才判定对象不存在；
 * 403、超时、5xx、网络错误及大小不一致一律 MANUAL_REVIEW，绝不与“不存在”混淆。</p>
 *
 * <p>连接信息来源（不在仓库硬编码、日志不打印密钥）：
 * <ul>
 *   <li>环境变量 FILE_STORAGE_S3_ENDPOINT/BUCKET/ACCESS_KEY/SECRET_KEY/REGION/PATH_STYLE/TIMEOUT_SECONDS；</li>
 *   <li>或命令行 {@code --config=<外部 properties 路径>}（该文件不入库，键名与环境变量同名）。</li>
 * </ul>
 * 其他参数：{@code --out=<输出目录>}。SHA-256 复用 {@link PdfFileVerification#sha256Hex}，
 * 基于真实读取字节计算，无自我证明。</p>
 */
public final class SourcePdfDryRun
{
    /** 7 条有 PDF 引用的工作项（两组重复引用各保留独立 appId，不去重）。 */
    private static final List<WorkItem> WORK_ITEMS = List.of(
        new WorkItem(1, 48, 135, 35, "private-resume/104/2026/10/27/d98c0cc568704e12916eb8db48c4dee9.pdf", 696287),
        new WorkItem(2, 47, 135, 35, "private-resume/104/2026/10/27/d98c0cc568704e12916eb8db48c4dee9.pdf", 696287),
        new WorkItem(3, 49, 138, 38, "private-resume/104/2026/10/28/d7372c40703341158ed76059a50b2f56.pdf", 360830),
        new WorkItem(4, 70, 152, 52, "s3/private-resume/104/2026/11/04/226ebc017a1b426b9ffc052a2be93542.pdf", 309407),
        new WorkItem(5, 79, 150, 50, "private-resume/104/2026/11/01/a237263b80534d1f9f818696c04cb120.pdf", 2978739),
        new WorkItem(7, 71, 151, 51, "s3/private-resume/2/2026/11/03/1094f8750f774eb19983a4d14e205567.pdf", 163683),
        new WorkItem(10, 78, 151, 51, "s3/private-resume/2/2026/11/03/1094f8750f774eb19983a4d14e205567.pdf", 163683));

    /** 3 条无 PDF 引用（PDF 路径为空）的快照，单独登记，不传入读取程序。 */
    private static final List<NoRefItem> NO_REF_ITEMS = List.of(
        new NoRefItem(6, 45, 16),
        new NoRefItem(7, 46, 16),
        new NoRefItem(8, 52, 16));

    private record WorkItem(long snapshotId, long appId, long companyId,
            long sourceResumeId, String sourceRef, long expectedSize) {}

    private record NoRefItem(long snapshotId, long appId, long sourceResumeId) {}

    /** 单条核验结果；actualSize/sourceSha256 在不可读时为 null。 */
    private record CheckResult(WorkItem item, boolean sourceExists, Long actualSize,
            boolean sizeMatches, String sourceSha256, String errorType,
            String readError, String finalClassification) {}

    /** 读取错误类型（精细分类），成功为 NONE。 */
    private static final String NONE = "NONE";
    private static final String NOT_FOUND = "NOT_FOUND";
    private static final String ACCESS_DENIED = "ACCESS_DENIED";
    private static final String TIMEOUT = "TIMEOUT";
    private static final String SERVER_ERROR = "SERVER_ERROR";
    private static final String CLIENT_ERROR = "CLIENT_ERROR";
    private static final String UNKNOWN_ERROR = "UNKNOWN_ERROR";
    private static final String SIZE_MISMATCH = "SIZE_MISMATCH";

    /** 最终分类：可进入正式复制 / 明确不存在 / 人工核查。 */
    private static final String READY_TO_COPY = "READY_TO_COPY";
    private static final String MANUAL_REVIEW = "MANUAL_REVIEW";

    private SourcePdfDryRun() {}

    public static void main(String[] args)
    {
        String configPath = null;
        String outDir = null;
        for (String arg : args)
        {
            if (arg.startsWith("--config=")) configPath = arg.substring("--config=".length());
            else if (arg.startsWith("--out=")) outDir = arg.substring("--out=".length());
        }

        Settings settings;
        try
        {
            settings = loadSettings(configPath);
        }
        catch (IOException error)
        {
            System.err.println("[BLOCKED] 读取外部配置失败：" + error.getMessage());
            System.exit(2);
            return;
        }
        if (!settings.ready())
        {
            // 连接信息缺失：给出可操作提示，不伪造端点/密钥
            System.err.println("[BLOCKED] 缺少对象存储连接信息，无法真实读取源对象。");
            System.err.println("请通过环境变量或 --config=<properties> 提供：");
            System.err.println("  FILE_STORAGE_S3_ENDPOINT, FILE_STORAGE_S3_BUCKET,");
            System.err.println("  FILE_STORAGE_S3_ACCESS_KEY, FILE_STORAGE_S3_SECRET_KEY");
            System.err.println("（可选 REGION/PATH_STYLE/TIMEOUT_SECONDS；密钥不会被打印）");
            System.exit(2);
            return;
        }

        Path out = Path.of(outDir == null ? "." : outDir).toAbsolutePath().normalize();
        try
        {
            Files.createDirectories(out);
        }
        catch (IOException error)
        {
            System.err.println("[BLOCKED] 无法创建输出目录：" + out);
            System.exit(2);
            return;
        }

        // 仅打印非敏感信息，绝不打印 accessKey/secretKey
        System.out.println("=== 历史源 PDF 只读 Dry Run（无写入、无 SQL、无数据库连接）===");
        System.out.println("endpoint=" + settings.endpoint + " | bucket=" + settings.bucket
                + " | region=" + settings.region + " | pathStyle=" + settings.pathStyle
                + " | timeoutSeconds=" + settings.timeoutSeconds);
        System.out.println("输出目录=" + out);

        S3Client s3 = buildClient(settings);
        List<CheckResult> results = new ArrayList<>();
        try
        {
            for (WorkItem item : WORK_ITEMS) results.add(checkOne(s3, settings.bucket, item));
        }
        finally
        {
            s3.close();
        }

        try
        {
            writeDeliverables(out, results);
        }
        catch (IOException error)
        {
            System.err.println("[BLOCKED] 写出交付文件失败：" + error.getMessage());
            System.exit(2);
            return;
        }
        printSummary(results);
    }

    /** 核验单条工作项：真实 GetObject 读取，精细区分错误，再做大小与 SHA 核验。 */
    private static CheckResult checkOne(S3Client s3, String bucket, WorkItem item)
    {
        String key = normalizeKey(item.sourceRef());
        try
        {
            ResponseBytes<GetObjectResponse> resp = s3.getObjectAsBytes(
                    GetObjectRequest.builder().bucket(bucket).key(key).build());
            byte[] bytes = resp.asByteArray();
            if (bytes == null || bytes.length == 0)
            {
                // 空对象不是合法 PDF，按不确定失败人工核查，不判不存在
                return new CheckResult(item, false, null, false, null, UNKNOWN_ERROR,
                        "读取到空对象，无法核验", MANUAL_REVIEW);
            }
            long actualSize = bytes.length;
            boolean sizeMatches = actualSize == item.expectedSize();
            String sha = PdfFileVerification.sha256Hex(bytes);
            if (!sizeMatches)
            {
                return new CheckResult(item, true, actualSize, false, sha, SIZE_MISMATCH,
                        "实际大小 " + actualSize + " 与期望大小 " + item.expectedSize() + " 不一致",
                        MANUAL_REVIEW);
            }
            return new CheckResult(item, true, actualSize, true, sha, NONE, "", READY_TO_COPY);
        }
        catch (NoSuchKeyException error)
        {
            // 唯一可判定“对象不存在”的情形
            return new CheckResult(item, false, null, false, null, NOT_FOUND,
                    "明确 404/NoSuchKey：对象不存在（key=" + key + "）", "NOT_FOUND");
        }
        catch (S3Exception error)
        {
            int code = error.statusCode();
            if (code == 403)
                return manual(item, ACCESS_DENIED, "403 拒绝访问，需人工核查权限（不等同不存在）");
            if (code >= 500)
                return manual(item, SERVER_ERROR, "5xx 服务端错误（HTTP " + code + "），需人工核查");
            return manual(item, UNKNOWN_ERROR, "S3 返回 HTTP " + code + "，需人工核查");
        }
        catch (ApiCallTimeoutException | ApiCallAttemptTimeoutException error)
        {
            return manual(item, TIMEOUT, "读取超时，需人工核查（不等同不存在）");
        }
        catch (SdkClientException error)
        {
            // 网络不可达、连接重置等客户端侧错误，不能判不存在
            return manual(item, CLIENT_ERROR, "网络/客户端错误，需人工核查（不等同不存在）");
        }
        catch (RuntimeException error)
        {
            return manual(item, UNKNOWN_ERROR, "未归类异常：" + error.getClass().getSimpleName());
        }
    }

    private static CheckResult manual(WorkItem item, String errorType, String message)
    {
        return new CheckResult(item, false, null, false, null, errorType, message, MANUAL_REVIEW);
    }

    /**
     * 路径规范化为对象 key：
     * <ul>
     *   <li>{@code s3:bucket/key}（代码完整引用）→ 去掉 bucket 段；</li>
     *   <li>{@code s3/key}（清单简化标注）→ 去掉 "s3/" 前缀；</li>
     *   <li>裸 {@code private-resume/...} → 原样作为 key。</li>
     * </ul>
     */
    static String normalizeKey(String ref)
    {
        if (ref == null) return "";
        String r = ref.trim();
        if (r.startsWith("s3:"))
        {
            int slash = r.indexOf('/');
            return slash >= 0 ? r.substring(slash + 1) : "";
        }
        if (r.startsWith("s3/")) return r.substring(3);
        return r;
    }

    // ===== 配置加载 =====

    private record Settings(String endpoint, String bucket, String accessKey, String secretKey,
            String region, boolean pathStyle, int timeoutSeconds)
    {
        boolean ready()
        {
            return endpoint != null && !endpoint.isBlank() && bucket != null && !bucket.isBlank()
                    && accessKey != null && !accessKey.isBlank()
                    && secretKey != null && !secretKey.isBlank();
        }
    }

    /** 环境变量优先；提供 --config 时以外部 properties 覆盖（键名与环境变量同名）。 */
    private static Settings loadSettings(String configPath) throws IOException
    {
        Properties file = new Properties();
        if (configPath != null && !configPath.isBlank())
        {
            Path p = Path.of(configPath).toAbsolutePath().normalize();
            try (InputStream in = Files.newInputStream(p))
            {
                file.load(in);
            }
        }
        String endpoint = pick("FILE_STORAGE_S3_ENDPOINT", file, "");
        String bucket = pick("FILE_STORAGE_S3_BUCKET", file, "recruit-files");
        String accessKey = pick("FILE_STORAGE_S3_ACCESS_KEY", file, "");
        String secretKey = pick("FILE_STORAGE_S3_SECRET_KEY", file, "");
        String region = pick("FILE_STORAGE_S3_REGION", file, "us-east-1");
        boolean pathStyle = Boolean.parseBoolean(pick("FILE_STORAGE_S3_PATH_STYLE", file, "true"));
        int timeout = 60;
        try { timeout = Integer.parseInt(pick("FILE_STORAGE_S3_TIMEOUT_SECONDS", file, "60")); }
        catch (NumberFormatException ignored) { timeout = 60; }
        return new Settings(endpoint, bucket, accessKey, secretKey, region, pathStyle, timeout);
    }

    /** 环境变量优先于 properties 文件；都没有则用默认值。 */
    private static String pick(String key, Properties file, String def)
    {
        String env = System.getenv(key);
        if (env != null && !env.isBlank()) return env.trim();
        String val = file.getProperty(key);
        return val == null || val.isBlank() ? def : val.trim();
    }

    /** 手动装配 S3Client（参数与 S3StorageConfiguration 一致），不依赖 Spring 容器。 */
    private static S3Client buildClient(Settings s)
    {
        URI endpoint = URI.create(s.endpoint);
        Duration timeout = Duration.ofSeconds(s.timeoutSeconds);
        return S3Client.builder()
                .endpointOverride(endpoint)
                .region(Region.of(s.region))
                .forcePathStyle(s.pathStyle)
                .serviceConfiguration(S3Configuration.builder().chunkedEncodingEnabled(false).build())
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(s.accessKey, s.secretKey)))
                .httpClientBuilder(UrlConnectionHttpClient.builder()
                        .connectionTimeout(Duration.ofSeconds(10)).socketTimeout(timeout))
                .overrideConfiguration(c -> c.apiCallTimeout(timeout).apiCallAttemptTimeout(timeout))
                .build();
    }

    // ===== 交付文件写出 =====

    private static void writeDeliverables(Path out, List<CheckResult> results) throws IOException
    {
        writeResultCsv(out.resolve("source_pdf_dry_run_result.csv"), results);
        writeManualReviewCsv(out.resolve("source_pdf_manual_review.csv"), results);
        writeNoRefCsv(out.resolve("no_pdf_reference.csv"));
        writeManifestCsv(out.resolve("migration_manifest.csv"));
        writeReport(out.resolve("source_pdf_dry_run_report.md"), results);
    }

    private static final List<String> RESULT_HEADER = List.of(
            "snapshotId", "appId", "sourceResumeId", "sourceRef", "sourceExists",
            "expectedSize", "actualSize", "sizeMatches", "sourceSha256",
            "readError", "finalClassification");

    private static List<String> resultRow(CheckResult r)
    {
        WorkItem w = r.item();
        return List.of(
                String.valueOf(w.snapshotId()),
                String.valueOf(w.appId()),
                String.valueOf(w.sourceResumeId()),
                w.sourceRef(),
                r.sourceExists() ? "TRUE" : "FALSE",
                String.valueOf(w.expectedSize()),
                r.actualSize() == null ? "" : String.valueOf(r.actualSize()),
                r.sizeMatches() ? "TRUE" : "FALSE",
                r.sourceSha256() == null ? "" : r.sourceSha256(),
                r.readError(),
                r.finalClassification());
    }

    private static void writeResultCsv(Path file, List<CheckResult> results) throws IOException
    {
        StringBuilder sb = new StringBuilder(CsvRecords.format(RESULT_HEADER)).append(System.lineSeparator());
        for (CheckResult r : results)
            sb.append(CsvRecords.format(resultRow(r))).append(System.lineSeparator());
        Files.writeString(file, sb.toString(), StandardCharsets.UTF_8);
    }

    private static void writeManualReviewCsv(Path file, List<CheckResult> results) throws IOException
    {
        StringBuilder sb = new StringBuilder(CsvRecords.format(RESULT_HEADER)).append(System.lineSeparator());
        for (CheckResult r : results)
        {
            if (MANUAL_REVIEW.equals(r.finalClassification()))
                sb.append(CsvRecords.format(resultRow(r))).append(System.lineSeparator());
        }
        Files.writeString(file, sb.toString(), StandardCharsets.UTF_8);
    }

    private static void writeNoRefCsv(Path file) throws IOException
    {
        List<String> header = List.of("snapshotId", "appId", "sourceResumeId", "note");
        StringBuilder sb = new StringBuilder(CsvRecords.format(header)).append(System.lineSeparator());
        for (NoRefItem n : NO_REF_ITEMS)
        {
            List<String> row = List.of(String.valueOf(n.snapshotId()), String.valueOf(n.appId()),
                    String.valueOf(n.sourceResumeId()), "PDF 路径为空：结构化简历仍可迁移，原件不可用，不传入读取程序");
            sb.append(CsvRecords.format(row)).append(System.lineSeparator());
        }
        Files.writeString(file, sb.toString(), StandardCharsets.UTF_8);
    }

    private static void writeManifestCsv(Path file) throws IOException
    {
        List<String> header = List.of("snapshotId", "appId", "companyId", "sourceResumeId",
                "sourceRef", "expectedSize");
        StringBuilder sb = new StringBuilder(CsvRecords.format(header)).append(System.lineSeparator());
        for (WorkItem w : WORK_ITEMS)
        {
            List<String> row = List.of(String.valueOf(w.snapshotId()), String.valueOf(w.appId()),
                    String.valueOf(w.companyId()), String.valueOf(w.sourceResumeId()),
                    w.sourceRef(), String.valueOf(w.expectedSize()));
            sb.append(CsvRecords.format(row)).append(System.lineSeparator());
        }
        Files.writeString(file, sb.toString(), StandardCharsets.UTF_8);
    }

    private static void writeReport(Path file, List<CheckResult> results) throws IOException
    {
        long total = results.size();
        long ready = results.stream().filter(r -> READY_TO_COPY.equals(r.finalClassification())).count();
        long notFound = results.stream().filter(r -> "NOT_FOUND".equals(r.finalClassification())).count();
        long manual = results.stream().filter(r -> MANUAL_REVIEW.equals(r.finalClassification())).count();

        StringBuilder sb = new StringBuilder();
        sb.append("# 历史源 PDF 只读核验 Dry Run 报告\n\n");
        sb.append("> 本程序仅执行 GetObject 只读调用：未启动 Spring/Druid/MySQL/Redis/Quartz，"
                + "未连接数据库、未执行 SQL、未写任何对象；SHA-256 基于真实读取字节。\n\n");
        sb.append("## 一、总体结论\n\n");
        sb.append("| 指标 | 数量 |\n|---|---|\n");
        sb.append("| 工作项总数 | ").append(total).append(" |\n");
        sb.append("| READY_TO_COPY（大小匹配、已算真实哈希） | ").append(ready).append(" |\n");
        sb.append("| NOT_FOUND（明确 404/NoSuchKey） | ").append(notFound).append(" |\n");
        sb.append("| MANUAL_REVIEW（403/超时/5xx/大小不符等） | ").append(manual).append(" |\n");
        sb.append("| 无 PDF 引用（单独登记） | ").append(NO_REF_ITEMS.size()).append(" |\n\n");

        sb.append("## 二、逐条核验明细\n\n");
        sb.append("| snapshotId | appId | sourceExists | expectedSize | actualSize | "
                + "sizeMatches | sourceSha256 | errorType | finalClassification |\n");
        sb.append("|---|---|---|---|---|---|---|---|---|\n");
        for (CheckResult r : results)
        {
            WorkItem w = r.item();
            sb.append("| ").append(w.snapshotId())
              .append(" | ").append(w.appId())
              .append(" | ").append(r.sourceExists() ? "TRUE" : "FALSE")
              .append(" | ").append(w.expectedSize())
              .append(" | ").append(r.actualSize() == null ? "" : r.actualSize())
              .append(" | ").append(r.sizeMatches() ? "TRUE" : "FALSE")
              .append(" | ").append(r.sourceSha256() == null ? "" : r.sourceSha256())
              .append(" | ").append(r.errorType())
              .append(" | ").append(r.finalClassification())
              .append(" |\n");
        }

        sb.append("\n## 三、判定规则（严格区分）\n\n");
        sb.append("- 只有明确 NoSuchKeyException（404/NoSuchKey）才判定对象不存在；\n");
        sb.append("- 403、超时、5xx、网络/客户端错误、空对象、未归类异常一律 MANUAL_REVIEW，不等同不存在；\n");
        sb.append("- 成功读取但实际大小与 expectedSize 不一致：SIZE_MISMATCH，MANUAL_REVIEW；\n");
        sb.append("- 成功读取且大小一致：基于真实字节计算 SHA-256，标记 READY_TO_COPY；\n");
        sb.append("- 两组重复引用（snapshotId 1/2、7/10）各保留独立 appId，未去重。\n\n");

        sb.append("## 四、无 PDF 引用记录处理建议\n\n");
        sb.append("3 条 PDF 路径为空的快照（appId=45/46/52）已单独登记于 no_pdf_reference.csv，"
                + "不传入读取程序；其结构化快照可正常迁移与展示，仅原始 PDF 不可用，"
                + "不应据此推断 PDF 已彻底丢失，需人工核查历史归档。\n\n");

        boolean pass = manual == 0 && notFound == 0 && ready == total;
        sb.append("## 五、是否达到正式复制条件\n\n");
        if (pass)
        {
            sb.append("**PASS**：7 条工作项全部 READY_TO_COPY，大小全部匹配且均有真实 SHA-256，"
                    + "可在另行授权后进入正式 PDF 复制；本 Dry Run 本身不执行任何复制。\n");
        }
        else
        {
            sb.append("**NOT READY**：存在 NOT_FOUND 或 MANUAL_REVIEW 项，需先完成人工核查/处置，"
                    + "暂不满足正式复制条件。\n");
        }
        Files.writeString(file, sb.toString(), StandardCharsets.UTF_8);
    }

    private static void printSummary(List<CheckResult> results)
    {
        long ready = results.stream().filter(r -> READY_TO_COPY.equals(r.finalClassification())).count();
        long notFound = results.stream().filter(r -> "NOT_FOUND".equals(r.finalClassification())).count();
        long manual = results.stream().filter(r -> MANUAL_REVIEW.equals(r.finalClassification())).count();
        System.out.println("--- 汇总 ---");
        System.out.println("总数=" + results.size() + " READY_TO_COPY=" + ready
                + " NOT_FOUND=" + notFound + " MANUAL_REVIEW=" + manual);
        for (CheckResult r : results)
        {
            WorkItem w = r.item();
            System.out.println(String.format(Locale.ROOT,
                    "snapshotId=%d appId=%d exists=%s actual=%s match=%s hash=%s => %s",
                    w.snapshotId(), w.appId(), r.sourceExists(),
                    r.actualSize() == null ? "-" : r.actualSize(),
                    r.sizeMatches(),
                    r.sourceSha256() == null ? "-" : r.sourceSha256().substring(0, 12) + "...",
                    r.finalClassification()));
        }
    }
}
