package com.ruoyi.system.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.mapper.ModelProviderMapper;
import com.ruoyi.system.service.IModelProviderService;

/**
 * 模型ProviderService业务层处理
 *
 * @author TQY
 */
@Service
public class ModelProviderServiceImpl implements IModelProviderService
{
    @Autowired
    private ModelProviderMapper modelProviderMapper;

    @Override
    public ModelProvider selectModelProviderByMppId(Long mppId)
    {
        return modelProviderMapper.selectModelProviderByMppId(mppId);
    }

    @Override
    public List<ModelProvider> selectModelProviderList(ModelProvider modelProvider)
    {
        return modelProviderMapper.selectModelProviderList(modelProvider);
    }

    @Override
    public int insertModelProvider(ModelProvider modelProvider)
    {
        return modelProviderMapper.insertModelProvider(modelProvider);
    }

    @Override
    public int updateModelProvider(ModelProvider modelProvider)
    {
        return modelProviderMapper.updateModelProvider(modelProvider);
    }

    @Override
    public int deleteModelProviderByMppId(Long mppId)
    {
        return modelProviderMapper.deleteModelProviderByMppId(mppId);
    }
}
