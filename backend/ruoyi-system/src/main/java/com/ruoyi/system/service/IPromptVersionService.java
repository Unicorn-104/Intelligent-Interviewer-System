package com.ruoyi.system.service;

import java.util.List;
import com.ruoyi.system.domain.PromptVersion;

/**
 * Prompt版本Service接口
 *
 * @author TQY
 */
public interface IPromptVersionService
{
    public PromptVersion selectPromptVersionByPmvId(Long pmvId);

    public List<PromptVersion> selectPromptVersionList(PromptVersion promptVersion);

    public int insertPromptVersion(PromptVersion promptVersion);

    public int updatePromptVersion(PromptVersion promptVersion);

    public int deletePromptVersionByPmvId(Long pmvId);
}
