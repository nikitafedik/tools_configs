#!/bin/bash
# Claude Code notification hook — Native Windows toast via PowerShell
# No VS Code extension needed, works even when VS Code is minimized
# Receives JSON on stdin with: message, title, notification_type

INPUT=$(cat)
TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')

case "$TYPE" in
    idle_prompt)       BODY="⏸️ Idling — waiting for your input" ;;
    permission_prompt) BODY="🔐 Needs approval — check terminal" ;;
    *)                 BODY="🤖 Needs attention" ;;
esac

TITLE="Claude Code"
TAG=$(date +%s%N | tail -c 16)

# Get project folder name for window matching
PROJECT=$(basename "$PWD")

# Windows toast notification with Focus Terminal button
powershell.exe -WindowStyle Hidden -Command "
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > \$null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] > \$null
\$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
\$xml.LoadXml('<toast duration=\"short\"><visual><binding template=\"ToastText02\"><text id=\"1\">$TITLE</text><text id=\"2\">$BODY</text></binding></visual><actions><action content=\"Focus Terminal\" activationType=\"protocol\" arguments=\"claude-focus://focus?title=$PROJECT\"/></actions><audio silent=\"true\"/></toast>')
\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
\$toast.Tag = '$TAG'
\$toast.Group = 'claude'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Microsoft.VisualStudioCode').Show(\$toast)
" &
