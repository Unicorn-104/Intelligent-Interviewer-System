package com.ruoyi.system.service;

/**
 * LiveKit Egress（服务端录制）调用服务
 * <p>
 * 通过 LiveKit Egress 的 Twirp 接口启动 / 停止房间合成录制，
 * 使用 API Key/Secret 签发的 HS256 JWT 鉴权（含 video.roomRecord 声明）。
 *
 * @author YLX
 */
public interface ILiveKitEgressService
{
    /**
     * 启动房间合成录制（MP4 文件输出）
     *
     * @param roomName 房间名
     * @param filepath 录制文件输出路径（Egress 容器内路径，如 /out/2026/10/14/REC-xxx.mp4）
     * @return LiveKit Egress 任务ID
     */
    public String startRoomRecording(String roomName, String filepath);

    /**
     * 停止录制任务（文件真正落盘由 Egress 完成，完成后通过 Webhook 回调通知）
     *
     * @param egressId LiveKit Egress 任务ID
     */
    public void stopEgress(String egressId);
}
