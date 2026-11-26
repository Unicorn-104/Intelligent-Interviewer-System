package com.ruoyi.framework.interceptor;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import com.github.pagehelper.PageHelper;

/**
 * 请求结束后清理 PageHelper 的分页线程变量。
 *
 * <p>startPage() 只是把分页参数放进 ThreadLocal，由 MyBatis 拦截器消费；
 * 若控制器随后走的是 JdbcTemplate（或未调用 getDataTable），参数会残留在 Tomcat 复用线程上，
 * 导致下一个无关的 MyBatis 查询被意外加上 LIMIT。这里做统一兜底。
 *
 * @author TQY
 */
@Component
public class PageContextCleanInterceptor implements HandlerInterceptor
{
    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex)
    {
        PageHelper.clearPage();
    }
}
