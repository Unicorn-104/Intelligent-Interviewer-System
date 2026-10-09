package com.ruoyi.system.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.system.domain.PromptVersion;
import com.ruoyi.system.mapper.PromptVersionMapper;
import com.ruoyi.system.service.IPromptVersionService;

/**
 * Prompt鐗堟湰Service涓氬姟灞傚鐞? *
 * @author TQY
 */
@Service
@Transactional(rollbackFor = Exception.class)
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
