package com.ruoyi.system.service;

import java.util.Properties;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.stereotype.Service;

/**
 * 邮件发送服务
 * 
 * @author ruoyi
 */
@Service
public class EmailService {

    @Autowired
    private JavaMailSender mailSender;

    /** 发件人必须与 SMTP 认证账号一致（QQ 邮箱强制校验），统一从配置读取 */
    @Value("${spring.mail.username}")
    private String from;

    /**
     * 发送简单邮件
     * 
     * @param to 收件人邮箱
     * @param subject 主题
     * @param content 内容
     * @return 是否成功
     */
    public boolean sendSimpleMail(String to, String subject, String content) {
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(from);
            message.setTo(to);
            message.setSubject(subject);
            message.setText(content);
            mailSender.send(message);
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    /**
     * 使用调用方指定的 SMTP 凭据发送简单邮件（个人邮箱发信场景）。
     *
     * <p>发件人强制与认证账号一致（QQ 等邮箱服务端会拒绝不一致的 From），
     * 每次调用动态构建独立 JavaMailSender，不影响全局邮件配置。</p>
     *
     * @param host SMTP 服务器
     * @param port SMTP 端口
     * @param ssl 是否 SSL（465 端口为 true，587 端口为 false 走 STARTTLS）
     * @param username SMTP 认证账号（同时作为发件人）
     * @param password SMTP 认证密码/授权码（明文，由调用方解密后传入）
     * @param to 收件人邮箱
     * @param subject 主题
     * @param content 内容
     * @return 是否成功
     */
    public boolean sendMailWith(String host, int port, boolean ssl, String username, String password,
            String to, String subject, String content) {
        try {
            JavaMailSenderImpl sender = new JavaMailSenderImpl();
            sender.setHost(host);
            sender.setPort(port);
            sender.setUsername(username);
            sender.setPassword(password);
            sender.setDefaultEncoding("UTF-8");
            Properties props = sender.getJavaMailProperties();
            props.put("mail.transport.protocol", "smtp");
            props.put("mail.smtp.auth", "true");
            if (ssl) {
                props.put("mail.smtp.ssl.enable", "true");
            } else {
                props.put("mail.smtp.starttls.enable", "true");
            }
            props.put("mail.smtp.connectiontimeout", "10000");
            props.put("mail.smtp.timeout", "10000");
            props.put("mail.smtp.writetimeout", "10000");
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(username);
            message.setTo(to);
            message.setSubject(subject);
            message.setText(content);
            sender.send(message);
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
}
