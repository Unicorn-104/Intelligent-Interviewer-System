package com.ruoyi.common.utils;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import com.ruoyi.common.exception.ServiceException;

/**
 * 第三方凭据加解密工具（AES-256/GCM）。
 *
 * <p>密钥文本经 SHA-256 派生为 32 字节 AES 密钥；每次加密随机生成 12 字节 IV，
 * 密文格式为 {@code ENC:Base64(IV + GCM密文)}。无前缀的值按历史明文原样使用。</p>
 */
public final class CredentialCipher
{
    private static final String PREFIX = "ENC:";

    private static final int IV_LENGTH = 12;

    private static final int TAG_BITS = 128;

    private CredentialCipher()
    {
    }

    public static boolean isEncrypted(String stored)
    {
        return stored != null && stored.startsWith(PREFIX);
    }

    public static String encrypt(String plain, String keyText)
    {
        if (plain == null || plain.isEmpty() || isEncrypted(plain))
        {
            return plain;
        }
        try
        {
            byte[] iv = new byte[IV_LENGTH];
            new SecureRandom().nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, aesKey(keyText), new GCMParameterSpec(TAG_BITS, iv));
            byte[] encrypted = cipher.doFinal(plain.getBytes(StandardCharsets.UTF_8));
            byte[] combined = new byte[iv.length + encrypted.length];
            System.arraycopy(iv, 0, combined, 0, iv.length);
            System.arraycopy(encrypted, 0, combined, iv.length, encrypted.length);
            return PREFIX + Base64.getEncoder().encodeToString(combined);
        }
        catch (Exception e)
        {
            throw new ServiceException("凭据加密失败");
        }
    }

    public static String decrypt(String stored, String keyText)
    {
        if (!isEncrypted(stored))
        {
            return stored;
        }
        try
        {
            byte[] combined = Base64.getDecoder().decode(stored.substring(PREFIX.length()));
            byte[] iv = Arrays.copyOfRange(combined, 0, IV_LENGTH);
            byte[] cipherText = Arrays.copyOfRange(combined, IV_LENGTH, combined.length);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, aesKey(keyText), new GCMParameterSpec(TAG_BITS, iv));
            return new String(cipher.doFinal(cipherText), StandardCharsets.UTF_8);
        }
        catch (Exception e)
        {
            throw new ServiceException("凭据解密失败，请检查加密主密钥是否变更");
        }
    }

    private static SecretKeySpec aesKey(String keyText) throws Exception
    {
        byte[] digest = MessageDigest.getInstance("SHA-256")
                .digest(keyText.getBytes(StandardCharsets.UTF_8));
        return new SecretKeySpec(digest, "AES");
    }
}
