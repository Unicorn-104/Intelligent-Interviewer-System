package com.ruoyi.system.service;

import java.util.List;
import com.ruoyi.system.domain.ModelProvider;

/**
 * 模型ProviderService接口
 *
 * @author TQY
 */
public interface IModelProviderService
{
    public ModelProvider selectModelProviderByMppId(Long mppId);

    public List<ModelProvider> selectModelProviderList(ModelProvider modelProvider);

    public int insertModelProvider(ModelProvider modelProvider);

    public int updateModelProvider(ModelProvider modelProvider);

    public int deleteModelProviderByMppId(Long mppId);
}
