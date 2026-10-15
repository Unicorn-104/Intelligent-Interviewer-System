package com.ruoyi.enterprise.service.impl;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.enterprise.mapper.ExamMonitorMapper;
import com.ruoyi.enterprise.service.IExamMonitorService;
import com.ruoyi.system.mapper.DashboardMapper;

/**
 * 在线笔试 - 双机位监考服务实现
 *
 * <p>按 LiveKit Access Token 协议生成 HS256 JWT（与面试会议同一套
 * livekit.api-key/api-secret 配置），但房间为笔试专用 EXAM-{recordId}，
 * 与面试场次解耦，故不复用也不改动 LiveKitTokenServiceImpl 的场次校验逻辑。
 * 副机位手机 H5 无法登录候选人端，凭 erc_sub_camera_token 接入码换取令牌。</p>
 *
 * @author enterprise
 */
@Service
public class ExamMonitorServiceImpl implements IExamMonitorService
{
    private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    /** 副机位心跳超过该秒数视为掉线 */
    private static final long SUB_ONLINE_WINDOW_SEC = 45;

    @Value("${livekit.api-key:}")
    private String apiKey;

    @Value("${livekit.api-secret:}")
    private String apiSecret;

    @Value("${livekit.url:ws://localhost:7880}")
    private String livekitUrl;

    @Value("${livekit.token-ttl-seconds:7200}")
    private long ttlSeconds;

    @Autowired
    private ExamMonitorMapper examMonitorMapper;

