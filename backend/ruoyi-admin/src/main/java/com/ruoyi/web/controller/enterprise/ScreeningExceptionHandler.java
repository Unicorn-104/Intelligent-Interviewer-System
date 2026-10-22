package com.ruoyi.web.controller.enterprise;

import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.dao.DataAccessException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import com.ruoyi.common.core.domain.AjaxResult;

/** Do not expose SQL, paths or resume evidence in screening database error responses. */
@Order(Ordered.HIGHEST_PRECEDENCE)
@RestControllerAdvice(assignableTypes = ScreeningController.class)
public class ScreeningExceptionHandler
{
    @ExceptionHandler(DataAccessException.class)
    public AjaxResult databaseFailure(DataAccessException error)
    {
        return AjaxResult.error("分析数据查询失败，请稍后重试；如持续出现，请更新服务器后端");
    }
}
