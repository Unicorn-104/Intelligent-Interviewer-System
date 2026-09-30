package com.ruoyi.system.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.system.domain.PromptVersion;
import com.ruoyi.system.mapper.PromptVersionMapper;
import com.ruoyi.system.service.IPromptVersionService;

/**
 * Prompt版本Service业务层处理
 *
 * @author TQY
 */
@Service
public class PromptVersionServiceImpl implements IPromptVersionService
{
    @Autowired
    private PromptVersionMapper promptVersionMapper;

    @Override
    public PromptVersion selectPromptVersionByPmvId(Long pmvId)
    {
        return promptVersionMapper.selectPromptVersionByPmvId(pmvId);
    }

    @Override
    public List<PromptVersion> selectPromptVersionList(PromptVersion promptVersion)
    {
        return promptVersionMapper.selectPromptVersionList(promptVersion);
    }

    @Override
    public int insertPromptVersion(PromptVersion promptVersion)
    {
        return promptVersionMapper.insertPromptVersion(promptVersion);
    }

    @Override
    public int updatePromptVersion(PromptVersion promptVersion)
    {
        return promptVersionMapper.updatePromptVersion(promptVersion);
    }

    @Override
    public int deletePromptVersionByPmvId(Long pmvId)
    {
        return promptVersionMapper.deletePromptVersionByPmvId(pmvId);
    }
}