    @Autowired
    private DashboardMapper dashboardMapper;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public Map<String, Object> getMonitorInfo(Long userId, Long recordId)
    {
        Map<String, Object> record = requireOwnedActive(userId, recordId);
        examMonitorMapper.insertMonitorIfAbsent(recordId);

        String code = asString(record.get("subToken"));
        if (StringUtils.isEmpty(code))
        {
            code = UUID.randomUUID().toString().replace("-", "");
            examMonitorMapper.updateSubCamera(recordId, code,
                    "/exam-sub?recordId=" + recordId + "&code=" + code);
        }

        Long talId = asLong(record.get("talId"));
        String room = roomOf(recordId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("recordId", recordId);
        result.put("room", room);
        result.put("url", livekitUrl);
        result.put("token", issueExamToken(room, "exam-main-" + talId, true));
        result.put("identity", "exam-main-" + talId);
        result.put("joinCode", code);
        result.put("subUrl", "/exam-sub?recordId=" + recordId + "&code=" + code);
        result.put("forceDualCamera", record.get("forceDualCamera"));
        result.put("sub", monitorStatus(recordId));
        return result;
    }

    @Override
    public Map<String, Object> subJoin(Long recordId, String code)
    {
        Map<String, Object> record = requireSubCode(recordId, code);
        examMonitorMapper.insertMonitorIfAbsent(recordId);
        examMonitorMapper.updateSubJoin(recordId);
        String room = roomOf(recordId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("room", room);
        result.put("url", livekitUrl);
        result.put("token", issueExamToken(room, "exam-sub-" + recordId, true));
        result.put("identity", "exam-sub-" + recordId);
        result.put("candidateName", record.get("candidateName"));
        result.put("paperName", record.get("paperName"));
        return result;
    }

    @Override
    public Map<String, Object> subPing(Long recordId, String code)
    {
        requireSubCode(recordId, code);
        examMonitorMapper.updateSubHeartbeat(recordId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("ok", true);
        return result;
    }

    @Override
    public Map<String, Object> subLeave(Long recordId, String code)
    {
        requireSubCode(recordId, code);
        examMonitorMapper.updateSubLeave(recordId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("ok", true);
        return result;
    }

    @Override
    public List<Map<String, Object>> listOngoing(Long userId)
    {
        Long companyId = resolveCompanyId(userId);
        List<Map<String, Object>> list = examMonitorMapper.selectOngoingRecords(companyId);
        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> item : list)
        {
            Map<String, Object> row = new LinkedHashMap<>(item);
            row.put("subOnline", isSubOnline(asInt(item.get("subStatus")), asTime(item.get("subHeartbeatAt"))));
            result.add(row);
        }
        return result;
    }

    @Override
    public Map<String, Object> proctorToken(Long userId, Long recordId)
    {
        Map<String, Object> record = examMonitorMapper.selectRecordForMonitor(recordId);
        if (record == null || !resolveCompanyId(userId).equals(asLong(record.get("companyId"))))
        {
            throw new ServiceException("考试记录不存在或无权访问");
        }
        String room = roomOf(recordId);
        String identity = "exam-proctor-" + userId;
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("room", room);
        result.put("url", livekitUrl);
        result.put("token", issueExamToken(room, identity, false));
        result.put("identity", identity);
        result.put("candidateName", record.get("candidateName"));
        result.put("positionTitle", record.get("positionTitle"));
        result.put("paperName", record.get("paperName"));
        result.put("recordStatus", record.get("status"));
        result.put("sub", monitorStatus(recordId));
        return result;
    }

    // ==================== 内部逻辑 ====================

    private Map<String, Object> requireOwnedActive(Long userId, Long recordId)
    {
        Map<String, Object> record = examMonitorMapper.selectRecordOwned(userId, recordId);
        if (record == null)
        {
            throw new ServiceException("考试记录不存在或无权访问");
        }
        if (asInt(record.get("status")) != 1)
        {
            throw new ServiceException("考试未处于进行中，无需监考");
        }
        return record;
    }

    /** 副机位接入码校验：码匹配且考试进行中，返回记录信息 */
    private Map<String, Object> requireSubCode(Long recordId, String code)
    {
        Map<String, Object> record = examMonitorMapper.selectRecordForMonitor(recordId);
        if (record == null)
        {
            throw new ServiceException("副机位链接无效");
        }
        String stored = asString(record.get("subToken"));
        if (StringUtils.isEmpty(stored) || !stored.equals(code))
        {
            throw new ServiceException("副机位接入码无效");
        }
        if (asInt(record.get("status")) != 1)
        {
            throw new ServiceException("考试未处于进行中，副机位不可加入");
        }
        return record;
    }

    private Map<String, Object> monitorStatus(Long recordId)
    {
        Map<String, Object> monitor = examMonitorMapper.selectMonitor(recordId);
        Map<String, Object> status = new LinkedHashMap<>();
        if (monitor == null)
        {
            status.put("subStatus", 0);
            status.put("subOnline", false);
            return status;
        }
        int subStatus = asInt(monitor.get("subStatus"));
        status.put("subStatus", subStatus);
        status.put("subJoinAt", monitor.get("subJoinAt"));
        status.put("lastHeartbeatAt", monitor.get("lastHeartbeatAt"));
        status.put("subOnline", isSubOnline(subStatus, asTime(monitor.get("lastHeartbeatAt"))));
        return status;
    }

    private boolean isSubOnline(Integer subStatus, LocalDateTime heartbeat)
    {
        if (subStatus == null || subStatus != 1 || heartbeat == null)
        {
            return false;
        }
        return Duration.between(heartbeat, LocalDateTime.now()).getSeconds() <= SUB_ONLINE_WINDOW_SEC;
    }

    private String roomOf(Long recordId)
    {
        return "EXAM-" + recordId;
    }

    /** 笔试监考令牌有效期：至少覆盖4小时长卷场景 */
    private long examTtlSeconds()
    {
        return Math.max(ttlSeconds, 14400L);
    }

    private String issueExamToken(String room, String identity, boolean canPublish)
    {
        if (StringUtils.isEmpty(apiKey) || StringUtils.isEmpty(apiSecret))
        {
            throw new ServiceException("LiveKit 服务未配置（livekit.api-key / livekit.api-secret）");
        }
        long now = System.currentTimeMillis() / 1000L;
        Map<String, Object> video = new LinkedHashMap<>();
        video.put("kind", "participant");
        video.put("room", room);
        video.put("roomJoin", true);
        video.put("canPublish", canPublish);
        video.put("canSubscribe", true);
        video.put("canPublishData", canPublish);

        Map<String, Object> claims = new LinkedHashMap<>();
        claims.put("iss", apiKey);
        claims.put("sub", identity);
        claims.put("nbf", now - 10);
        claims.put("exp", now + examTtlSeconds());
        claims.put("video", video);
        return signHs256(claims);
    }

    /** 生成 LiveKit Access Token（header.payload.signature，Base64URL 无填充） */
    private String signHs256(Map<String, Object> claims)
    {
        try
        {
            Map<String, Object> header = new LinkedHashMap<>();
            header.put("alg", "HS256");
            header.put("typ", "JWT");
            Base64.Encoder encoder = Base64.getUrlEncoder().withoutPadding();
            String signingInput = encoder.encodeToString(objectMapper.writeValueAsBytes(header))
                    + "." + encoder.encodeToString(objectMapper.writeValueAsBytes(claims));
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(apiSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] signature = mac.doFinal(signingInput.getBytes(StandardCharsets.US_ASCII));
            return signingInput + "." + encoder.encodeToString(signature);
        }
        catch (Exception e)
        {
            throw new ServiceException("签发笔试监考令牌失败：" + e.getMessage());
        }
    }

    private Long resolveCompanyId(Long userId)
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        return companyId == null ? 1L : companyId;
    }

    // ==================== 工具 ====================

    private LocalDateTime asTime(Object value)
    {
        String s = asString(value);
        if (s == null)
        {
            return null;
        }
        try
        {
            if (s.length() == 16)
            {
                s = s + ":00";
            }
            return LocalDateTime.parse(s, TIME_FORMAT);
        }
        catch (Exception e)
        {
            return null;
        }
    }

    private Long asLong(Object v)
    {
        if (v == null)
        {
            return null;
        }
        if (v instanceof Number)
        {
            return ((Number) v).longValue();
        }
        String s = v.toString().trim();
        return s.isEmpty() ? null : Long.valueOf(s);
    }

    private int asInt(Object v)
    {
        if (v == null)
        {
            return 0;
        }
        if (v instanceof Number)
        {
            return ((Number) v).intValue();
        }
        String s = v.toString().trim();
        return s.isEmpty() ? 0 : Integer.parseInt(s);
    }

    private String asString(Object v)
    {
        return v == null ? null : String.valueOf(v).trim();
    }
}
