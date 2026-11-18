package com.ruoyi.enterprise.service;

import java.security.MessageDigest;
import java.util.regex.Pattern;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.MigrationRecord;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.MigrationRecordStore;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.SourceFile;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.SourcePdfReader;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.EnterprisePdfTarget;

/**
 * 历史 PDF 文件验证：基于真实读取字节产出 14 列证据行，不依赖 Spring 与数据库。
 *
 * <p>三个状态严格分开：
 * <ul>
 *   <li>copyVerified：当前源、目标都可读且字节/哈希一致；源缺失时恒 FALSE；</li>
 *   <li>archiveIntegrityVerified：源缺失时，凭迁移当时独立固化的参考哈希验证目标，禁止当前目标自证；
 *       且必须先通过命名空间与 companyId/appId 归属的严格绑定校验；</li>
 *   <li>authenticityVerified：原件真实性，本类默认 FALSE，不自动升级。</li>
 * </ul>
 * 复用 Migrator 的端口接口，不新增端口；读取异常/记录损坏/绑定错误/无法归类一律 MANUAL_REVIEW。
 * 本类不产生 LIVE_ORIGINAL_COMPLETE（实时原件由实时契约识别）。</p>
 */
public class PdfFileVerification
{
    /** 14 列验证行，字段顺序即清单列顺序。 */
    public record VerificationRow(
        String sourcePath, String targetPath,
        boolean sourceExists, boolean targetExists,
        Long sourceSize, Long targetSize,
        String sourceSha256, String targetSha256,
        boolean copyVerified, boolean archiveIntegrityVerified,
        String archiveReferenceSha256, boolean authenticityVerified,
        String finalClassification, String detail) {}

    /** 企业 PDF 合法引用：限定独立命名空间，正则已排除 ..、反斜杠、绝对路径与越权形态。 */
    private static final Pattern TARGET_REF = Pattern.compile(
            "enterprise-application-resume/[1-9][0-9]*/[1-9][0-9]*/[a-f0-9]{32}\\.pdf");

    private enum Binding { OK, NO_REFERENCE, BINDING_ERROR }

    private final SourcePdfReader sourceReader;
    private final EnterprisePdfTarget target;
    private final MigrationRecordStore recordStore;

    public PdfFileVerification(SourcePdfReader sourceReader, EnterprisePdfTarget target,
            MigrationRecordStore recordStore)
    {
        this.sourceReader = sourceReader;
        this.target = target;
        this.recordStore = recordStore;
    }

    /** 验证单条工作项的真实文件状态，全程只读、不写对象。 */
    public VerificationRow verify(SourceFile s)
    {
        // 1) 实际读取源（异常与“不存在”区分：异常进 MANUAL_REVIEW）
        boolean sourceError = false;
        byte[] sourceBytes = null;
        try
        {
            sourceBytes = sourceReader.read(s.sourceResumeId(), s.sourceRef());
        }
        catch (RuntimeException error)
        {
            sourceError = true;
        }
        boolean sourceExists = sourceBytes != null && sourceBytes.length > 0;
        Long sourceSize = sourceExists ? (long) sourceBytes.length : null;
        String sourceHash = sourceExists ? sha256Hex(sourceBytes) : null;

        // 2) 历史迁移记录：读取错误不再静默为“无记录”，单独标记进 MANUAL_REVIEW
        boolean recordError = false;
        MigrationRecord record = null;
        try
        {
            record = recordStore.find(s.appId());
        }
        catch (RuntimeException error)
        {
            recordError = true;
        }
        String targetRef = record == null ? null : record.targetRef();

        // 3) 实际读回目标（readBack 对明确 not found 返回 null；抛异常才是错误）
        boolean targetError = false;
        byte[] targetBytes = null;
        if (targetRef != null)
        {
            try
            {
                targetBytes = target.readBack(targetRef);
            }
            catch (RuntimeException error)
            {
                targetError = true;
            }
        }
        boolean targetExists = targetBytes != null && targetBytes.length > 0;
        Long targetSize = targetExists ? (long) targetBytes.length : null;
        String targetHash = targetExists ? sha256Hex(targetBytes) : null;

        // 4) 当前复制一致性：源、目标都可读且大小与哈希一致
        boolean copyVerified = sourceExists && targetExists
                && sourceSize.equals(targetSize) && sourceHash.equals(targetHash);

        // 5) 归档完整性（仅源缺失、目标存在时评估）：先严格绑定，再凭独立哈希比对
        boolean archiveIntegrity = false;
        String archiveReference = null;
        String bindingReason = "";
        Binding binding = Binding.BINDING_ERROR;
        if (!sourceExists && targetExists)
        {
            StringBuilder reason = new StringBuilder();
            binding = evaluateBinding(s, record, reason);
            bindingReason = reason.toString();
            if (binding == Binding.OK)
            {
                archiveReference = record.sourceSha256();
                archiveIntegrity = archiveReference.equals(targetHash);
                if (!archiveIntegrity) bindingReason = "目标与独立历史参考哈希不一致";
            }
        }

        // 6) 原件真实性：本程序不自动确认
        boolean authenticityVerified = false;

        String detail = buildDetail(sourceError, targetError, recordError, binding,
                sourceExists, targetExists, archiveReference, archiveIntegrity, bindingReason);
        String classification = classify(sourceError, targetError, recordError, binding,
                sourceExists, targetExists, copyVerified, archiveIntegrity);

        return new VerificationRow(s.sourceRef(), targetRef == null ? "" : targetRef,
                sourceExists, targetExists, sourceSize, targetSize,
                sourceHash, targetHash,
                copyVerified, archiveIntegrity,
                archiveReference, authenticityVerified,
                classification, detail);
    }

