package com.ruoyi.framework.filter;

import java.io.IOException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * 接口版本前缀兼容过滤器
 * 
 * 将版本化路径 /api/v1/** 重写为原有路径 /**，使新旧路径同时可用，
 * 各端可逐步迁移到 /api/v1，迁移期间出现问题时可直接回退到旧路径。
 * 
 * @author MZR
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class ApiVersionPrefixFilter extends OncePerRequestFilter
{
    /**
     * 版本前缀
     */
    private static final String API_VERSION_PREFIX = "/api/v1";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException
    {
        String uri = request.getRequestURI();
        if (uri != null && uri.startsWith(request.getContextPath() + API_VERSION_PREFIX))
        {
            filterChain.doFilter(new ApiVersionRequestWrapper(request), response);
        }
        else
        {
            filterChain.doFilter(request, response);
        }
    }

    /**
     * 去掉版本前缀后的请求包装，供 Spring Security 与 Spring MVC 按原路径匹配
     */
    private static class ApiVersionRequestWrapper extends HttpServletRequestWrapper
    {
        private final String requestURI;

        private final String servletPath;

        ApiVersionRequestWrapper(HttpServletRequest request)
        {
            super(request);
            String contextPath = request.getContextPath();
            String path = request.getRequestURI().substring(contextPath.length() + API_VERSION_PREFIX.length());
            this.servletPath = path.isEmpty() ? "/" : path;
            this.requestURI = contextPath + this.servletPath;
        }

        @Override
        public String getRequestURI()
        {
            return requestURI;
        }

        @Override
        public String getServletPath()
        {
            return servletPath;
        }
    }
}