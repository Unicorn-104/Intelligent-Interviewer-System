package com.ruoyi.web.controller.common;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.service.storage.AvatarStorage;

/** 与旧 /profile/avatar 一样公开展示头像；不能借此读取私有文件。 */
@RestController
public class StoredAvatarController
{
    // 临时诊断日志：确认头像请求是否到达控制器（诊断后可移除）
    private static final Logger diagLog = LoggerFactory.getLogger("S3_DIAG");
    private final AvatarStorage avatars;

    public StoredAvatarController(AvatarStorage avatars) { this.avatars = avatars; }

    @GetMapping("/profile/storage/avatars/{userId}/{year}/{month}/{day}/{fileName}")
    public ResponseEntity<Resource> avatar(@PathVariable Long userId,
            @PathVariable String year, @PathVariable String month, @PathVariable String day,
            @PathVariable String fileName)
    {
        String key = "avatars/" + userId + "/" + year + "/" + month + "/" + day + "/" + fileName;
        diagLog.info("controller hit userId={}, key={}", userId, key);
        try
        {
            Resource resource = avatars.read(key);
            String extension = fileName.substring(fileName.lastIndexOf('.') + 1);
            return ResponseEntity.ok().contentType(MediaType.parseMediaType(avatars.contentType(extension)))
                    .header("Cache-Control", "public, max-age=86400, immutable")
                    .header("X-Content-Type-Options", "nosniff")
                    .body(resource);
        }
        catch (ServiceException error)
        {
            diagLog.warn("controller service error: {}", error.getMessage());
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }
    }
}
