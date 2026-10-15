package com.ruoyi.web.controller.system;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import com.ruoyi.system.service.IEnterpriseJobService;
import com.ruoyi.system.service.agent.IAgentJobService;
import jakarta.validation.Valid;

/**
 * 企业端岗位管理（列表页：分页/搜索/状态过滤）
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/system/enterprise/jobs")
public class EnterpriseJobController extends BaseController
{
    @Autowired
    private IEnterpriseJobService jobService;

    @Autowired
    private IAgentJobService agentJobService;

    /**
     * 查询企业已发布岗位，供求职者端岗位浏览使用。
     */
    @GetMapping
    public AjaxResult publicJobs(@Valid AgentJobQuery query)
    {
        return success(agentJobService.selectJobs(query, getUserId()));
    }

    /**
     * 查询求职者端岗位分类选项。
     */
    @GetMapping("/categories")
    public AjaxResult categories()
    {
        return success(agentJobService.selectJobCategories());
    }

    /**
     * 查询求职者端岗位多维筛选选项。
     */
    @GetMapping("/filter-options")
    public AjaxResult filterOptions()
    {
        return success(agentJobService.selectJobFilterOptions());
    }

    /**
     * 分页查询当前公司岗位，支持 keyword/dept/status 过滤
     */
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) String keyword,
                              @RequestParam(required = false) String dept,
                              @RequestParam(required = false) Integer status)
    {
        Long companyId = jobService.resolveCompanyId(getUserId());
        startPage();
        List<Map<String, Object>> list = jobService.selectJobList(companyId, keyword, dept, status);
        return getDataTable(list);
    }

    /**
     * 当前公司岗位部门选项
     */
    @GetMapping("/departments")
    public AjaxResult departments()
    {
        return success(jobService.selectJobDepartments(getUserId()));
    }

    /**
     * 切换岗位状态（0下线/1在招/2暂停）
     */
    @PutMapping("/{posId}/status/{status}")
    public AjaxResult changeStatus(@PathVariable("posId") Long posId, @PathVariable("status") Integer status)
    {
        return toAjax(jobService.changeJobStatus(getUserId(), posId, status));
    }

    /**
     * 发布新岗位
     */
    @PostMapping
    public AjaxResult create(@RequestBody Map<String, Object> form)
    {
        return success(jobService.createJob(getUserId(), form));
    }

    /**
     * 岗位详情聚合
     */
    @GetMapping("/{posId}")
    public AjaxResult detail(@PathVariable("posId") Long posId)
    {
        return success(jobService.jobDetail(getUserId(), posId));
    }

    /**
     * 岗位流程配置读取
     */
    @GetMapping("/{posId}/workflow")
    public AjaxResult workflow(@PathVariable("posId") Long posId)
    {
        return success(jobService.workflow(getUserId(), posId));
    }

    /**
     * 保存岗位流程配置
     */
    @PutMapping("/{posId}/workflow")
    public AjaxResult saveWorkflow(@PathVariable("posId") Long posId, @RequestBody Map<String, Object> body)
    {
        String name = body.get("templateName") == null ? null : String.valueOf(body.get("templateName"));
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> stages = (List<Map<String, Object>>) body.get("stages");
        return success(jobService.saveWorkflow(getUserId(), posId, name, stages));
    }
}
