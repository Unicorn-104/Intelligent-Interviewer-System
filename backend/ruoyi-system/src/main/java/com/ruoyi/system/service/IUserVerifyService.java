package com.ruoyi.system.service;

import java.util.List;
import com.ruoyi.system.domain.UserVerify;

/**
 * 用户实名认证Service接口
 *
 * @author TQY
 */
public interface IUserVerifyService
{
    public UserVerify selectUserVerifyByVefId(Long vefId);

    public List<UserVerify> selectUserVerifyList(UserVerify userVerify);

    public int insertUserVerify(UserVerify userVerify);

    public int updateUserVerify(UserVerify userVerify);

    /**
     * 审核实名认证：通过或拒绝
     * @param vefId 认证ID
     * @param vefStatus 审核状态：1-通过，2-拒绝
     * @param rejectReason 拒绝原因
     */
    public int verifyUser(Long vefId, Integer vefStatus, String rejectReason);
}
