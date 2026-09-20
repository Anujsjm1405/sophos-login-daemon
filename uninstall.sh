#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="/etc/sophos-login"
DAEMON="/usr/bin/sophos-login"
SETUP="/usr/bin/sophos-login-setup"
SERVICE="/usr/lib/systemd/system/sophos-login.service"
DISPATCHER="/etc/NetworkManager/dispatcher.d/90-sophos-login"

printf '\n'
printf 'Sophos Login Daemon Uninstaller\n'
printf '\n'

if [[ "${EUID}" -ne 0 ]]; then
    printf 'Error: run this script with sudo.\n'
    exit 1
fi

printf '  Removing NetworkManager dispatcher...\n'
rm -f "$DISPATCHER"

printf '  Removing systemd service...\n'
systemctl stop sophos-login.service 2>/dev/null || true
systemctl disable sophos-login.service 2>/dev/null || true
rm -f "$SERVICE"

printf '  Reloading systemd...\n'
systemctl daemon-reload

printf '  Removing executables...\n'
rm -f "$DAEMON"
rm -f "$SETUP"

printf '  Removing configuration...\n'
rm -rf "$INSTALL_DIR"

printf '  Reloading NetworkManager configuration...\n'
systemctl reload NetworkManager 2>/dev/null || true

printf '\n'
printf '========================================\n'
printf '  Sophos Login Daemon Removed\n'
printf '========================================\n'
printf '\n'

printf '  Removed:\n'
printf '    /usr/bin/sophos-login\n'
printf '    /usr/bin/sophos-login-setup\n'
printf '    /etc/sophos-login\n'
printf '    sophos-login.service\n'
printf '    90-sophos-login dispatcher\n'
printf '\n'

printf '  Sophos Login Daemon has been uninstalled.\n'
printf '\n'