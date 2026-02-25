#!/bin/bash
# PostToolUse hook: auto-commit Claude edits for checkpoints + VS Code diff review

TMPJSON=$(mktemp)
cat > "$TMPJSON"

python3 - "$TMPJSON" <<'INNEREOF'
import json, sys, os, subprocess

CYAN  = '\033[36m'
DIM   = '\033[2m'
RESET = '\033[0m'

try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

# Handle both flat and nested (tool_input) formats
inp = data.get('tool_input', data)
file_path = inp.get('file_path', '')

if not file_path:
    sys.exit(0)

# Ensure git repo exists
cwd = data.get('cwd', os.path.dirname(file_path))
try:
    subprocess.run(['git', 'rev-parse', '--git-dir'], cwd=cwd,
                   capture_output=True, check=True)
except (subprocess.CalledProcessError, FileNotFoundError):
    subprocess.run(['git', 'init'], cwd=cwd, capture_output=True)
    subprocess.run(['git', 'add', '-A'], cwd=cwd, capture_output=True)
    subprocess.run(['git', 'commit', '-m', 'init: pre-claude checkpoint'],
                   cwd=cwd, capture_output=True)

# Build a short commit message from the change
basename = os.path.basename(file_path)
old_string = inp.get('old_string', '')
new_string = inp.get('new_string', '')
content = inp.get('content', '')  # for Write tool

if old_string and new_string:
    # Edit tool — summarize what changed
    old_preview = old_string.strip().split('\n')[0][:50]
    new_preview = new_string.strip().split('\n')[0][:50]
    msg = f"claude: {basename} — '{old_preview}' -> '{new_preview}'"
elif content:
    # Write tool
    msg = f"claude: write {basename}"
else:
    msg = f"claude: edit {basename}"

# Stage just this file and commit
subprocess.run(['git', 'add', file_path], cwd=cwd, capture_output=True)

result = subprocess.run(['git', 'diff', '--cached', '--stat'], cwd=cwd,
                        capture_output=True, text=True)

# Only commit if there are staged changes
if result.stdout.strip():
    subprocess.run(['git', 'commit', '-m', msg], cwd=cwd, capture_output=True)
    print(f'{CYAN}  checkpoint: {DIM}{msg}{RESET}')

INNEREOF

rm -f "$TMPJSON"
