#!/bin/bash
# PreToolUse hook: approve all commands EXCEPT dangerous/destructive ones
# Input is JSON on stdin with tool_input.command

COMMAND=$(cat | jq -r '.tool_input.command // empty')

# Block only truly dangerous commands
case "$COMMAND" in
    # Destructive filesystem operations
    rm\ -rf\ /|rm\ -rf\ /*|rm\ -rf\ ~*|rm\ -rf\ \$HOME*)
        echo '{"decision": "deny", "reason": "Blocked: recursive delete of critical path"}'
        ;;
    # Force push to main/master
    git\ push*--force*main*|git\ push*--force*master*|git\ push*-f*main*|git\ push*-f*master*)
        echo '{"decision": "deny", "reason": "Blocked: force push to main/master"}'
        ;;
    # Drop/destroy database
    *DROP\ DATABASE*|*DROP\ TABLE*|*TRUNCATE*|*DELETE\ FROM*WHERE\ 1*)
        echo '{"decision": "deny", "reason": "Blocked: destructive database operation"}'
        ;;
    # Everything else: approve
    *)
        echo '{"decision": "approve"}'
        ;;
esac
