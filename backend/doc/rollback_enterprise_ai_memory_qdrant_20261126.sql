-- Rollback for enterprise recruiter multi-fact memory. Stop the backend first.
-- Fixed t_enterprise_ai_memory preferences and session summaries are not touched.
DROP TABLE IF EXISTS t_enterprise_ai_memory_outbox;
DROP TABLE IF EXISTS t_enterprise_ai_memory_fact;
