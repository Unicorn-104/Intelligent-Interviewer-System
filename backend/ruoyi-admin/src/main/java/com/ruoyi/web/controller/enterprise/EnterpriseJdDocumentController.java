package com.ruoyi.web.controller.enterprise;

import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.multipart.MultipartHttpServletRequest;
import com.ruoyi.common.constant.ErrorCode;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.service.IJdDocumentService;

/** Import a document into an editable JD draft; publishing remains a separate user action. */
@RestController
@RequestMapping("/enterprise/jd")
@PreAuthorize("@ss.hasAnyRoles('biz_1,biz_2,biz_3')")
public class EnterpriseJdDocumentController extends BaseController
{
    private final IJdDocumentService documentService;

    public EnterpriseJdDocumentController(IJdDocumentService documentService)
    {
        this.documentService = documentService;
    }

    @PostMapping(value = "/parse-document", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public AjaxResult parseDocument(@RequestParam("file") MultipartFile file, MultipartHttpServletRequest request)
    {
        long count = request.getMultiFileMap().values().stream().mapToLong(java.util.List::size).sum();
        if (count != 1)
        {
            throw new ServiceException("每次只能上传一个 JD 文档", ErrorCode.BAD_REQUEST);
        }
        return success(documentService.parseDocument(getUserId(), file));
    }
}
