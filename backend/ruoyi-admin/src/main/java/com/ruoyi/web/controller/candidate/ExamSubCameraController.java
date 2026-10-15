package com.ruoyi.web.controller.candidate;

import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.enterprise.service.IExamMonitorService;

/**
 * 候选人端 - 笔试副机位（手机 H5 扫码加入，匿名访问）
 *
 * <p>手机扫码进入的 H5 页不携带 Candidate-Token，凭 recordId + 副机位接入码换取
 * LiveKit 入会令牌并上报心跳/断开。接入码由主机位开考时签发，仅考试进行中有效。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/candidate/exam/sub")
public class ExamSubCameraController extends BaseController
{
    @Autowired
    private IExamMonitorService examMonitorService;

    /** 副机位换取入会令牌：body {recordId, code} */
    @Anonymous
    @PostMapping("/join")
    public AjaxResult join(@RequestBody Map<String, Object> body)
    {
        return success(examMonitorService.subJoin(asLong(body.get("recordId")), asString(body.get("code"))));
    }

    /** 副机位心跳保活：body {recordId, code} */
    @Anonymous
    @PostMapping("/ping")
    public AjaxResult ping(@RequestBody Map<String, Object> body)
    {
        return success(examMonitorService.subPing(asLong(body.get("recordId")), asString(body.get("code"))));
    }

    /** 副机位离开：body {recordId, code} */
    @Anonymous
    @PostMapping("/leave")
    public AjaxResult leave(@RequestBody Map<String, Object> body)
    {
        return success(examMonitorService.subLeave(asLong(body.get("recordId")), asString(body.get("code"))));
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

    private String asString(Object v)
    {
        return v == null ? null : String.valueOf(v).trim();
    }
}
