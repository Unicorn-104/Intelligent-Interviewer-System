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
    public int updateCandidateStatus(Long talId, Integer status, String reason, Long operatorId)
    {
        if (talId == null || status == null)
        {
            throw new ServiceException("候选人或状态不能为空");
        }
        Map<String, Object> exist = candidateMapper.selectAdminCandidateById(talId);
        if (exist == null)
        {
            throw new ServiceException("候选人不存在");
        }
        int rows = candidateMapper.updateCandidateStatus(talId, status);
        // t_tal 已有 AFTER UPDATE 触发器自动写日志，这里仅回填人工填写的原因与操作人，避免重复记录
        candidateMapper.updateTalStatusLogMeta(talId, reason, operatorId);
        return rows;
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
        return replaceTags(talId, tagsCsv);
    }

    @Override
    @Transactional
    public int batchUpdateTags(List<Long> talIds, String tagsCsv)
    {
        if (talIds == null || talIds.isEmpty())
        {
            throw new ServiceException("请先选择候选人");
        }
        int rows = 0;
        for (Long talId : talIds)
        {
            if (candidateMapper.selectAdminCandidateById(talId) == null)
            {
                throw new ServiceException("候选人不存在: " + talId);
            }
            rows += appendTags(talId, tagsCsv);
        }
        return rows;
    }

    @Override
    public List<Map<String, Object>> selectTalStatusLogs(Long talId)
    {
        if (talId == null)
        {
            throw new ServiceException("候选人不能为空");
        }
        return candidateMapper.selectTalStatusLogs(talId);
    }

    @Override
    public List<Map<String, Object>> selectCandidateSummary()
    {
        return candidateMapper.selectCandidateSummary();
    }

    /**
     * 先清后插单个候选人标签
     */
    private int replaceTags(Long talId, String tagsCsv)
    {
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
        int rows = 0;
        for (String t : tags)
        {
            rows += candidateMapper.insertCandidateTag(talId, t);
        }
        return rows;
    }

    /**
     * 批量追加标签：保留已有标签，仅插入尚不存在的标签（不去重清空）
     */
    private int appendTags(Long talId, String tagsCsv)
    {
        Set<String> existing = new LinkedHashSet<>(candidateMapper.selectCandidateTags(talId));
        Set<String> toAdd = new LinkedHashSet<>();
        if (StringUtils.isNotEmpty(tagsCsv))
        {
            for (String t : tagsCsv.split(","))
            {
                String v = t == null ? "" : t.trim();
                if (StringUtils.isNotEmpty(v) && !existing.contains(v))
                {
                    toAdd.add(v);
                }
            }
        }
        int rows = 0;
        for (String t : toAdd)
        {
            rows += candidateMapper.insertCandidateTag(talId, t);
        }
        return rows;
    }
}
