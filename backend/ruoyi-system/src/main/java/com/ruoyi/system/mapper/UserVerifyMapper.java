package com.ruoyi.system.mapper;

import java.util.List;
import com.ruoyi.system.domain.UserVerify;

/**
 * 用户实名认证Mapper接口
 *
 * @author TQY
 */
public interface UserVerifyMapper
{
    public UserVerify selectUserVerifyByVefId(Long vefId);

    public List<UserVerify> selectUserVerifyList(UserVerify userVerify);

    public int insertUserVerify(UserVerify userVerify);

    public int updateUserVerify(UserVerify userVerify);

    public int verifyUser(UserVerify userVerify);
}
