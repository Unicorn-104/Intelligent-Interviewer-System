"""Apply only the additive AI migration using credentials from the local process environment."""
import os
from pathlib import Path
import re
import sys


def main():
    import pymysql

    password = os.environ.get("DB_PASSWORD")
    if password is None:
        print("Missing local DB_PASSWORD environment variable.")
        return 1
    try:
        connection = pymysql.connect(
            host="127.0.0.1", port=3306, user="root", password=password,
            database="recruit_agent", charset="utf8mb4", autocommit=True,
            connect_timeout=5, read_timeout=15, write_timeout=15,
        )
        with connection:
            with connection.cursor() as cursor:
                if "--verify-only" not in sys.argv[1:]:
                    for name in ("migration_capp_ai_agent_20261020.sql", "migration_capp_ai_memory_20261021.sql",
                                 "migration_capp_ai_history_actions_20261021.sql",
                                 "migration_capp_ai_task_context_20261021.sql"):
                        migration = Path(__file__).resolve().parents[1] / "doc" / name
                        sql = re.sub(r"(?m)^\s*--.*$", "", migration.read_text(encoding="utf-8-sig"))
                        for statement in sql.split(";"):
                            if statement.strip():
                                cursor.execute(statement)
                cursor.execute(
                    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() "
                    "AND table_name IN ('t_capp_ai_session','t_capp_ai_run','t_capp_ai_message','t_capp_ai_event',"
                    "'t_capp_ai_memory_state','t_capp_ai_memory','t_capp_ai_summary')"
                )
                if cursor.fetchone()[0] != 7:
                    raise RuntimeError("Migration verification failed")
                cursor.execute(
                    "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() "
                    "AND table_name='t_capp_ai_session' AND column_name='pinned'"
                )
                if cursor.fetchone()[0] != 1:
                    raise RuntimeError("AI history actions migration verification failed")
                cursor.execute(
                    "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() "
                    "AND table_name='t_capp_ai_run' AND column_name IN ('application_id','task_type')"
                )
                if cursor.fetchone()[0] != 2:
                    raise RuntimeError("AI task context migration verification failed")
        print("Local MySQL connected; AI conversation tables and task-context columns verified.")
        return 0
    except Exception as error:
        code = error.args[0] if error.args and isinstance(error.args[0], int) else "unavailable"
        print(f"Local database operation failed ({type(error).__name__}, code={code}).")
        return 1


if __name__ == "__main__":
    sys.exit(main())
