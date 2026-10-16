package com.ruoyi.enterprise.util;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import com.ruoyi.common.exception.ServiceException;

/**
 * 个人邮箱 SMTP 授权码加解密组件（AES-256/GCM）
 *
 * <p>密钥取自配置项 {@code offer.mail.crypto-key}，经 SHA-256 派生为 32 字节 AES 密钥；
 * 每次加密随机生成 12 字节 IV，密文格式为 Base64(IV + GCM密文)。</p>
 *
 * @author enterprise
 */
@Component
public class MailCredentialCipher
{
    private static final int IV_LENGTH = 12;

    private static final int TAG_BITS = 128;

    @Value("${offer.mail.crypto-key:Intelligent-Interviewer-Mail@2026}")
    private String keyText;

    /** 加密明文，返回 Base64(IV + 密文) */
    public String encrypt(String plain)
    {
        try
        {
            byte[] iv = new byte[IV_LENGTH];
            new SecureRandom().nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, aesKey(), new GCMParameterSpec(TAG_BITS, iv));
            byte[] encrypted = cipher.doFinal(plain.getBytes(StandardCharsets.UTF_8));
            byte[] combined = new byte[iv.length + encrypted.length];
            System.arraycopy(iv, 0, combined, 0, iv.length);
            System.arraycopy(encrypted, 0, combined, iv.length, encrypted.length);
            return Base64.getEncoder().encodeToString(combined);
        }
        catch (Exception e)
        {
            throw new ServiceException("授权码加密失败");
        }
    }

    /** 解密 Base64(IV + 密文)，还原明文 */
    public String decrypt(String encoded)
    {
        try
        {
            byte[] combined = Base64.getDecoder().decode(encoded);
            byte[] iv = Arrays.copyOfRange(combined, 0, IV_LENGTH);
            byte[] cipherText = Arrays.copyOfRange(combined, IV_LENGTH, combined.length);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, aesKey(), new GCMParameterSpec(TAG_BITS, iv));
            return new String(cipher.doFinal(cipherText), StandardCharsets.UTF_8);
        }
        catch (Exception e)
        {
            throw new ServiceException("授权码解密失败，配置凭据可能已损坏");
        }
    }

    private SecretKeySpec aesKey()
    {
        try
        {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(keyText.getBytes(StandardCharsets.UTF_8));
            return new SecretKeySpec(digest, "AES");
        }
        catch (Exception e)
        {
            throw new ServiceException("加密密钥初始化失败");
        }
    }
}
