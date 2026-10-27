package com.ruoyi.web.controller.enterprise;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.enterprise.service.IInterviewerSlotService;

/**
 * 面试官空闲时段（面试安排页）
 */
@RestController
@RequestMapping("/enterprise/interviewer-slots")
public class InterviewerSlotController extends BaseController
{
    @Autowired
    private IInterviewerSlotService slotService;

    /**
     * 查询当前登录面试官某周的空闲时段
     */
    @GetMapping
    public AjaxResult list(@RequestParam(required = false) String weekStart)
    {
        return success(slotService.listSlots(getUserId(), weekStart));
    }

    /**
     * 整周覆盖保存空闲时段（先删后插，仅作用于当前登录用户）
     */
    @PostMapping
    public AjaxResult save(@RequestBody Map<String, Object> body)
    {
        String weekStart = body.get("weekStart") == null ? null : String.valueOf(body.get("weekStart"));
        List<Map<String, Object>> slots = new ArrayList<>();
        Object raw = body.get("slots");
        if (raw instanceof List)
        {
            for (Object item : (List<?>) raw)
            {
                if (item instanceof Map)
                {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> slot = (Map<String, Object>) item;
                    slots.add(slot);
                }
            }
        }
        return success(slotService.saveSlots(getUserId(), weekStart, slots));
    }
}
