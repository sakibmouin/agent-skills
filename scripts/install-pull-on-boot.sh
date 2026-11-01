#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
os="$(uname -s)"

case "$os" in
    Darwin)
        agent_dir="$HOME/Library/LaunchAgents"
        agent_file="$agent_dir/com.agent-skills.pull.plist"
        mkdir -p "$agent_dir"
        cat > "$agent_file" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.agent-skills.pull</string>
    <key>ProgramArguments</key>
    <array>
        <string>$repo_root/scripts/pull-on-boot.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/agent-skills-pull.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/agent-skills-pull.log</string>
</dict>
</plist>
EOF
        launchctl bootout "gui/$(id -u)" "$agent_file" >/dev/null 2>&1 || true
        launchctl bootstrap "gui/$(id -u)" "$agent_file"
        echo "Installed. The repository will be pulled when you log in."
        ;;
    Linux)
        service_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
        service_file="$service_dir/agent-skills-pull.service"
        mkdir -p "$service_dir"
        cat > "$service_file" <<EOF
[Unit]
Description=Pull the agent-skills repository at startup
After=network-online.target

[Service]
Type=oneshot
ExecStart=$repo_root/scripts/pull-on-boot.sh

[Install]
WantedBy=default.target
EOF

        systemctl --user daemon-reload
        systemctl --user enable agent-skills-pull.service

        # A lingering user manager starts the service at boot, before interactive login.
        if ! loginctl show-user "$USER" --property=Linger --value | grep -qx yes; then
            sudo loginctl enable-linger "$USER"
        fi

        echo "Installed. The repository will be pulled at boot."
        ;;
    *)
        echo "Unsupported operating system: $os" >&2
        exit 1
        ;;
esac
