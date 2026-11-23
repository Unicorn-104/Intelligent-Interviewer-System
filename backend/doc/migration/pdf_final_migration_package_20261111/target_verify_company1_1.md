# 目标对象完整性验证报告

- Endpoint：http://127.0.0.1:19000
- Bucket：recruit-files
- Region：us-east-1
- 验证时间：2026-11-11 20:19:44 +08:00

验证方式：完整 GetObject 读取并计算真实 SHA-256，未使用 ETag

| appId | TargetKey | 结果 | 错误明细 | 期望大小 | 实际大小 | 期望 SHA | 实际 SHA |
|---|---|---|---|---|---|---|---|
| 70 | enterprise-application-resume/1/70/f7265a2484e44f1bb8f28eb898e517d3.pdf | PASS |  | 309407 | 309407 | d4da83f8d56c7b65e8a36cc5ed35d188cea66ec0c84e36243440e9b172230022 | d4da83f8d56c7b65e8a36cc5ed35d188cea66ec0c84e36243440e9b172230022 |
| 71 | enterprise-application-resume/1/71/41b70c7ec33e42be9bfbe584645935a0.pdf | PASS |  | 163683 | 163683 | e42eea0cbf46eba2dde87785099fd2b031e7fdf2cd2fe246b5f3631f85350bda | e42eea0cbf46eba2dde87785099fd2b031e7fdf2cd2fe246b5f3631f85350bda |
| 78 | enterprise-application-resume/1/78/18a5a19616884d64a492decd1f86a4e8.pdf | PASS |  | 163683 | 163683 | e42eea0cbf46eba2dde87785099fd2b031e7fdf2cd2fe246b5f3631f85350bda | e42eea0cbf46eba2dde87785099fd2b031e7fdf2cd2fe246b5f3631f85350bda |

总体结论：三条结果均为 PASS，允许进入数据库回写审核。
