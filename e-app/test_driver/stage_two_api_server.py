"""Loopback-only synthetic API for the Pixel_10a stage-two acceptance test.

It never reads or logs request authorization headers and does not contact the
real backend. Test controls and counters are separate from business endpoints.
"""
import json
import threading
import time
from datetime import datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

LOCK = threading.Lock()
STATE = {"scenario": "success", "failure": "", "unread": 4, "delay": 0.0}
COUNTS = {}
READ = set()
ENDPOINTS = {
    "identity": "/getInfo",
    "unread": "/system/notice/unreadCount",
    "stats": "/system/dashboard/overview",
    "interviews": "/enterprise/interview/list",
    "applications": "/system/enterprise/jobs/list",
}


class Handler(BaseHTTPRequestHandler):
    def respond(self, payload, status=200):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        parsed = urlsplit(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)
        if path == "/__control/set":
            with LOCK:
                if query.get("reset", ["0"])[0] == "1":
                    STATE.update(scenario="success", failure="", unread=4, delay=0.0)
                    COUNTS.clear()
                    READ.clear()
                for key in ["scenario", "failure"]:
                    if key in query:
                        STATE[key] = query[key][0]
                if "unread" in query:
                    value = query["unread"][0]
                    STATE["unread"] = None if value == "null" else int(value)
                if "delay" in query:
                    STATE["delay"] = float(query["delay"][0])
            self.respond({"code": 200})
            return
        if path == "/__control/report":
            with LOCK:
                report = {"counts": dict(COUNTS), "readCount": len(READ)}
            self.respond(report)
            return
        with LOCK:
            COUNTS[path] = COUNTS.get(path, 0) + 1
            state = dict(STATE)
            read = set(READ)
        if state["delay"]:
            time.sleep(state["delay"])
        if path == ENDPOINTS.get(state["failure"]):
            if state["failure"] == "identity":
                self.respond({"code": 403, "msg": "受控权限不足"}, 403)
            elif state["failure"] == "interviews":
                self.respond({"code": 408, "msg": "连接超时，请重试"})
            else:
                self.respond({"code": 500, "msg": "受控服务错误"}, 500)
            return
        empty = state["scenario"] == "empty"
        payload = {"code": 200}
        if path == "/getInfo":
            payload["user"] = {"nickName": "验收招聘经理"}
        elif path == "/system/enterprise/jobs/publishing-options":
            payload["data"] = {"company": {"id": 99000, "name": "受控验收企业"}, "departments": ["验收部门"]}
        elif path == "/system/notice/unreadCount":
            payload["data"] = state["unread"]
        elif path == "/system/dashboard/overview":
            payload["data"] = {"stats": {} if empty else {"activePositions": 2, "pendingInterviews": 4, "weeklyCompleted": 0}}
        elif path == "/enterprise/interview/list":
            tomorrow = (datetime.now() + timedelta(days=1)).replace(hour=10, minute=0, second=0, microsecond=0)
            rows = [] if empty else [
                {"appointmentId": 92001 + i, "candidateName": f"验收候选人 {i+1}", "positionTitle": f"验收面试岗位 {i+1}",
                 "positionId": 91001 + i, "startTime": (tomorrow + timedelta(hours=i)).strftime("%Y-%m-%d %H:%M:%S"),
                 "status": i % 2}
                for i in range(4)
            ]
            page = int(query.get("pageNum", ["1"])[0])
            size = int(query.get("pageSize", ["20"])[0])
            payload.update(rows=rows[(page-1)*size:page*size], total=len(rows))
        elif path == "/system/enterprise/jobs/list":
            rows = [] if empty else [
                {"posId": 91001+i, "title": f"验收岗位 {i+1}", "dept": "验收部门", "city": "验收城市", "applicantCount": i*2, "salaryMin": 10000, "salaryMax": 20000, "status": 1}
                for i in range(5)
            ]
            page = int(query.get("pageNum", ["1"])[0])
            size = int(query.get("pageSize", ["20"])[0])
            payload.update(rows=rows[(page-1)*size:page*size], total=len(rows))
        elif path == "/system/notice/listTop":
            payload["data"] = [{"noticeId": i, "noticeTitle": f"验收公告 {i}", "noticeContent": "仅用于受控验收", "isRead": i in read, "createTime": "2030-01-01"} for i in range(1, 5)]
            payload["unreadCount"] = state["unread"] or 0
        elif path.startswith("/system/enterprise/jobs/"):
            payload["data"] = {"candidates": []}
        elif path.startswith("/enterprise/jd/"):
            payload["data"] = {"jdProfile": None}
        else:
            self.respond({"code": 404, "msg": "未配置的受控接口"}, 404)
            return
        self.respond(payload)

    def do_POST(self):
        parsed = urlsplit(self.path)
        if parsed.path != "/system/notice/markRead":
            self.respond({"code": 404}, 404)
            return
        notice = int(parse_qs(parsed.query).get("noticeId", ["0"])[0])
        with LOCK:
            COUNTS[parsed.path] = COUNTS.get(parsed.path, 0) + 1
            if notice not in READ:
                READ.add(notice)
                STATE["unread"] = max(0, (STATE["unread"] or 0) - 1)
        self.respond({"code": 200})

    def log_message(self, *_):
        pass


if __name__ == "__main__":
    print("Stage-two synthetic API listening on 127.0.0.1:18990", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 18990), Handler).serve_forever()
