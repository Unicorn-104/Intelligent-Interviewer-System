-- Stop the knowledge worker and disable RAG first. Back up user data before explicit rollback.
-- This script does not delete original objects or change existing AI tables.
DROP TABLE IF EXISTS t_capp_knowledge_run;
DROP TABLE IF EXISTS t_capp_knowledge_job;
DROP TABLE IF EXISTS t_capp_knowledge_chunk;
DROP TABLE IF EXISTS t_capp_knowledge_document;
DROP TABLE IF EXISTS t_capp_knowledge_base;
