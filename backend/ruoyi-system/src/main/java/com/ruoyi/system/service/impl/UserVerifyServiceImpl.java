package com.ruoyi.system.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.system.domain.UserVerify;
import com.ruoyi.system.mapper.UserVerifyMapper;
import com.ruoyi.system.service.IUserVerifyService;

/**
 * 鐢ㄦ埛瀹炲悕璁よ瘉Service涓氬姟灞傚鐞? *
 * @author TQY
 */
@Service
@Transactional(rollbackFor = Exception.class)
public class UserVerifyServiceImpl implements IUserVerifyService
{
    @Autowired
    private UserVerifyMapper userVerifyMapper;

    @Override
    public UserVerify selectUserVerifyByVefId(Long vefId)
    {
        return userVerifyMapper.selectUserVerifyByVefId(vefId);
    }

    @Override
    public List<UserVerify> selectUserVerifyList(UserVerify userVerify)
    {
        return userVerifyMapper.selectUserVerifyList(userVerify);
    }

    @Override
    public int insertUserVerify(UserVerify userVerify)
    {
        userVerify.setVefCreatedAt(DateUtils.getNowDate());
        return userVerifyMapper.insertUserVerify(userVerify);
    }

    @Override
    public int updateUserVerify(UserVerify userVerify)
    {
        return userVerifyMapper.updateUserVerify(userVerify);
    }

    @Override
    public int verifyUser(Long vefId, Integer vefStatus, String rejectReason)
    {
        UserVerify verify = new UserVerify();
        verify.setVefId(vefId);
        verify.setVefStatus(vefStatus);
        verify.setVefVerifiedAt(DateUtils.getNowDate());
        verify.setVefRejectReason(rejectReason);
        return userVerifyMapper.verifyUser(verify);
    }
}
