# -*- coding: utf-8 -*-
"""绘制 JD 解析生命周期流程图（两条路径），输出 PNG。"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
from matplotlib.font_manager import FontProperties

# 中文字体
FONT_PATH = r"C:\Windows\Fonts\msyh.ttc"
fp = FontProperties(fname=FONT_PATH)
fpb = FontProperties(fname=FONT_PATH, weight="bold")

fig, ax = plt.subplots(figsize=(13, 11), dpi=160)
ax.set_xlim(0, 100)
ax.set_ylim(0, 100)
ax.axis("off")

# 颜色
A_FILL, A_EDGE, A_HEAD = "#EAF2FF", "#2B7FFF", "#1A3C6E"
B_FILL, B_EDGE, B_HEAD = "#E8F7F1", "#1B9A72", "#0E6B4F"
C_FILL, C_EDGE = "#FFF4E5", "#D7811D"

def box(x, y, w, h, text, fill, edge, fontsize=10.5, bold=False):
    p = FancyBboxPatch((x - w/2, y - h/2), w, h,
                       boxstyle="round,pad=0.3,rounding_size=1.2",
                       linewidth=1.6, edgecolor=edge, facecolor=fill, zorder=2)
    ax.add_patch(p)
    ax.text(x, y, text, ha="center", va="center",
            fontproperties=(fpb if bold else fp), fontsize=fontsize,
            color="#16233a", zorder=3, linespacing=1.4)

def arrow(x1, y1, x2, y2, color="#44506a", style="-|>", lw=1.8, ls="solid"):
    a = FancyArrowPatch((x1, y1), (x2, y2), arrowstyle=style,
                        mutation_scale=16, linewidth=lw, color=color,
                        linestyle=ls, zorder=1,
                        shrinkA=2, shrinkB=2)
    ax.add_patch(a)

# ===== 列标题 =====
ax.text(26, 97.5, "路径 A · JD 文档导入（AI 结构化，发布前，不写库）",
        ha="center", fontproperties=fpb, fontsize=12.5, color=A_HEAD)
ax.text(74, 97.5, "路径 B · JD 画像（规则解析，会写库）",
        ha="center", fontproperties=fpb, fontsize=12.5, color=B_HEAD)

# 列背景
ax.add_patch(FancyBboxPatch((3, 8), 46, 86, boxstyle="round,pad=0.3,rounding_size=1.5",
             linewidth=1.0, edgecolor="#c4d4ec", facecolor="#F7FAFF", zorder=0))
ax.add_patch(FancyBboxPatch((51, 8), 46, 86, boxstyle="round,pad=0.3,rounding_size=1.5",
             linewidth=1.0, edgecolor="#bfe6d8", facecolor="#F4FBF8", zorder=0))

# ===== 路径 A 节点 =====
Ax = 26
A_nodes = [
    (92, "发布岗位页 · 点“从文档导入”", 34, 5.2, True),
    (84, "JdDocumentPicker 选择 PDF / DOCX\n（前端校验：≤10MB、非空、文件名）", 38, 7.0, False),
    (75, "multipart 上传（带进度 / 可取消）\nPOST /enterprise/jd/parse-document", 40, 7.0, False),
    (66, "后端入口校验：企业绑定 / 类型 / 大小\n密钥 / 角色 / Semaphore 限流", 40, 7.0, False),
    (56, "内存文本提取（不落盘）\nPDF：ResumePdfParser，扫描件 OCR\nDOCX：POI XWPF，防 Zip 炸弹", 42, 9.0, False),
    (45, "JdAiStructurer · AI 结构化\nAnthropic Claude Messages API", 40, 7.0, False),
    (36, "逐字段校验（字段/金额/长度/技能去重）\n→ JdDocumentDraft 草稿", 42, 7.0, False),
    (27, "草稿回填发布表单（不写库）", 36, 5.6, False),
    (19, "HR 人工核对 / 修改", 30, 5.2, False),
    (11, "POST /system/enterprise/jobs 发布岗位", 36, 5.6, True),
]
prev = None
for y, t, w, h, bold in A_nodes:
    box(Ax, y, w, h, t, A_FILL, A_EDGE, bold=bold)
    if prev is not None:
        arrow(Ax, prev[0]-prev[1]/2, Ax, y+h/2)
    prev = (y, h)

# ===== 路径 B 节点 =====
Bx = 74
B_nodes = [
    (92, "岗位详情 · 点“生成画像”", 34, 5.2, True),
    (83, "POST /enterprise/jd/parse\n（positionId + jdText）", 36, 7.0, False),
    (73, "EnterpriseJdServiceImpl\n规则解析（非 AI）", 36, 7.0, False),
    (63, "学历（优先级）/ 年限（正则）\n技能（词典）/ 软性要求（词典）", 40, 8.0, False),
    (53, "落库（幂等 · 先删后插）\nt_pos.pos_jd_json\nt_pos_skill", 38, 9.0, False),
    (43, "GET /enterprise/jd/{posId}\n查看岗位画像", 36, 7.0, False),
    (33, "画像作为后续\nAI 筛选的标尺", 32, 7.0, False),
]
prev = None
for y, t, w, h, bold in B_nodes:
    box(Bx, y, w, h, t, B_FILL, B_EDGE, bold=bold)
    if prev is not None:
        arrow(Bx, prev[0]-prev[1]/2, Bx, y+h/2, color="#2a7a5f")
    prev = (y, h)

# ===== 衔接：A 发布 -> B 顶部（岗位详情）=====
# 从 A 底部节点出发，向右绕行到 B 顶部
arrow(Ax + 18, 11, 60, 11, color=C_EDGE, lw=2.2)
arrow(60, 11, 60, 92, color=C_EDGE, lw=2.2, ls="dashed")
arrow(60, 92, Bx-17, 92, color=C_EDGE, lw=2.2)
ax.text(60.5, 51, "发布后\n进入岗位详情", ha="left", va="center",
        fontproperties=fp, fontsize=9.5, color="#9a5a10", linespacing=1.4)

plt.tight_layout(pad=0.5)
out = r"D:\Flutter_apps\Intelligent-Interviewer-System\e-app\docs\jd-lifecycle-flow.png"
plt.savefig(out, bbox_inches="tight", facecolor="white")
print("saved:", out)
