package com.ruoyi.system.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.system.domain.IntegrationSecret;

/**
 * 第三方集成凭据数据访问。
 */
public interface IntegrationSecretMapper
{
    List<IntegrationSecret> selectAll();

    IntegrationSecret selectByScopeAndKey(@Param("scope") String scope, @Param("key") String key);

    int updateValueById(@Param("id") Long id, @Param("value") String value);
}
