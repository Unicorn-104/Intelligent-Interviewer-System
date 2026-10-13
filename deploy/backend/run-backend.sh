#!/usr/bin/env bash
# =====================================================================
# 智能招聘面试官系统 后端启动脚本（Linux 服务器）
# 用法：chmod +x run-backend.sh && ./run-backend.sh
# 前提：jar 包（ruoyi-admin.jar）、application.yml / application-druid.yml
#       已按 README「快速开始 → 3. 配置后端」放置到同目录
#
# 录制相关关键点：
#   1. -Djava.io.tmpdir —— 录制分片暂存目录。默认 /tmp 可能被 systemd
#      PrivateTmp 隔离或被系统定时清理，导致分片丢失，改为持久目录
#   2. --ruoyi.profile —— 成品录制文件落盘根目录（webm 存于
#      {profile}/upload/recording/{yyyyMMdd}/），需大容量磁盘并保证写权限
# =====================================================================
set -euo pipefail

APP_HOME="$(cd "$(dirname "$0")" && pwd)"
JAR="${APP_HOME}/ruoyi-admin.jar"

# --- 可修改的部署路径 ---
PROFILE_DIR="/home/ruoyi/uploadPath"       # 上传/录制成品根目录
REC_TMP_DIR="/data/recruit-tmp"            # 录制分片暂存目录（java.io.tmpdir）
JVM_OPTS="-Xms512m -Xmx1024m"

# 目录准备：不存在则创建，并校验写权限
mkdir -p "${PROFILE_DIR}" "${REC_TMP_DIR}" "${APP_HOME}/logs"
if [ ! -w "${PROFILE_DIR}" ] || [ ! -w "${REC_TMP_DIR}" ]; then
  echo "错误：当前用户对 ${PROFILE_DIR} 或 ${REC_TMP_DIR} 无写权限，录制将无法落盘" >&2
  exit 1
fi

nohup java ${JVM_OPTS} \
  -Djava.io.tmpdir="${REC_TMP_DIR}" \
  -jar "${JAR}" \
  --ruoyi.profile="${PROFILE_DIR}" \
  > "${APP_HOME}/logs/backend.out" 2>&1 &

echo "后端已启动，PID=$!，profile=${PROFILE_DIR}，录制分片目录=${REC_TMP_DIR}/recruit-recording"
