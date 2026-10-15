package com.ruoyi.common.constant;

/**
 * 业务错误码
 *
 * 约定：2xx 表示成功，4xx 表示客户端错误（参数、认证、权限、资源），5xx 表示服务端错误。
 * 1000 起的区间预留给后续业务错误码，通过 ServiceException(message, code) 携带。
 *
 * @author ruoyi
 */
public class ErrorCode
{
    /**
     * 操作成功
     */
    public static final int SUCCESS = 200;

    /**
     * 参数错误（缺少、格式不匹配、校验不通过）
     */
    public static final int BAD_REQUEST = 400;

    /**
     * 未认证或登录状态已过期
     */
    public static final int UNAUTHORIZED = 401;

    /**
     * 无访问权限
     */
    public static final int FORBIDDEN = 403;

    /**
     * 资源不存在
     */
    public static final int NOT_FOUND = 404;

    /**
     * 请求方式不支持
     */
    public static final int METHOD_NOT_ALLOWED = 405;

    /**
     * 资源冲突
     */
    public static final int CONFLICT = 409;

    /**
     * 系统内部错误
     */
    public static final int ERROR = 500;

    /**
     * 接口未实现
     */
    public static final int NOT_IMPLEMENTED = 501;

    /**
     * 系统警告消息
     */
    public static final int WARN = 601;

    /**
     * 业务处理失败（通用业务错误码）
     */
    public static final int BUSINESS_ERROR = 1000;
}