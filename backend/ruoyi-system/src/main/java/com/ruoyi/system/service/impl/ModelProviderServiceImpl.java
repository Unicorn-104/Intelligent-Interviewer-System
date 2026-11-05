package com.ruoyi.system.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.utils.CredentialCipher;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.mapper.ModelProviderMapper;
import com.ruoyi.system.service.IModelProviderService;

/**
 * 模型ProviderService业务层处理
 *
 * @author TQY
 */
@Service
@Transactional(rollbackFor = Exception.class)
public class ModelProviderServiceImpl implements IModelProviderService
{
    @Autowired
    private ModelProviderMapper modelProviderMapper;

    @Value("${ai.model.crypto-key:Intelligent-Interviewer-AI@2026}")
    private String modelCryptoKey;

    @Override
    public ModelProvider selectModelProviderByMppId(Long mppId)
    {
        return decryptKey(modelProviderMapper.selectModelProviderByMppId(mppId));
    }

    @Override
    public List<ModelProvider> selectModelProviderList(ModelProvider modelProvider)
    {
        List<ModelProvider> list = modelProviderMapper.selectModelProviderList(modelProvider);
        list.forEach(this::decryptKey);
        return list;
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

    /** 读取时统一解密，兼容历史明文行 */
    private ModelProvider decryptKey(ModelProvider provider)
    {
        if (provider != null)
        {
            provider.setMppApiKey(CredentialCipher.decrypt(provider.getMppApiKey(), modelCryptoKey));
        }
        return provider;
    }
}
