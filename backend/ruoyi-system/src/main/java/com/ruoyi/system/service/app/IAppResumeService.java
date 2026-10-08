package com.ruoyi.system.service.app;

import java.util.List;
import com.ruoyi.system.domain.app.AppResume;

public interface IAppResumeService
{
    List<AppResume> selectResumeList(Long userId);
    AppResume selectResume(Long userId, Long resumeId);
    AppResume saveResume(Long userId, AppResume resume);
    AppResume parsePdf(byte[] pdfBytes, String originalFilename);
}
