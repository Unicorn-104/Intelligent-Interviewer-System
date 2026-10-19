package com.ruoyi.enterprise.service;

import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.enterprise.domain.JdDocumentDraft;

public interface IJdDocumentService
{
    /** Parse an authenticated enterprise user's document without saving a job or attachment. */
    JdDocumentDraft parseDocument(Long userId, MultipartFile file);
}
