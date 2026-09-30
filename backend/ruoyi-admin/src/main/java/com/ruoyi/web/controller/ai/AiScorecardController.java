package com.ruoyi.web.controller.ai;

import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.page.TableDataInfo;
import java.util.*;

/**
 * AI记分卡配置（对齐前端 /ai/scorecard 接口）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/ai/scorecard")
public class AiScorecardController extends BaseController {

    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        
        // 返回测试数据
        List<Map<String, Object>> result = new ArrayList<>();
        
        Map<String, Object> item1 = new HashMap<>();
        item1.put("id", 1);
        item1.put("cardName", "技术岗位评分卡");
        item1.put("jobDirection", "技术面");
        List<Map<String, Object>> dims1 = new ArrayList<>();
        Map<String, Object> d1 = new HashMap<>();
        d1.put("name", "技术能力");
        d1.put("weight", 40);
        dims1.add(d1);
        Map<String, Object> d2 = new HashMap<>();
        d2.put("name", "沟通能力");
        d2.put("weight", 30);
        dims1.add(d2);
        Map<String, Object> d3 = new HashMap<>();
        d3.put("name", "项目经验");
        d3.put("weight", 30);
        dims1.add(d3);
        item1.put("dimensions", dims1);
        item1.put("status", 1);
        result.add(item1);
        
        Map<String, Object> item2 = new HashMap<>();
        item2.put("id", 2);
        item2.put("cardName", "HR岗位评分卡");
        item2.put("jobDirection", "HR面");
        List<Map<String, Object>> dims2 = new ArrayList<>();
        Map<String, Object> d4 = new HashMap<>();
        d4.put("name", "沟通能力");
        d4.put("weight", 40);
        dims2.add(d4);
        Map<String, Object> d5 = new HashMap<>();
        d5.put("name", "应变能力");
        d5.put("weight", 30);
        dims2.add(d5);
        Map<String, Object> d6 = new HashMap<>();
        d6.put("name", "服务意识");
        d6.put("weight", 30);
        dims2.add(d6);
        item2.put("dimensions", dims2);
        item2.put("status", 1);
        result.add(item2);
        
        return getDataTable(result);
    }
}
