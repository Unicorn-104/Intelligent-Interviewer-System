-- Irreversibly removes only AI memories and summaries. Chat history is preserved.
DROP TABLE IF EXISTS t_capp_ai_summary;
DROP TABLE IF EXISTS t_capp_ai_memory;
DROP TABLE IF EXISTS t_capp_ai_memory_state;
