package com.ruoyi.web.controller.common;

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
    private final AvatarStorage avatars;

    public StoredAvatarController(AvatarStorage avatars) { this.avatars = avatars; }

    @GetMapping("/profile/storage/avatars/{userId}/{year}/{month}/{day}/{fileName}")
    public ResponseEntity<Resource> avatar(@PathVariable Long userId,
            @PathVariable String year, @PathVariable String month, @PathVariable String day,
            @PathVariable String fileName)
    {
        String key = "avatars/" + userId + "/" + year + "/" + month + "/" + day + "/" + fileName;
        try
        {
            Resource resource = avatars.read(key);
            String extension = fileName.substring(fileName.lastIndexOf('.') + 1);
            return ResponseEntity.ok().contentType(MediaType.parseMediaType(avatars.contentType(extension)))
                    .header("Cache-Control", "public, max-age=86400, immutable")
                    .header("X-Content-Type-Options", "nosniff")
                    .body(resource);
        }
        catch (ServiceException error) { throw new ResponseStatusException(HttpStatus.NOT_FOUND); }
    }
}
