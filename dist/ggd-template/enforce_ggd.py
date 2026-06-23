#!/usr/bin/env python3
"""
GGD 工作流门禁脚本
"""

import json
import os
import sys

# ============================================================
STATE_FILE = ".claude/ggd/state.json"
TEMPLATE_READ_FILE = ".claude/ggd/templates_read.json"

# 全局模板目录
GLOBAL_TEMPLATE_DIR = "__CLAUDE_HOME__/templates"

# 文档到模板的映射
DOC_TO_TEMPLATE = {
    "PROJECT.md": "project_template.md",
    "REQUIREMENTS.md": "requirements_template.md",
    "ROADMAP.md": "roadmap_template.md",
    "STATE.md": "state_template.md",
}

# waiting_requirements 状态下允许写入的文件
WAITING_REQS_ALLOWED_FILES = [
    "PROJECT.md",
    "REQUIREMENTS.md",
    "ROADMAP.md",
    "STATE.md",
    "CLAUDE.md",
    ".claude/ggd/state.json",
]

# ============================================================
# 工具函数
# ============================================================
def get_tool_info():
    tool_name = os.environ.get("CLAUDE_TOOL_NAME", "")
    tool_params = os.environ.get("CLAUDE_TOOL_PARAMS", "{}")
    try:
        params = json.loads(tool_params)
    except json.JSONDecodeError:
        params = {}
    return tool_name, params

def load_state():
    if not os.path.exists(STATE_FILE):
        return None
    try:
        with open(STATE_FILE, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return None

def is_template_file(file_path):
    if not GLOBAL_TEMPLATE_DIR:
        return False
    # 标准化路径后判断是否在模板目录内
    norm_path = os.path.normpath(file_path)
    norm_template_dir = os.path.normpath(GLOBAL_TEMPLATE_DIR)
    return norm_path.startswith(norm_template_dir) and file_path.endswith(".md")

def record_template_read(template_name):
    records = {}
    if os.path.exists(TEMPLATE_READ_FILE):
        try:
            with open(TEMPLATE_READ_FILE, 'r') as f:
                records = json.load(f)
        except (json.JSONDecodeError, IOError):
            records = {}
    records[template_name] = True
    os.makedirs(os.path.dirname(TEMPLATE_READ_FILE), exist_ok=True)
    with open(TEMPLATE_READ_FILE, 'w') as f:
        json.dump(records, f)

def has_read_template(doc_path):
    doc_name = os.path.basename(doc_path)
    template_name = DOC_TO_TEMPLATE.get(doc_name)
    if not template_name:
        return True  # 非受控文档（实际上白名单中的都有映射）
    if not os.path.exists(TEMPLATE_READ_FILE):
        return False
    try:
        with open(TEMPLATE_READ_FILE, 'r') as f:
            records = json.load(f)
        return records.get(template_name, False)
    except (json.JSONDecodeError, IOError):
        return False

def is_allowed_in_waiting_requirements(file_path):
    """检查文件是否在 waiting_requirements 状态的白名单中"""
    norm_path = os.path.normpath(file_path)
    for allowed in WAITING_REQS_ALLOWED_FILES:
        norm_allowed = os.path.normpath(allowed)
        # 精确匹配整个路径
        if norm_path == norm_allowed:
            return True
        # 如果允许的是根目录下的文件（如 PROJECT.md），且路径就是该文件名
        if os.path.basename(norm_path) == norm_allowed and os.path.dirname(norm_path) == "":
            return True
        # 如果路径以允许的路径结尾（如 .../.claude/ggd/state.json）
        if norm_path.endswith(os.path.sep + norm_allowed):
            return True
    return False

def is_global_whitelist(file_path):
    """全局白名单：这些文件任何状态下都允许写入"""
    whitelist = [
        "state.md",
        ".claude/ggd/state.json",
        ".claude/ggd/templates_read.json",
    ]
    norm_path = os.path.normpath(file_path)
    for item in whitelist:
        norm_item = os.path.normpath(item)
        if norm_path == norm_item or norm_path.endswith(os.path.sep + norm_item):
            return True
    return False

def check_state_and_file(state, file_path):
    if state is None:
        return True, "⚠️ 状态文件不存在，已允许写入"
    phase = state.get("current_phase", "planning")
    if phase == "done":
        return False, "❌ 项目已完成，禁止写入。请执行 ggd-reset"
    if phase == "planning":
        return False, "❌ 状态: planning，请先执行 ggd-approve-plan"
    if phase == "waiting_requirements":
        if is_allowed_in_waiting_requirements(file_path):
            return True, None
        else:
            allowed = "\n    - ".join(WAITING_REQS_ALLOWED_FILES)
            return False, f"❌ 当前状态: waiting_requirements，只允许写入:\n    - {allowed}"
    if phase == "developing":
        return True, None
    return True, f"⚠️ 未知状态: {phase}"

def check_template_requirement(file_path):
    if not GLOBAL_TEMPLATE_DIR:
        return True, None
    doc_name = os.path.basename(file_path)
    template_name = DOC_TO_TEMPLATE.get(doc_name)
    if not template_name:
        return True, None
    if not has_read_template(file_path):
        return False, f"❌ 生成 {doc_name} 前，必须先读取模板文件 {template_name}"
    return True, None

# ============================================================
# 主函数
# ============================================================
def main():
    tool_name, params = get_tool_info()
    file_path = params.get("file_path", "")

    # 处理 Read 模板：记录已读
    if tool_name == "Read" and file_path:
        if is_template_file(file_path):
            record_template_read(os.path.basename(file_path))
        sys.exit(0)

    # 处理 Write/Edit
    if tool_name in ["Write", "Edit"] and file_path:
        # 1. 全局白名单
        if is_global_whitelist(file_path):
            sys.exit(0)

        # 2. 状态检查
        state = load_state()
        allowed, msg = check_state_and_file(state, file_path)
        if not allowed:
            print(msg)
            sys.exit(2)

        # 3. 模板检查（仅在 waiting_requirements 状态下对白名单文档有效）
        allowed, msg = check_template_requirement(file_path)
        if not allowed:
            print(msg)
            sys.exit(2)

    sys.exit(0)

if __name__ == "__main__":
    main()