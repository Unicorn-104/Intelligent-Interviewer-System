package com.ruoyi.system.mapper;

import java.util.List;
import com.ruoyi.system.domain.ModelProvider;

/**
 * 模型ProviderMapper接口
 *
 * @author TQY
 */
public interface ModelProviderMapper
{
    public ModelProvider selectModelProviderByMppId(Long mppId);

    public List<ModelProvider> selectModelProviderList(ModelProvider modelProvider);

    public int insertModelProvider(ModelProvider modelProvider);

    public int updateModelProvider(ModelProvider modelProvider);

    public int deleteModelProviderByMppId(Long mppId);
}
