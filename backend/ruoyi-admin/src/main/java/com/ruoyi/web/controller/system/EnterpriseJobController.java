package com.ruoyi.web.controller.system;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.DeleteMapping;
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
import com.ruoyi.system.service.IEnterpriseJobService;
import org.springframework.security.access.prepost.PreAuthorize;

/**
 * 企业端岗位管理（列表页：分页/搜索/状态过滤）
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/system/enterprise/jobs")
@PreAuthorize("@ss.hasAnyRoles('admin,biz_1,biz_2,biz_3')")
public class EnterpriseJobController extends BaseController
{
    @Autowired
    private IEnterpriseJobService jobService;

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
     * 发布前确认企业归属，读取企业和部门选项
     */
    @GetMapping("/publishing-options")
    public AjaxResult publishingOptions()
    {
        return success(jobService.publishingOptions(getUserId()));
    }

    /**
     * 发布新岗位，返回生成的岗位 ID
     */
    @PostMapping
    public AjaxResult create(@RequestBody Map<String, Object> form)
    {
        return success(jobService.createJob(getUserId(), form));
    }

    /** 更新当前企业已有岗位，不改变招聘状态与流程。 */
    @PutMapping("/{posId}")
    public AjaxResult update(@PathVariable("posId") Long posId, @RequestBody Map<String, Object> form)
    {
        return success(jobService.updateJob(getUserId(), posId, form));
    }

    /**
     * 删除岗位（仅允许删除无投递/面试等业务数据的岗位）
     */
    @DeleteMapping("/{posId}")
    public AjaxResult remove(@PathVariable("posId") Long posId)
    {
        return success(jobService.deleteDraftJob(getUserId(), posId));
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
