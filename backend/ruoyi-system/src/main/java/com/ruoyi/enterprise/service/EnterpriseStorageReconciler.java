package com.ruoyi.enterprise.service;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * 企业对象存储离线对账清扫器。
 *
 * <p>兜底 {@code TransactionSynchronization.afterCompletion} 无法覆盖的异常：JVM 崩溃、上传超时但实际写入、
 * 孤儿删除失败等。以「数据库快照实际引用集合」对账「企业命名空间实际对象集合」，仅删除确认无引用的孤儿，
 * 不删除任何被引用对象，不依赖数据库连接（引用集合由只读清单经端口提供）。可重复运行、删除失败可安全重试。</p>
 *
 * <p>不引入分布式事务框架：事务内一致性仍靠 afterCompletion，本类只做离线最终对账，匹配项目体量。</p>
 */
public class EnterpriseStorageReconciler
{
    private static final String ENTERPRISE_PREFIX = "enterprise-application-resume/";
    private static final String S3_ENTERPRISE_MARKER = "enterprise-application-resume/";

    /** 企业命名空间对象清单端口（LOCAL 列目录 / S3 listObjects 适配）。 */
    public interface ObjectInventory
    {
        List<String> listAllReferences();
    }

    /** 数据库快照实际引用集合端口（由只读查询导出的清单提供，不连库）。 */
    public interface ReferencedObjects
    {
        Set<String> referencedRefs();
    }

    /** 孤儿删除端口（复用 EnterpriseResumeStorage.delete 适配）。 */
    public interface OrphanHandler
    {
        void delete(String ref);
    }

    /** 对账结果。 */
    public record ReconcileReport(int scanned, List<String> deletedOrphans,
            List<String> retained, List<String> deleteFailed) {}

    private final ObjectInventory objectInventory;
    private final ReferencedObjects referencedObjects;
    private final OrphanHandler orphanHandler;

    public EnterpriseStorageReconciler(ObjectInventory objectInventory,
            ReferencedObjects referencedObjects, OrphanHandler orphanHandler)
    {
        this.objectInventory = objectInventory;
        this.referencedObjects = referencedObjects;
        this.orphanHandler = orphanHandler;
    }

    /** 执行一次对账：仅删除企业命名空间内、且确认无数据库引用的孤儿。 */
    public ReconcileReport reconcile()
    {
        Set<String> referenced = new HashSet<>(referencedObjects.referencedRefs());
        List<String> scanned = objectInventory.listAllReferences();

        List<String> deleted = new ArrayList<>();
        List<String> retained = new ArrayList<>();
        List<String> failed = new ArrayList<>();

        for (String ref : scanned)
        {
            // 非企业命名空间对象一律不动，避免误删其他业务对象
            if (!isEnterpriseRef(ref))
            {
                retained.add(ref);
                continue;
            }
            // 仍被快照引用的对象保留
            if (referenced.contains(ref))
            {
                retained.add(ref);
                continue;
            }
            // 确认孤儿后删除；删除失败计入失败列表，下次重跑可重试（幂等）
            try
            {
                orphanHandler.delete(ref);
                deleted.add(ref);
            }
            catch (RuntimeException error)
            {
                failed.add(ref);
            }
        }
        return new ReconcileReport(scanned.size(), deleted, retained, failed);
    }

    /** 仅认可企业命名空间引用：本地引用按前缀，s3 引用取 key 后按前缀。 */
    private static boolean isEnterpriseRef(String ref)
    {
        if (ref == null) return false;
        if (ref.startsWith(ENTERPRISE_PREFIX)) return true;
        if (ref.startsWith("s3:"))
        {
            int slash = ref.indexOf('/');
            if (slash < 0) return false;
            return ref.substring(slash + 1).startsWith(S3_ENTERPRISE_MARKER);
        }
        return false;
    }
}
