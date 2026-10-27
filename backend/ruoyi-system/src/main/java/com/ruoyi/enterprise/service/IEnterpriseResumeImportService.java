package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;
import org.springframework.web.multipart.MultipartFile;

/**
 * 企业端简历批量导入：解析 PDF 并挂到已注册候选人账号
 */
public interface IEnterpriseResumeImportService
{
    /**
     * 批量导入简历
     *
     * @param userId 当前登录用户
     * @param files PDF 文件列表
     * @param deduplicate 是否跳过已在企业人才库且同名简历的候选人
     * @return 逐文件导入结果（fileName/status/message/talId/resumeId/candidateName）
     */
    public List<Map<String, Object>> batchImport(Long userId, List<MultipartFile> files, boolean deduplicate);
}
