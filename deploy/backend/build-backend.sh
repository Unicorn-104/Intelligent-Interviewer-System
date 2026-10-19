#!/usr/bin/env bash
# =====================================================================
# 后端标准打包脚本（多模块 Maven，无需先执行 install）
#
# 用法：
#   chmod +x build-backend.sh
#   ./build-backend.sh                 # 打包并把 jar 放到脚本同级 dist/
#   ./build-backend.sh --skip-clean    # 跳过 clean，增量打包（更快）
#
# 说明：
#   在仓库 backend/ 根目录执行 `mvn clean package -DskipTests`，Maven 会按
#   依赖顺序自动构建 ruoyi-common -> system -> framework -> admin 等全部模块，
#   最终产出自包含的 fat jar（ruoyi-admin.jar）。不需要先手动 mvn install。
# =====================================================================
set -euo pipefail

SKIP_CLEAN=0
for arg in "$@"; do
  case "$arg" in
    --skip-clean) SKIP_CLEAN=1 ;;
    *) echo "未知参数：$arg" >&2; exit 2 ;;
  esac
done

# 脚本位于 deploy/backend/，源码根为 仓库/backend
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BACKEND_DIR="${REPO_ROOT}/backend"
OUT_DIR="${SCRIPT_DIR}/dist"

if [ ! -d "${BACKEND_DIR}" ]; then
  echo "错误：找不到后端源码目录 ${BACKEND_DIR}" >&2
  exit 1
fi

MVN_GOAL="package"
if [ "${SKIP_CLEAN}" -eq 0 ]; then
  MVN_GOAL="clean package"
fi

echo "==> 打包目录：${BACKEND_DIR}"
(
  cd "${BACKEND_DIR}"
  mvn ${MVN_GOAL} -DskipTests
)

JAR="${BACKEND_DIR}/ruoyi-admin/target/ruoyi-admin.jar"
if [ ! -f "${JAR}" ]; then
  echo "错误：未产出 ${JAR}，打包失败" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"
cp -f "${JAR}" "${OUT_DIR}/ruoyi-admin.jar"

echo "==> 打包完成：${OUT_DIR}/ruoyi-admin.jar"
echo "==> 部署：java -jar ruoyi-admin.jar（配合 run-backend.sh 使用）"
