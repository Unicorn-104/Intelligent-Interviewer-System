package com.ruoyi.system.service;

import java.util.List;
import java.util.Map;

/**
 * 企业数据管理 服务层（导出/备份/清理）
 *
 * @author ruoyi
 */
public interface IDataManageService
{
    /** 导出本公司候选人数据为 CSV，返回下载 url */
    public Map<String, Object> exportResumes(Long companyId);

    /** 立即备份核心业务表，返回备份时间与文件名 */
    public Map<String, Object> backup(Long companyId);

    /** 最近备份时间（无则 null） */
    public String lastBackupTime(Long companyId);

    /** 清理预览：超过 years 年且流程已结束的候选人 */
    public List<Map<String, Object>> cleanupPreview(Long companyId, int years);

    /** 执行清理（按 talId 列表，校验归属公司） */
    public int cleanupExecute(Long companyId, List<Long> talIds);
}
