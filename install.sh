#!/usr/bin/env bash

set -u

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE_DAEMON="$PROJECT_DIR/src/sophos-login"
SOURCE_SETUP="$PROJECT_DIR/src/sophos-login-setup"
SOURCE_SERVICE="$PROJECT_DIR/systemd/sophos-login.service"
SOURCE_DISPATCHER="$PROJECT_DIR/networkmanager/90-sophos-login"
SOURCE_CONFIG="$PROJECT_DIR/config/config.example"

INSTALL_DAEMON="/usr/bin/sophos-login"
INSTALL_SETUP="/usr/bin/sophos-login-setup"
INSTALL_SERVICE="/usr/lib/systemd/system/sophos-login.service"
INSTALL_DISPATCHER="/etc/NetworkManager/dispatcher.d/90-sophos-login"

CONFIG_DIR="/etc/sophos-login"
CONFIG_FILE="$CONFIG_DIR/config"
CREDENTIALS_FILE="$CONFIG_DIR/credentials"

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    WHITE="$(tput bold)$(tput setaf 7)"
    GRAY="$(tput setaf 8)"
    RESET="$(tput sgr0)"
else
    RED=""
    GREEN=""
    WHITE=""
    GRAY=""
    RESET=""
fi

info() {
    printf "  %s→%s %s\n" "$GRAY" "$RESET" "$1"
}

success() {
    printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"
}

error() {
    printf "  %s✗%s %s\n" "$RED" "$RESET" "$1" >&2
}

# ------------------------------------------------------------
# Checks
# ------------------------------------------------------------

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "Run this installer with sudo."
        exit 1
    fi
}

check_files() {
    local files=(
        "$SOURCE_DAEMON"
        "$SOURCE_SETUP"
        "$SOURCE_SERVICE"
        "$SOURCE_DISPATCHER"
        "$SOURCE_CONFIG"
    )

    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Missing project file: $file"
            exit 1
        fi
    done
}

check_dependencies() {
    local dependencies=(
        bash
        nmcli
        curl
        stat
        systemctl
        systemd-analyze
    )

    for dependency in "${dependencies[@]}"; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            error "Missing dependency: $dependency"
            exit 1
        fi
    done
}

validate_files() {
    bash -n "$SOURCE_DAEMON"
    bash -n "$SOURCE_SETUP"
    bash -n "$SOURCE_DISPATCHER"

    # The service references /usr/bin/sophos-login.
    # Validate the unit file syntax without requiring the
    # executable to already be installed.
    systemd-analyze verify "$SOURCE_SERVICE" >/dev/null 2>&1 || {
        # systemd-analyze may complain because the executable
        # does not exist yet. The unit syntax itself is still
        # checked after installation.
        :
    }
}

# ------------------------------------------------------------
# Installation
# ------------------------------------------------------------

install_directories() {
    install -d -m 755 "$CONFIG_DIR"
    install -d -m 755 "/etc/NetworkManager/dispatcher.d"
    install -d -m 755 "/usr/lib/systemd/system"
}

install_programs() {
    install -m 755 -o root -g root \
        "$SOURCE_DAEMON" \
        "$INSTALL_DAEMON"

    install -m 755 -o root -g root \
        "$SOURCE_SETUP" \
        "$INSTALL_SETUP"

    install -m 644 -o root -g root \
        "$SOURCE_SERVICE" \
        "$INSTALL_SERVICE"

    install -m 755 -o root -g root \
        "$SOURCE_DISPATCHER" \
        "$INSTALL_DISPATCHER"
}

install_config() {

    # --------------------------------------------------------
    # Configuration
    # --------------------------------------------------------

    if [[ ! -f "$CONFIG_FILE" ]]; then
        install -m 600 -o root -g root \
            "$SOURCE_CONFIG" \
            "$CONFIG_FILE"
    else
        chmod 600 "$CONFIG_FILE"
        chown root:root "$CONFIG_FILE"
    fi

    # --------------------------------------------------------
    # Credentials
    # --------------------------------------------------------

    # Credentials are intentionally created empty.
    # The user configures them through sophos-login-setup.
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        install -m 600 -o root -g root \
            /dev/null \
            "$CREDENTIALS_FILE"
    else
        chmod 600 "$CREDENTIALS_FILE"
        chown root:root "$CREDENTIALS_FILE"
    fi
}

configure_service() {
    # The daemon is triggered by NetworkManager.
    # It must not be enabled as a boot-time service.
    systemctl disable sophos-login.service >/dev/null 2>&1 || true
}

verify_installation() {

    if [[ ! -x "$INSTALL_DAEMON" ]]; then
        error "Daemon installation failed."
        exit 1
    fi

    if [[ ! -x "$INSTALL_SETUP" ]]; then
        error "Setup utility installation failed."
        exit 1
    fi

    if [[ ! -f "$INSTALL_SERVICE" ]]; then
        error "systemd service installation failed."
        exit 1
    fi

    if [[ ! -x "$INSTALL_DISPATCHER" ]]; then
        error "NetworkManager dispatcher installation failed."
        exit 1
    fi

    if [[ ! -s "$CONFIG_FILE" ]]; then
        error "Configuration file is empty."
        exit 1
    fi

    systemd-analyze verify "$INSTALL_SERVICE" >/dev/null 2>&1 || {
        error "Installed systemd service validation failed."
        exit 1
    }
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

main() {

    clear

    printf "\n"
    printf "%sSophos%s %sLogin Daemon Installer%s\n" \
        "$WHITE" "$RESET" "$GRAY" "$RESET"

    printf "\n"

    check_root

    info "Checking project files..."
    check_files
    success "Project files found."

    info "Checking dependencies..."
    check_dependencies
    success "Dependencies found."

    info "Validating project files..."
    validate_files
    success "Project files validated."

    info "Installing files..."

    install_directories
    install_programs
    install_config

    success "Files installed."

    info "Validating installed service..."
    systemd-analyze verify "$INSTALL_SERVICE" >/dev/null 2>&1
    success "systemd service validated."

    info "Configuring NetworkManager integration..."
    configure_service
    success "NetworkManager-triggered service configured."

    systemctl daemon-reload

    verify_installation

    printf "\n"
    printf "%sInstallation complete.%s\n" "$GREEN" "$RESET"

    printf "\n"
    printf "%sInstalled:%s\n" "$WHITE" "$RESET"
    printf "  %s/usr/bin/sophos-login%s\n" "$GRAY" "$RESET"
    printf "  %s/usr/bin/sophos-login-setup%s\n" "$GRAY" "$RESET"
    printf "  %s/etc/sophos-login%s\n" "$GRAY" "$RESET"
    printf "  %sNetworkManager dispatcher%s\n" "$GRAY" "$RESET"

    printf "\n"
    printf "%sNext:%s\n" "$WHITE" "$RESET"
    printf "  %ssudo sophos-login-setup%s\n" "$GRAY" "$RESET"

    printf "\n"
}

main "$@"