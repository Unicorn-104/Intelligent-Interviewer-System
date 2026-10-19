package com.ruoyi.system.service.biz.impl;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.mapper.biz.BizResumeMapper;
import com.ruoyi.system.service.biz.IBizResumeService;

/**
 * 平台运营 - 简历库 服务实现（降级实现）
 *
 * @author TQY
 */
@Service
public class BizResumeServiceImpl implements IBizResumeService
{
    @Autowired
    private BizResumeMapper resumeMapper;

    @Override
    public List<Map<String, Object>> selectAdminResumeList(String name, String jobName, String source)
    {
        return resumeMapper.selectAdminResumeList(name, jobName, source);
    }

    @Override
    public Map<String, Object> selectAdminResumeById(Long rbsId)
    {
        Map<String, Object> resume = resumeMapper.selectAdminResumeById(rbsId);
        if (resume == null)
        {
            throw new ServiceException("简历不存在");
        }
        return resume;
    }

    @Override
    public int deleteResumeByIds(Long[] rbsIds)
    {
        if (rbsIds == null || rbsIds.length == 0)
        {
            throw new ServiceException("请选择要删除的简历");
        }
        return resumeMapper.deleteResumeByIds(rbsIds);
    }
}
