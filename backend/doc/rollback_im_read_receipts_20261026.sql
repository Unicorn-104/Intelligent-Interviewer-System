-- 先回滚应用，停用回执接口并备份此表；删除会丢失回执，聊天记录不受影响。
-- 仅在维护者明确授权后执行，应用运行中不要删除。
DROP TABLE IF EXISTS t_im_read_cursor;
