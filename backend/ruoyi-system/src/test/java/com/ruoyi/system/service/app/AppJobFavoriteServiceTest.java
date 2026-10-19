package com.ruoyi.system.service.app;

import java.util.List;
import java.util.Map;
import com.github.pagehelper.Page;
import com.github.pagehelper.PageHelper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.app.AppJob;
import com.ruoyi.system.mapper.app.AppJobFavoriteMapper;
import com.ruoyi.system.service.app.impl.AppJobFavoriteServiceImpl;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AppJobFavoriteServiceTest
{
    private final AppJobFavoriteMapper mapper = mock(AppJobFavoriteMapper.class);
    private final AppJobFavoriteServiceImpl service = new AppJobFavoriteServiceImpl();

    @BeforeEach
    void setup()
    {
        ReflectionTestUtils.setField(service, "favoriteMapper", mapper);
    }

    @AfterEach
    void cleanup()
    {
        PageHelper.clearPage();
    }

    @Test
    void refusesMissingOrUnavailablePositionWithoutWritingFavorite()
    {
        when(mapper.lockAvailablePosition(91L)).thenReturn(null);
        ServiceException error = assertThrows(ServiceException.class, () -> service.setFavorited(17L, 91L, true));
        assertEquals(404, error.getCode());
        verify(mapper, never()).favorite(17L, 91L);
    }

    @Test
    void scopesWritesAndReturnsConfirmedStateForCurrentAccount()
    {
        when(mapper.lockAvailablePosition(91L)).thenReturn(91L);
        when(mapper.isFavorited(17L, 91L)).thenReturn(true);
        assertTrue(service.setFavorited(17L, 91L, true));
        verify(mapper).favorite(17L, 91L);
        assertFalse(service.isFavorited(18L, 91L));
        verify(mapper).isFavorited(18L, 91L);
    }

    @Test
    void canCancelUnavailableOrDeletedPositionWithoutCheckingAvailability()
    {
        assertFalse(service.setFavorited(17L, 91L, false));
        verify(mapper).unfavorite(17L, 91L);
        verify(mapper, never()).lockAvailablePosition(91L);
    }

    @Test
    void preservesDatabasePagingAndUnavailableItems()
    {
        AppJob offline = new AppJob();
        offline.setPositionId(91L);
        offline.setAvailable(false);
        Page<AppJob> page = new Page<>(2, 20);
        page.setTotal(41);
        page.add(offline);
        when(mapper.selectFavorites(17L)).thenReturn(page);
        Map<String, Object> result = service.selectFavorites(17L, 2, 20);
        assertEquals(List.of(offline), result.get("items"));
        assertEquals(2, result.get("page"));
        assertEquals(41L, result.get("total"));
        assertEquals(true, result.get("hasNext"));
        assertFalse(offline.getAvailable());
        assertNull(offline.getMatchScore());
    }

    @Test
    void emptyFavoritesHaveNoNextPage()
    {
        when(mapper.selectFavorites(18L)).thenReturn(List.of());
        Map<String, Object> result = service.selectFavorites(18L, 1, 20);
        assertEquals(0L, result.get("total"));
        assertEquals(false, result.get("hasNext"));
    }
}
