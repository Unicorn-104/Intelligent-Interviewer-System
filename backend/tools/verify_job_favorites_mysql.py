"""Exercise actual job-favorite mapper SQL using synthetic rows in an isolated schema."""
import re
import traceback
import uuid
from pathlib import Path

import pymysql
from verify_company_mysql import local_connection, statements, sql


def main():
    schema = 'codex_job_favorites_' + uuid.uuid4().hex[:12]
    db = local_connection()
    original = db.db.decode() if isinstance(db.db, bytes) else db.db
    mapper = statements('ruoyi-system/src/main/resources/mapper/app/AppJobFavoriteMapper.xml')
    try:
        with db.cursor(pymysql.cursors.DictCursor) as cursor:
            cursor.execute(f'CREATE DATABASE `{schema}` CHARACTER SET utf8mb4')
            db.select_db(schema)
            for table in ['sys_user', 't_cmp', 't_pos', 't_usr_interest', 't_app_record', 't_tal', 't_pos_skill']:
                cursor.execute(f'CREATE TABLE `{table}` LIKE `{original}`.`{table}`')
            cursor.execute("INSERT INTO sys_user (user_id,user_name,nick_name,status,del_flag) VALUES (17,'synthetic17','Synthetic 17','0','0'),(18,'synthetic18','Synthetic 18','0','0')")
            cursor.execute("INSERT INTO t_cmp (cmp_id,cmp_name,cmp_status) VALUES (71,'Synthetic company',1),(72,'Synthetic disabled company',0)")
            for position, company, status in [(91, 71, 1), (92, 71, 1), (93, 71, 0), (94, 72, 1)]:
                cursor.execute("INSERT INTO t_pos (pos_id,pos_company_id,pos_publisher_id,pos_title,pos_status,pos_jd_json) VALUES (%s,%s,17,%s,%s,'{\"description\":\"Synthetic duties\"}')", (position, company, 'Synthetic job ' + str(position), status))

            def execute(key, user=17, position=91):
                cursor.execute(sql(mapper[key]), {'userId': user, 'positionId': position})
                return cursor.fetchall() if cursor.description else cursor.rowcount

            assert execute('lockAvailablePosition') == [{'pos_id': 91}]
            for position in [93, 94, 999]:
                assert execute('lockAvailablePosition', position=position) == ()
            assert not bool(next(iter(execute('isFavorited')[0].values())))
            execute('favorite')
            cursor.execute('SELECT int_updated_at FROM t_usr_interest WHERE int_user_id=17 AND int_target_type=1 AND int_target_id=91')
            timestamp = cursor.fetchone()['int_updated_at']
            execute('favorite')
            cursor.execute('SELECT count(*) n, max(int_updated_at) updated FROM t_usr_interest WHERE int_user_id=17 AND int_target_type=1')
            row = cursor.fetchone()
            assert row['n'] == 1 and row['updated'] == timestamp
            assert bool(next(iter(execute('isFavorited')[0].values())))
            assert not bool(next(iter(execute('isFavorited', user=18)[0].values())))
            cursor.execute("INSERT INTO t_usr_interest (int_user_id,int_target_type,int_target_id,int_status) VALUES (17,2,91,1)")
            execute('favorite', position=92)
            execute('favorite', position=93)
            execute('favorite', position=94)
            rows = execute('selectFavorites')
            assert [row['position_id'] for row in rows] == [94, 93, 92, 91]
            assert [row['available'] for row in rows] == [0, 0, 1, 1]
            assert rows[-1]['description'] == 'Synthetic duties'
            assert execute('selectFavorites', user=18) == ()
            cursor.execute(sql(mapper['selectFavorites']) + ' LIMIT 2 OFFSET 2', {'userId': 17})
            assert [row['position_id'] for row in cursor.fetchall()] == [92, 91]
            assert execute('unfavorite', user=18) == 0
            execute('unfavorite')
            execute('unfavorite')
            assert len(execute('selectFavorites')) == 3
            cursor.execute('SELECT int_status FROM t_usr_interest WHERE int_user_id=17 AND int_target_type=2 AND int_target_id=91')
            assert cursor.fetchone()['int_status'] == 1
            execute('unfavorite', position=93)
            execute('favorite')
            assert len(execute('selectFavorites')) == 3
            db.commit()
            execute('unfavorite')
            db.rollback()
            assert bool(next(iter(execute('isFavorited')[0].values())))
            print('PASS: real MySQL job favorites; idempotence, type/account isolation, availability, deterministic pagination, cancellation, restoration and rollback')
    finally:
        db.rollback()
        db.select_db(original)
        if not re.fullmatch(r'codex_job_favorites_[0-9a-f]{12}', schema):
            raise RuntimeError('Unexpected test schema name')
        with db.cursor() as cursor:
            cursor.execute(f'DROP DATABASE IF EXISTS `{schema}`')
        db.close()


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('FAIL:', type(error).__name__)
        if isinstance(error, pymysql.MySQLError):
            print('MySQL code:', error.args[0])
        for frame in traceback.extract_tb(error.__traceback__):
            if Path(frame.filename).name == Path(__file__).name:
                print(Path(frame.filename).name, frame.lineno, frame.name)
        raise SystemExit(1)
