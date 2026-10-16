"""Run company mapper SQL on empty fixture tables in an isolated MySQL schema.

Reads only local datasource credentials. No production rows or credentials are printed.
The dedicated schema is removed on completion; production tables are never mutated.
"""
import os
import re
import uuid
from pathlib import Path
from urllib.parse import urlparse
from xml.etree import ElementTree as ET

import pymysql
import yaml

ROOT = Path(__file__).resolve().parents[1]


def local_connection():
    config = yaml.safe_load((ROOT / 'ruoyi-admin/src/main/resources/application-druid.yml').read_text(encoding='utf-8'))
    source = config['spring']['datasource']['druid']['master']
    def resolve(value):
        return re.sub(r'\$\{([^}:]+)(?::([^}]*))?\}', lambda m: os.environ.get(m[1], m[2] or ''), str(value or ''))
    uri = urlparse(resolve(source['url']).removeprefix('jdbc:'))
    return pymysql.connect(host=uri.hostname or 'localhost', port=uri.port or 3306,
        user=resolve(source['username']), password=resolve(source['password']),
        database=uri.path.lstrip('/'), charset='utf8mb4', autocommit=False)


def statements(file):
    return {child.attrib['id']: child for child in ET.parse(ROOT / file).getroot() if 'id' in child.attrib}


def sql(element, query=None, includes=None, bind=True):
    result = element.text or ''
    for child in element:
        if child.tag == 'include':
            result += sql(includes[child.attrib['refid']], query, includes, False)
        elif child.tag == 'if':
            # This smoke case uses only companyId, all other optional query fields are absent.
            if 'query.companyId' in child.attrib['test'] and query:
                result += sql(child, query, includes, False)
        elif child.tag == 'choose':
            result += sql(child.find('otherwise'), query, includes, False)
        result += child.tail or ''
    if not bind:
        return result
    return re.sub(r'#\{([^}]+)\}', lambda m: '%(' + m[1].replace('query.', '') + ')s', result.replace('%', '%%'))


def main():
    schema = 'codex_company_check_' + uuid.uuid4().hex[:12]
    db = local_connection()
    original = db.db.decode() if isinstance(db.db, bytes) else db.db
    tables = ['sys_user', 't_cmp', 't_pos', 't_usr_interest', 't_msg', 't_im_session',
              't_cmp_binding', 't_app_record', 't_tal', 't_pos_skill']
    companies = statements('ruoyi-system/src/main/resources/mapper/app/AppCompanyMapper.xml')
    messages = statements('ruoyi-system/src/main/resources/mapper/app/AppMessageMapper.xml')
    jobs = statements('ruoyi-system/src/main/resources/mapper/agent/AgentJobMapper.xml')
    try:
        with db.cursor(pymysql.cursors.DictCursor) as cursor:
            cursor.execute(f'CREATE DATABASE `{schema}` CHARACTER SET utf8mb4')
            db.select_db(schema)
            for table in tables:
                cursor.execute(f'CREATE TABLE `{table}` LIKE `{original}`.`{table}`')
            cursor.execute("INSERT INTO sys_user (user_id,user_name,nick_name,status,del_flag) VALUES (17,'synthetic17','Synthetic 17','0','0'),(18,'synthetic18','Synthetic 18','0','0')")
            cursor.execute("INSERT INTO t_cmp (cmp_id,cmp_name,cmp_status) VALUES (71,'Synthetic A',1),(72,'Synthetic B',1),(73,'Synthetic disabled',0)")
            for position, company_id, status in [(99101,71,1),(99102,71,1),(99103,71,1),(99104,71,1),(99105,71,0),(99201,72,1)]:
                cursor.execute("INSERT INTO t_pos (pos_id,pos_company_id,pos_publisher_id,pos_title,pos_status,pos_jd_json) VALUES (%s,%s,17,%s,%s,'{}')", (position,company_id,'Synthetic job '+str(position),status))
            def execute(collection, key, **params):
                cursor.execute(sql(collection[key]), params)
                return cursor.rowcount
            def rows(user=17):
                execute(messages, 'selectMessages', userId=user, limit=100)
                return cursor.fetchall()
            def unread(user=17):
                return sum(int(row['unread_count']) for row in rows(user))
            execute(companies, 'selectPublicCompany', companyId=71)
            public_company = cursor.fetchone()
            assert public_company['cmp_id'] == 71 and 'api_quota' not in public_company
            for _ in range(2): execute(companies,'follow',userId=17,companyId=71)
            execute(companies,'follow',userId=18,companyId=72)
            execute(companies,'selectFavoriteCompanyIds',userId=17)
            assert [r['int_target_id'] for r in cursor.fetchall()] == [71]
            cursor.execute('SELECT count(*) AS n FROM t_usr_interest WHERE int_user_id=17')
            assert cursor.fetchone()['n'] == 1
            assert unread() == 0
            assert execute(companies,'notifyFollowers',companyId=71,positionId=99105) == 0
            assert execute(companies,'notifyFollowers',companyId=71,positionId=99101) == 1
            assert execute(companies,'notifyFollowers',companyId=71,positionId=99101) == 0
            assert unread() == 1 and unread(18) == 0
            company_message = [r for r in rows() if r['category']=='COMPANY'][0]
            assert company_message['target_url'] == '/companies/71'
            interest = company_message['source_id']
            assert execute(messages,'markCompanyMessagesRead',userId=18,interestId=interest) == 0
            assert unread() == 1
            execute(messages,'markCompanyMessagesRead',userId=17,interestId=interest)
            assert unread() == 0
            execute(companies,'notifyFollowers',companyId=71,positionId=99102)
            assert unread() == 1
            execute(messages,'markAllSystemMessagesRead',userId=17)
            assert unread() == 0
            db.commit()
            execute(companies,'notifyFollowers',companyId=71,positionId=99103)
            assert unread() == 1
            db.rollback()
            assert unread() == 0
            execute(companies,'unfollow',userId=17,companyId=71)
            execute(companies,'markNotificationsRead',userId=17,companyId=71)
            assert execute(companies,'notifyFollowers',companyId=71,positionId=99104) == 0
            assert not any(r['category']=='COMPANY' for r in rows())
            execute(companies,'follow',userId=17,companyId=71)
            assert unread() == 0
            cursor.execute(sql(jobs['selectJobList'], query=True, includes=jobs)+' LIMIT 10', {'companyId':71,'userId':17})
            result = cursor.fetchall()
            assert len(result)==4 and all(row['company_id']==71 and row['status_code']==1 for row in result)
            db.rollback()
            print('PASS: real MySQL mapper SQL; idempotent favorites, account isolation, published-only jobs, notification deduplication, unread/read-all, unfollow and rollback')
    finally:
        db.rollback()
        db.select_db(original)
        with db.cursor() as cursor:
            if not re.fullmatch(r'codex_company_check_[0-9a-f]{12}', schema):
                raise RuntimeError('Unexpected test schema name')
            cursor.execute(f'DROP DATABASE IF EXISTS `{schema}`')
        db.close()


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Database error messages from fixture SQL are safe; never echo connection settings.
        if isinstance(error, pymysql.MySQLError):
            print('FAIL: MySQL check error code', error.args[0])
            if error.args[0] == 1064:
                print(error.args[1])
        else:
            print('FAIL:', type(error).__name__)
        import traceback
        for frame in traceback.extract_tb(error.__traceback__):
            if Path(frame.filename).name == Path(__file__).name:
                print(Path(frame.filename).name, frame.lineno, frame.name)
        raise SystemExit(1)
