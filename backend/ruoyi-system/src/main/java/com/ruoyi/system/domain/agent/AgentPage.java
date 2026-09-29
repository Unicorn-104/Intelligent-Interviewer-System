package com.ruoyi.system.domain.agent;

import java.util.List;

/**
 * 求职者端分页响应。
 *
 * @param <T> item type
 */
public class AgentPage<T>
{
    private List<T> items;
    private int page;
    private int size;
    private long total;
    private boolean hasNext;

    public AgentPage()
    {
    }

    public AgentPage(List<T> items, int page, int size, long total)
    {
        this.items = items;
        this.page = page;
        this.size = size;
        this.total = total;
        this.hasNext = (long) page * size < total;
    }

    public List<T> getItems()
    {
        return items;
    }

    public void setItems(List<T> items)
    {
        this.items = items;
    }

    public int getPage()
    {
        return page;
    }

    public void setPage(int page)
    {
        this.page = page;
    }

    public int getSize()
    {
        return size;
    }

    public void setSize(int size)
    {
        this.size = size;
    }

    public long getTotal()
    {
        return total;
    }

    public void setTotal(long total)
    {
        this.total = total;
    }

    public boolean isHasNext()
    {
        return hasNext;
    }

    public void setHasNext(boolean hasNext)
    {
        this.hasNext = hasNext;
    }
}
