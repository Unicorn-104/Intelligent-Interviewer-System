package com.ruoyi.web.controller.enterprise.ai.agent;

import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.enterprise.ai.knowledge.EnterpriseKnowledgeService;
import com.ruoyi.system.mapper.DashboardMapper;
import org.springframework.web.bind.annotation.*;

/** CRUD for text knowledge owned by the authenticated enterprise. */
@RestController
@RequestMapping("/enterprise/assistant/knowledge")
public class EnterpriseKnowledgeController extends BaseController
{
    private final EnterpriseKnowledgeService knowledge;
    private final DashboardMapper companies;
    public EnterpriseKnowledgeController(EnterpriseKnowledgeService knowledge,DashboardMapper companies)
    { this.knowledge=knowledge;this.companies=companies; }
    public record DocumentRequest(String name,String content) { }
    public record SearchRequest(String query) { }
    @GetMapping("/documents") public AjaxResult documents()
    { return success(knowledge.documents(company())); }
    @PostMapping("/documents") public AjaxResult create(@RequestBody DocumentRequest body)
    { if(body==null) throw new com.ruoyi.common.exception.ServiceException("知识库参数无效",400); return success(knowledge.create(company(),body.name(),body.content())); }
    @DeleteMapping("/documents/{id}") public AjaxResult delete(@PathVariable String id)
    { knowledge.delete(company(),id); return success(); }
    @PostMapping("/search") public AjaxResult search(@RequestBody SearchRequest body)
    { if(body==null) throw new com.ruoyi.common.exception.ServiceException("检索参数无效",400); return success(knowledge.search(company(),body.query(),System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(8))); }
    @PostMapping("/reindex") public AjaxResult reindex()
    { return success(knowledge.reindex(company())); }
    private long company()
    { Long id=companies.selectCompanyIdByUser(getUserId()); if(id==null||id<=0) throw new com.ruoyi.common.exception.ServiceException("请先完成企业绑定",403); return id; }
}
