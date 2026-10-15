package com.ruoyi.system.service.impl;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.service.ILiveKitEgressService;

/**
 * LiveKit Egress（服务端录制）调用服务实现
 * <p>
 * 走 Egress 的 Twirp JSON 接口（/twirp/livekit.Egress/xxx），
 * 鉴权 JWT 与 Access Token 同源，仅额外声明 video.roomRecord。
 *
 * @author YLX
 */
@Service
public class LiveKitEgressServiceImpl implements ILiveKitEgressService
{
    @Value("${livekit.api-key:}")
    private String apiKey;

    @Value("${livekit.api-secret:}")
    private String apiSecret;

    /** Egress Twirp 接口地址 */
    @Value("${livekit.egress-url:http://localhost:8089}")
    private String egressUrl;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    @Override
    public String startRoomRecording(String roomName, String filepath)
    {
        if (StringUtils.isEmpty(roomName) || StringUtils.isEmpty(filepath))
        {
            throw new ServiceException("录制参数不完整");
        }
        Map<String, Object> fileOutput = new LinkedHashMap<>();
        fileOutput.put("file_type", "MP4");
        fileOutput.put("filepath", filepath);
        List<Map<String, Object>> fileOutputs = new ArrayList<>();
        fileOutputs.add(fileOutput);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("room_name", roomName);
        // 宫格合成：所有参与者画面统一并排，与前端会议布局语义一致
        body.put("layout", "grid");
        body.put("audio_only", false);
        body.put("file_outputs", fileOutputs);

        JSONObject response = twirp("StartRoomCompositeEgress", body);
        String egressId = response == null ? null : response.getString("egress_id");
        if (StringUtils.isEmpty(egressId))
        {
            throw new ServiceException("LiveKit 录制任务启动失败：未返回任务ID");
        }
        return egressId;
    }

    @Override
    public void stopEgress(String egressId)
    {
        if (StringUtils.isEmpty(egressId))
        {
            throw new ServiceException("录制任务ID为空，无法停止录制");
        }
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("egress_id", egressId);
        twirp("StopEgress", body);
    }

    /**
     * 调用 Egress Twirp 接口（JSON 编码），失败时抛出带服务端错误信息的业务异常
     */
    private JSONObject twirp(String method, Map<String, Object> body)
    {
        if (StringUtils.isEmpty(apiKey) || StringUtils.isEmpty(apiSecret))
        {
            throw new ServiceException("LiveKit 服务未配置（livekit.api-key / livekit.api-secret）");
        }
        try
        {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(egressUrl + "/twirp/livekit.Egress/" + method))
                    .timeout(Duration.ofSeconds(10))
                    .header("Content-Type", "application/json")
                    .header("Authorization", "Bearer " + signRecordToken())
                    .POST(HttpRequest.BodyPublishers.ofString(JSON.toJSONString(body), StandardCharsets.UTF_8))
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            String text = response.body() == null ? "" : response.body();
            if (response.statusCode() < 200 || response.statusCode() >= 300)
            {
                String reason = text;
                try
                {
                    JSONObject error = JSON.parseObject(text);
                    reason = error == null ? text : error.getString("msg");
                }
                catch (Exception ignore)
                {
                    // 非 JSON 错误体时直接使用原始响应
                }
                throw new ServiceException("LiveKit 录制接口调用失败：" + reason);
            }
            return StringUtils.isEmpty(text) ? new JSONObject() : JSON.parseObject(text);
        }
        catch (ServiceException e)
        {
            throw e;
        }
        catch (Exception e)
        {
            throw new ServiceException("无法连接 LiveKit 录制服务：" + e.getMessage());
        }
    }

    /** 生成 Egress 专属 JWT（含 video.roomRecord 声明，有效期 10 分钟） */
    private String signRecordToken()
    {
        long now = System.currentTimeMillis() / 1000L;
        Map<String, Object> video = new LinkedHashMap<>();
        video.put("roomRecord", true);
        Map<String, Object> claims = new LinkedHashMap<>();
        claims.put("iss", apiKey);
        claims.put("sub", apiKey);
        claims.put("nbf", now - 10);
        claims.put("exp", now + 600);
        claims.put("video", video);
        try
        {
            Map<String, Object> header = new LinkedHashMap<>();
            header.put("alg", "HS256");
            header.put("typ", "JWT");
            Base64.Encoder encoder = Base64.getUrlEncoder().withoutPadding();
            String signingInput = encoder.encodeToString(JSON.toJSONBytes(header))
                    + "." + encoder.encodeToString(JSON.toJSONBytes(claims));
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(apiSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return signingInput + "." + encoder.encodeToString(mac.doFinal(signingInput.getBytes(StandardCharsets.US_ASCII)));
        }
        catch (Exception e)
        {
            throw new ServiceException("签发 LiveKit 录制令牌失败：" + e.getMessage());
        }
    }
}
