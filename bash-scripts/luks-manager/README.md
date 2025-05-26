# LUKS Management Utility

A Bash script for managing LUKS-encrypted devices.

## Origin

This script was created based on the Debian Live environment (`debian-live-12.11.0-amd64-kde.iso`) from:
[https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/](https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/)

## Key Features

- **Slot 1 Protection**: Special safeguards for slot 1 which contains:
  - The encryption keyfile (`/crypto_keyfile.bin`)
  - Required for automatic disk decryption during boot
- Interactive menu for safe LUKS management
- Visual verification of all password slots

## Requirements

- Debian-based system (tested on Debian Live 12.11.0)
- Root privileges

## Installation & Usage

```
wget https://example.com/luks-manager.sh
chmod +x luks-manager.sh
sudo ./luks-manager.sh
```