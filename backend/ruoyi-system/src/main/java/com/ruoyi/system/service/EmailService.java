package com.ruoyi.system.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
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
            message.setFrom("2969423337@qq.com");
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
}
