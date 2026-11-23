-- Run only after stopping the enterprise assistant and backing up its data.
DROP TABLE IF EXISTS t_enterprise_ai_knowledge_chunk;
DROP TABLE IF EXISTS t_enterprise_ai_knowledge_document;
DROP TABLE IF EXISTS t_enterprise_ai_context_reset;
DROP TABLE IF EXISTS t_enterprise_ai_summary;
DROP TABLE IF EXISTS t_enterprise_ai_memory;
DROP TABLE IF EXISTS t_enterprise_ai_memory_state;
