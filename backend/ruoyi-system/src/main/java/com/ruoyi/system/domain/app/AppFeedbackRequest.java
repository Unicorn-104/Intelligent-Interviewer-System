package com.ruoyi.system.domain.app;

import java.io.Serializable;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** C-App 用户反馈提交参数。 */
public class AppFeedbackRequest implements Serializable
{
    private static final long serialVersionUID = 1L;

    @NotNull(message = "请选择反馈类型")
    @Min(value = 1, message = "反馈类型不正确")
    @Max(value = 4, message = "反馈类型不正确")
    private Integer type;

    @NotBlank(message = "反馈标题不能为空")
    @Size(max = 200, message = "反馈标题不能超过200个字符")
    private String subject;

    @NotBlank(message = "请填写详细描述")
    @Size(max = 2000, message = "详细描述不能超过2000个字符")
    private String description;

    public Integer getType() { return type; }
    public void setType(Integer type) { this.type = type; }
    public String getSubject() { return subject; }
    public void setSubject(String subject) { this.subject = subject; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
}