    /**
     * 严格目标绑定：appId 一致、引用符合独立命名空间、路径内 companyId/appId 与工作项归属一致。
     * 无记录/参考哈希缺失归 NO_REFERENCE（→ARCHIVED_UNVERIFIED）；归属/格式错误归 BINDING_ERROR（→MANUAL_REVIEW）。
     */
    private static Binding evaluateBinding(SourceFile s, MigrationRecord record, StringBuilder reason)
    {
        if (record == null)
        {
            reason.append("无历史迁移记录");
            return Binding.NO_REFERENCE;
        }
        if (record.appId() != s.appId())
        {
            reason.append("历史记录 appId 不一致");
            return Binding.BINDING_ERROR;
        }
        String ref = record.targetRef();
        if (ref == null || !TARGET_REF.matcher(ref).matches())
        {
            reason.append("目标引用格式非法或路径逃逸");
            return Binding.BINDING_ERROR;
        }
        String[] parts = ref.split("/");
        long refCompany = Long.parseLong(parts[1]);
        long refApp = Long.parseLong(parts[2]);
        if (refCompany != s.companyId())
        {
            reason.append("目标路径属于其他企业");
            return Binding.BINDING_ERROR;
        }
        if (refApp != s.appId())
        {
            reason.append("目标路径属于其他投递");
            return Binding.BINDING_ERROR;
        }
        if (isBlank(record.sourceSha256()))
        {
            reason.append("历史参考哈希缺失");
            return Binding.NO_REFERENCE;
        }
        return Binding.OK;
    }

    private static String classify(boolean sourceError, boolean targetError, boolean recordError,
            Binding binding, boolean sourceExists, boolean targetExists,
            boolean copyVerified, boolean archiveIntegrity)
    {
        if (sourceError || targetError || recordError) return "MANUAL_REVIEW";
        if (sourceExists && !targetExists) return "RECOVERABLE_PENDING";
        if (sourceExists && targetExists)
        {
            return copyVerified ? "COPIED_UNVERIFIED" : "VERIFY_FAILED";
        }
        if (!sourceExists && !targetExists) return "SOURCE_MISSING_NO_FILE";
        // 源缺失、目标存在
        if (binding == Binding.BINDING_ERROR) return "MANUAL_REVIEW";
        if (binding == Binding.NO_REFERENCE) return "ARCHIVED_UNVERIFIED";
        return archiveIntegrity ? "SOURCE_MISSING_BUT_ARCHIVED" : "ARCHIVE_HASH_MISMATCH";
    }

    private static String buildDetail(boolean sourceError, boolean targetError, boolean recordError,
            Binding binding, boolean sourceExists, boolean targetExists,
            String archiveReference, boolean archiveIntegrity, String bindingReason)
    {
        if (sourceError) return "源文件读取异常，需人工核查（不等同不存在）";
        if (targetError) return "目标文件读取异常，需人工核查";
        if (recordError) return "迁移记录读取失败，不能当作无记录，人工核查";
        if (sourceExists && !targetExists) return "源可读、目标尚未复制";
        if (!sourceExists && !targetExists) return "源与目标均不存在，合法历史缺失";
        if (!sourceExists && targetExists)
        {
            if (binding == Binding.BINDING_ERROR) return "目标绑定校验未通过：" + bindingReason;
            if (binding == Binding.NO_REFERENCE) return "源缺失、目标存在但" + bindingReason + "，完整性不能证实";
            if (!archiveIntegrity) return bindingReason;
            return "归档完整性经独立历史哈希与归属绑定验证（非原件核实）";
        }
        return "源目标当前复制一致（原件真实性未自动确认）";
    }

    private static boolean isBlank(String v) { return v == null || v.isBlank(); }

    static String sha256Hex(byte[] bytes)
    {
        try
        {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(bytes);
            StringBuilder sb = new StringBuilder(digest.length * 2);
            for (byte b : digest)
            {
                sb.append(Character.forDigit((b >> 4) & 0xF, 16));
                sb.append(Character.forDigit(b & 0xF, 16));
            }
            return sb.toString();
        }
        catch (Exception error)
        {
            throw new IllegalStateException("SHA-256 计算失败", error);
        }
    }
}
