package com.ruoyi.common.filter;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;
import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.FilterConfig;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * 防盗链过滤器
 * 
 * @author ruoyi
 */
public class RefererFilter implements Filter
{
    /**
     * 允许的域名列表
     */
    public List<String> allowedDomains;

    @Override
    public void init(FilterConfig filterConfig) throws ServletException
    {
        String domains = filterConfig.getInitParameter("allowedDomains");
        this.allowedDomains = Arrays.asList(domains.split(","));
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException
    {
        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse resp = (HttpServletResponse) response;

        String referer = req.getHeader("Referer");

        // 原生客户端（例如 Flutter Image.network）通常不会发送 Referer。
        // 资源本身已经通过公开资源路由和文件名校验控制访问范围，缺少该可选请求头时应继续处理。
        if (referer == null || referer.isBlank())
        {
            chain.doFilter(request, response);
            return;
        }

        // 检查Referer是否在允许的域名列表中
        boolean allowed = false;
        for (String domain : allowedDomains)
        {
            if (referer.contains(domain))
            {
                allowed = true;
                break;
            }
        }

        // 根据检查结果决定是否放行
        if (allowed)
        {
            chain.doFilter(request, response);
        }
        else
        {
            resp.sendError(HttpServletResponse.SC_FORBIDDEN, "Access denied: Referer '" + referer + "' is not allowed");
        }
    }

    @Override
    public void destroy()
    {

    }
}
