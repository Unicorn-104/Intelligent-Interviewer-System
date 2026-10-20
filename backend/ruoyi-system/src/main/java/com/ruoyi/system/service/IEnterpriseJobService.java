package com.ruoyi.system.service;

import java.util.List;
import java.util.Map;

/**
 * 企业端岗位管理 服务层
 *
 * @author ruoyi
 */
public interface IEnterpriseJobService
{
    /**
     * 解析当前用户所属公司（null 默认 1）
     */
    public Long resolveCompanyId(Long userId);

    /**
     * 分页查询指定公司岗位（keyword/dept/status 过滤）
     */
    public List<Map<String, Object>> selectJobList(Long companyId, String keyword, String dept, Integer status);

    /**
     * 当前用户公司岗位部门选项
     */
    public List<String> selectJobDepartments(Long userId);

    /**
     * 切换岗位状态（0下线/1在招/2暂停）
     */
    public int changeJobStatus(Long userId, Long posId, Integer status);

    /**
     * 新增岗位，返回岗位信息
     */
    public Map<String, Object> createJob(Long userId, Map<String, Object> form);

    /** 更新当前企业岗位信息，保留岗位状态及招聘流程。 */
    public Map<String, Object> updateJob(Long userId, Long posId, Map<String, Object> form);

    /**
     * 删除草稿岗位（仅允许删除状态为草稿的岗位，已产生业务数据时拒绝删除）
     */
    public Map<String, Object> deleteDraftJob(Long userId, Long posId);

    /** 发布前读取真实企业信息和部门选项。 */
    public Map<String, Object> publishingOptions(Long userId);

    /**
     * 岗位详情聚合（岗位信息+漏斗+候选人+流程阶段）
     */
    public Map<String, Object> jobDetail(Long userId, Long posId);

    /**
     * 岗位流程配置（模板+阶段富字段）
     */
    public Map<String, Object> workflow(Long userId, Long posId);

    /**
     * 保存岗位流程配置（无模板则创建，有则版本+1 重建阶段）
     */
    public Map<String, Object> saveWorkflow(Long userId, Long posId, String templateName, List<Map<String, Object>> stages);
}
