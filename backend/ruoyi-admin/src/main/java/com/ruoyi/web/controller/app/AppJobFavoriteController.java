package com.ruoyi.web.controller.app;

import java.util.Map;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.service.app.IAppJobFavoriteService;

/** 仅从登录态获取用户 ID，收藏不接受客户端指定用户。 */
@Validated
@RestController
@RequestMapping("/app/jobs")
public class AppJobFavoriteController extends BaseController
{
    @Autowired
    private IAppJobFavoriteService favoriteService;

    public record FavoriteRequest(@NotNull Boolean favorited) { }

    @GetMapping("/{positionId}/favorite")
    public AjaxResult state(@PathVariable @Positive Long positionId)
    {
        return success(Map.of("favorited", favoriteService.isFavorited(getUserId(), positionId)));
    }

    @PutMapping("/{positionId}/favorite")
    public AjaxResult save(@PathVariable @Positive Long positionId, @Valid @RequestBody FavoriteRequest request)
    {
        return success(Map.of("favorited", favoriteService.setFavorited(getUserId(), positionId, request.favorited())));
    }

    @GetMapping("/favorites")
    public AjaxResult favorites(@RequestParam(defaultValue = "1") @Min(1) Integer page,
                               @RequestParam(defaultValue = "20") @Min(1) @Max(100) Integer size)
    {
        return success(favoriteService.selectFavorites(getUserId(), page, size));
    }
}
