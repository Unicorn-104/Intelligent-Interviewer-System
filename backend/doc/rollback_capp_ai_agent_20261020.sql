-- Destructive: back up user conversations first. Stop AI workers before rollback.
-- Execute only when intentionally removing all AI conversation data.
DROP TABLE IF EXISTS t_capp_ai_event;
DROP TABLE IF EXISTS t_capp_ai_message;
DROP TABLE IF EXISTS t_capp_ai_run;
DROP TABLE IF EXISTS t_capp_ai_session;
