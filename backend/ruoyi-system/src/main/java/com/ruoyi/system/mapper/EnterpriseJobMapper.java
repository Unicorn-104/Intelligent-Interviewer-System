package com.ruoyi.system.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端岗位管理 数据层
 *
 * @author ruoyi
 */
public interface EnterpriseJobMapper
{
    /**
     * 按条件查询公司岗位列表（配合 PageHelper 分页）
     */
    public List<Map<String, Object>> selectJobList(@Param("companyId") Long companyId, @Param("keyword") String keyword, @Param("dept") String dept, @Param("status") Integer status);

    /**
     * 公司下岗位的部门选项
     */
    public List<String> selectJobDepartments(@Param("companyId") Long companyId);

    /**
     * 更新岗位状态（0下线/1在招/2暂停），限本公司
     */
    public int updateJobStatus(@Param("posId") Long posId, @Param("companyId") Long companyId, @Param("status") Integer status);

    /**
     * 新增岗位
     */
    public int insertJob(Map<String, Object> job);

    public Map<String, Object> selectJobForUpdate(@Param("posId") Long posId, @Param("companyId") Long companyId);

    public int updateJob(Map<String, Object> job);

    public Map<String, Object> selectPublishingCompany(@Param("companyId") Long companyId);

    /**
     * 岗位详情（限本公司）
     */
    public Map<String, Object> selectJobById(@Param("posId") Long posId, @Param("companyId") Long companyId);

    /**
     * 岗位招聘漏斗（按候选人 tal_status 聚合）
     */
    public Map<String, Object> selectJobFunnel(@Param("posId") Long posId);

    /**
     * 岗位候选人列表（含当前阶段名与状态标签）
     */
    public List<Map<String, Object>> selectJobCandidates(@Param("posId") Long posId);

    /**
     * 岗位流程模板阶段列表
     */
    public List<Map<String, Object>> selectJobStages(@Param("posId") Long posId);

    /**
     * 查询岗位绑定的流程模板（限本公司）
     */
    public Map<String, Object> selectTemplateByPos(@Param("posId") Long posId, @Param("companyId") Long companyId);

    /**
     * 新建流程模板，返回自增 id
     */
    public int insertTemplate(@Param("companyId") Long companyId, @Param("posId") Long posId, @Param("name") String name);

    /**
     * 岗位最新流程模板 id（新建后回查）
     */
    public Long selectLatestTemplateIdByPos(@Param("posId") Long posId);

    /**
     * 绑定岗位与模板
     */
    public int bindPosTemplate(@Param("posId") Long posId, @Param("companyId") Long companyId, @Param("templateId") Long templateId);

    /**
     * 模板版本号自增
     */
    public int bumpTemplateVersion(@Param("templateId") Long templateId);

    /**
     * 重命名流程模板
     */
    public int renameTemplate(@Param("templateId") Long templateId, @Param("name") String name);

    /**
     * 删除模板下全部阶段
     */
    public int deleteStagesByTemplate(@Param("templateId") Long templateId);

    /**
     * 插入流程阶段
     */
    public int insertStage(@Param("templateId") Long templateId, @Param("name") String name, @Param("type") Integer type,
                           @Param("sortOrder") Integer sortOrder, @Param("required") Integer required,
                           @Param("threshold") Integer threshold, @Param("configJson") String configJson);

    /**
     * 查询模板阶段（含富配置 json）
     */
    public List<Map<String, Object>> selectStagesByTemplate(@Param("templateId") Long templateId);
}
