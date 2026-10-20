package com.ruoyi.system.service.biz.impl;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.mapper.biz.BizJobMapper;
import com.ruoyi.system.service.biz.IBizJobService;

/**
 * 平台运营 - 岗位监管 服务实现
 *
 * @author TQY
 */
@Service
public class BizJobServiceImpl implements IBizJobService
{
    @Autowired
    private BizJobMapper jobMapper;

    @Override
    public List<Map<String, Object>> selectAdminJobList(String jobName, String companyName, Integer status)
    {
        return jobMapper.selectAdminJobList(jobName, companyName, status);
    }

    @Override
    public Map<String, Object> selectAdminJobById(Long posId)
    {
        Map<String, Object> job = jobMapper.selectAdminJobById(posId);
        if (job == null)
        {
            throw new ServiceException("岗位不存在");
        }
        return job;
    }

    @Override
    public int auditJob(Long posId, Integer result, String reason)
    {
        if (posId == null)
        {
            throw new ServiceException("岗位不能为空");
        }
        if (result == null || (result != 1 && result != 2))
        {
            throw new ServiceException("审核结论非法");
        }
        if (jobMapper.selectAdminJobById(posId) == null)
        {
            throw new ServiceException("岗位不存在");
        }
        // 降级：未新增审核原因列，reason 不持久化；1=通过发布，2=违规下架
        int targetStatus = result == 1 ? 1 : 2;
        return jobMapper.updateJobStatus(posId, targetStatus);
    }
}
