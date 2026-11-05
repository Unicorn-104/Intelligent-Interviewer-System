package com.ruoyi.web.controller.common;

import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.service.storage.PublicUploadStorage;

/** 仅代理通用上传的公开命名空间，不提供私有简历或任意对象下载。 */
@RestController
public class StoredUploadController
{
    private final PublicUploadStorage uploads;

    public StoredUploadController(PublicUploadStorage uploads) { this.uploads = uploads; }

    @GetMapping("/profile/storage/uploads/{userId}/{year}/{month}/{day}/{fileName}")
    public ResponseEntity<Resource> file(@PathVariable Long userId, @PathVariable String year,
            @PathVariable String month, @PathVariable String day, @PathVariable String fileName)
    {
        String path = PublicUploadStorage.URL_PREFIX + userId + "/" + year + "/" + month + "/" + day + "/" + fileName;
        try
        {
            Resource resource = uploads.read(path);
            String extension = fileName.substring(fileName.lastIndexOf('.') + 1);
            String type = uploads.contentType(extension);
            ContentDisposition disposition = (type.startsWith("image/")
                    ? ContentDisposition.inline() : ContentDisposition.attachment()).filename(fileName).build();
            return ResponseEntity.ok().contentType(MediaType.parseMediaType(type))
                    .header(HttpHeaders.CONTENT_DISPOSITION, disposition.toString())
                    .header(HttpHeaders.CACHE_CONTROL, "private, no-store")
                    .header("X-Content-Type-Options", "nosniff").body(resource);
        }
        catch (ServiceException error) { throw new ResponseStatusException(HttpStatus.NOT_FOUND); }
    }
}
