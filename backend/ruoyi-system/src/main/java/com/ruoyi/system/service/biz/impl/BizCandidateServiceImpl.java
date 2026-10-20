package com.ruoyi.system.service.biz.impl;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.mapper.biz.BizCandidateMapper;
import com.ruoyi.system.service.biz.IBizCandidateService;

/**
 * 平台运营 - 候选人监管 服务实现
 *
 * @author TQY
 */
@Service
public class BizCandidateServiceImpl implements IBizCandidateService
{
    @Autowired
    private BizCandidateMapper candidateMapper;

    @Override
    public List<Map<String, Object>> selectAdminCandidateList(String userName, String status, String tags)
    {
        return candidateMapper.selectAdminCandidateList(userName, status, tags);
    }

    @Override
    public Map<String, Object> selectAdminCandidateById(Long talId)
    {
        Map<String, Object> cand = candidateMapper.selectAdminCandidateById(talId);
        if (cand == null)
        {
            throw new ServiceException("候选人不存在");
        }
        cand.put("tags", candidateMapper.selectCandidateTags(talId));
        return cand;
    }

    @Override
    public int updateCandidateStatus(Long talId, Integer status)
    {
        if (talId == null || status == null)
        {
            throw new ServiceException("候选人或状态不能为空");
        }
        if (candidateMapper.selectAdminCandidateById(talId) == null)
        {
            throw new ServiceException("候选人不存在");
        }
        return candidateMapper.updateCandidateStatus(talId, status);
    }

    @Override
    @Transactional
    public int batchUpdateTag(Long talId, String tagsCsv, String remark)
    {
        if (talId == null)
        {
            throw new ServiceException("候选人不能为空");
        }
        if (candidateMapper.selectAdminCandidateById(talId) == null)
        {
            throw new ServiceException("候选人不存在");
        }
        candidateMapper.deleteCandidateTags(talId);
        Set<String> tags = new LinkedHashSet<>();
        if (StringUtils.isNotEmpty(tagsCsv))
        {
            for (String t : tagsCsv.split(","))
            {
                String v = t == null ? "" : t.trim();
                if (StringUtils.isNotEmpty(v))
                {
                    tags.add(v);
                }
            }
        }
        // 降级：remark 无列不持久化
        int rows = 0;
        for (String t : tags)
        {
            rows += candidateMapper.insertCandidateTag(talId, t);
        }
        return rows;
    }
}
