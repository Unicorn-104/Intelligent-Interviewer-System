package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;

/**
 * 在线笔试 - 双机位监考服务
 *
 * <p>主机位=候选人电脑端 LiveKit 推流，副机位=手机 H5 经接入码加入同一房间推流，
 * 企业端监考以观察者身份入会并排查看两路画面。房间按考试记录维度命名 EXAM-{recordId}。</p>
 *
 * @author enterprise
 */
public interface IExamMonitorService
{
    /** 候选人端：主机位入会信息 + 副机位接入码/二维码地址 + 副机位状态 */
    public Map<String, Object> getMonitorInfo(Long userId, Long recordId);

    /** 副机位H5：凭 recordId+接入码换取入会令牌（匿名） */
    public Map<String, Object> subJoin(Long recordId, String code);

    /** 副机位H5：心跳保活（匿名） */
    public Map<String, Object> subPing(Long recordId, String code);

    /** 副机位H5：离开标记断开（匿名） */
    public Map<String, Object> subLeave(Long recordId, String code);

    /** 企业端：进行中的考试记录列表（含副机位在线状态） */
    public List<Map<String, Object>> listOngoing(Long userId);

    /** 企业端：监考观察者入会令牌 */
    public Map<String, Object> proctorToken(Long userId, Long recordId);
}
