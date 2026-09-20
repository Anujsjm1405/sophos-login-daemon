# Sophos Login Daemon

A lightweight Linux daemon that automatically handles Sophos captive-portal authentication when connecting to a configured Wi-Fi network.

## Features

- Detects the configured Wi-Fi network
- Checks Internet connectivity
- Authenticates through the Sophos gateway when required
- Automatically triggers through NetworkManager
- Prevents duplicate authentication attempts
- Stores credentials with restricted permissions
- Runs with systemd security restrictions
- Includes a simple setup utility
- Includes install and uninstall scripts

## Architecture

```text
Wi-Fi Connection
       │
       ▼
NetworkManager
       │
       ▼
Dispatcher Script
       │
       ▼
systemd Service
       │
       ▼
Sophos Login Daemon
       │
       ├── Check SSID
       ├── Check Internet
       ├── Authenticate if required
       └── Verify connectivity