package com.ruoyi.system.typehandler;

import java.sql.CallableStatement;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Map;
import org.apache.ibatis.type.BaseTypeHandler;
import org.apache.ibatis.type.JdbcType;
import com.alibaba.fastjson2.JSON;

/**
 * 将 MySQL JSON 字段转换为 Map，避免依赖数据库驱动对 JSON 的隐式转换。
 */
public class JsonMapTypeHandler extends BaseTypeHandler<Map<String, Object>>
{
    @Override
    public void setNonNullParameter(PreparedStatement ps, int i, Map<String, Object> parameter, JdbcType jdbcType)
            throws SQLException
    {
        ps.setString(i, JSON.toJSONString(parameter));
    }

    @Override
    public Map<String, Object> getNullableResult(ResultSet rs, String columnName) throws SQLException
    {
        return parse(rs.getString(columnName));
    }

    @Override
    public Map<String, Object> getNullableResult(ResultSet rs, int columnIndex) throws SQLException
    {
        return parse(rs.getString(columnIndex));
    }

    @Override
    public Map<String, Object> getNullableResult(CallableStatement cs, int columnIndex) throws SQLException
    {
        return parse(cs.getString(columnIndex));
    }

    private Map<String, Object> parse(String value)
    {
        return value == null || value.isBlank() ? null : JSON.parseObject(value);
    }
}
