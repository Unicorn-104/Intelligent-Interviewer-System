package com.ruoyi.system.domain.app.ai;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record AgentRunRequest(
        @NotBlank @Pattern(regexp = "[a-zA-Z0-9-]{16,36}") String requestId,
        @NotBlank @Size(max = 4000) String content,
        @Positive Long resumeId,
        @Positive Long applicationId,
        @Pattern(regexp = "chat|job_recommendation|resume_analysis|interview_preparation|writing_polish") String action)
{
    public AgentRunRequest
    {
        if (action == null) action = "chat";
    }

    public AgentRunRequest(String requestId, String content, Long resumeId)
    { this(requestId, content, resumeId, null, "chat"); }
}
