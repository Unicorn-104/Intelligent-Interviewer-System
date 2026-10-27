-- Destructive: back up user memories first, then stop the application before applying.
DROP TABLE IF EXISTS t_capp_ai_memory_vector_outbox;
DROP TABLE IF EXISTS t_capp_ai_memory_extract_job;
DROP TABLE IF EXISTS t_capp_ai_memory_evidence;
DROP TABLE IF EXISTS t_capp_ai_memory_item;
