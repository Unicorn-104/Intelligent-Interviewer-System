package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 在线笔试 - 双机位监考数据层
 *
 * <p>对应表：t_exam_record（erc_sub_camera_token/url 副机位接入信息）、
 * t_exam_monitor（副机位状态与心跳）。主机位实时状态由 LiveKit 房间参与者
 * 呈现，本表仅持久化副机位加入状态。</p>
 *
 * @author enterprise
 */
public interface ExamMonitorMapper
{
    /** 考试记录 + 安排/试卷/岗位/候选人信息（限本人投递档案） */
    public Map<String, Object> selectRecordOwned(@Param("userId") Long userId,
            @Param("recordId") Long recordId);

    /** 考试记录 + 安排/试卷/岗位/候选人信息（含岗位归属企业，供副机位校验码与监考校验） */
    public Map<String, Object> selectRecordForMonitor(@Param("recordId") Long recordId);

    /** 写入副机位接入码与H5地址 */
    public int updateSubCamera(@Param("recordId") Long recordId, @Param("token") String token,
            @Param("url") String url);

    /** 监控行幂等创建 */
    public int insertMonitorIfAbsent(@Param("recordId") Long recordId);

    /** 当前监控状态（副机位） */
    public Map<String, Object> selectMonitor(@Param("recordId") Long recordId);

    /** 副机位加入：状态1、记录加入与心跳时间 */
    public int updateSubJoin(@Param("recordId") Long recordId);

    /** 副机位心跳：状态1、刷新心跳 */
    public int updateSubHeartbeat(@Param("recordId") Long recordId);

    /** 副机位断开：状态2 */
    public int updateSubLeave(@Param("recordId") Long recordId);

    /** 企业正在进行中的考试记录（status=1），含副机位状态与心跳 */
    public List<Map<String, Object>> selectOngoingRecords(@Param("companyId") Long companyId);
}
