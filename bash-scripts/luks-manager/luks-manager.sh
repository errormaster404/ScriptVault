#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Keyfile path
KEYFILE_PATH="/crypto_keyfile.bin"

# Utility functions

error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Function to check root privileges
check_root() {
    [ "$(id -u)" -ne 0 ] && error_exit "This script must be run as root"
}

# Function to select LUKS device
select_luks_device() {
    echo -e "\n${BLUE}=== AVAILABLE DEVICES ===${NC}"
    lsblk -o NAME,FSTYPE,TYPE,SIZE,MOUNTPOINT

    
    while true; do
        read -p "Enter the LUKS device (e.g., /dev/sda2) or 'q' to quit: " device
        [ "$device" = "q" ] && exit 0
        
        if [ -b "$device" ]; then
            cryptsetup isLuks "$device" 2>/dev/null && {
                LUKS_DEVICE="$device"
                echo -e "${GREEN}Selected device: $LUKS_DEVICE${NC}"
                break
            } || echo -e "${RED}Device $device does not contain a valid LUKS header${NC}"
        else
            echo -e "${RED}Device $device not found${NC}"
        fi
    done
}

# Function to show detailed LUKS information
show_luks_info() {
    echo -e "\n${BLUE}=== DETAILED LUKS INFORMATION ===${NC}"
    echo -e "${YELLOW}Device: $LUKS_DEVICE${NC}\n"
    
    # Show LUKS dump with slot highlighting
    cryptsetup luksDump "$LUKS_DEVICE" | awk '
        /^Keyslot/ {print "\033[1;33m" $0 "\033[0m"; next}
        /^[0-9]:/ {print "\033[0;32m" $0 "\033[0m"; next}
        {print}
    '
    
    # Show additional information
    echo -e "\n${BLUE}=== MOUNT INFORMATION ===${NC}"
    lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT "$LUKS_DEVICE"
}

# Function to test password slots
test_slots() {
    echo -e "\n${BLUE}=== AVAILABLE PASSWORD SLOTS ===${NC}"
    
    # Extract slot information
    local slot_info=$(cryptsetup luksDump "$LUKS_DEVICE" | grep ENABLED)
    
    if [ -z "$slot_info" ]; then
        echo -e "${RED}No slots found${NC}"
        return
    fi
    
    # Show slot status
    echo -e "${YELLOW}Slot          Status${NC}"
    echo "$slot_info" | while read -r line; do
        local slot=$(echo "$line" | cut -d: -f1)
        local status=$(echo "$line" | awk '{print $4}')
        
        printf "${GREEN}%-5s${NC} %-8s %s\n" "$slot:" "$status"
    done
    
    echo -e "\n${BLUE}=== SLOT VERIFICATION ===${NC}"
    read -p "Enter the slot number to verify (0-7) or 't' for all: " slot
    
    if [ "$slot" = "t" ]; then
        # Verify all slots
        for s in {0..7}; do
            verify_slot "$s"
        done
    elif [[ "$slot" =~ ^[0-7]$ ]]; then
        verify_slot "$slot"
    else
        echo -e "${RED}Invalid slot${NC}"
    fi
}

# Helper function to verify a specific slot
verify_slot() {
    local slot=$1
    
    echo -e "\n${YELLOW}Verifying slot $slot...${NC}"
    
    if [ "$slot" -eq 1 ] && [ -f "$KEYFILE_PATH" ]; then
        # Verify slot 1 with keyfile
        cryptsetup luksOpen --test-passphrase --key-slot "$slot" --key-file "$KEYFILE_PATH" "$LUKS_DEVICE" 2>/dev/null && \
            echo -e "${GREEN}Slot $slot: Keyfile VALID${NC}" || \
            echo -e "${RED}Slot $slot: Keyfile INVALID${NC}"
    else
        # Verify slot with password
        cryptsetup luksOpen --test-passphrase --key-slot "$slot" "$LUKS_DEVICE" 2>/dev/null && \
            echo -e "${GREEN}Slot $slot: Password VALID${NC}" || \
            echo -e "${RED}Slot $slot: Password INVALID or slot DISABLED${NC}"
    fi
}

# Function to add a new password
add_password() {
    echo -e "\n${BLUE}=== ADD NEW PASSWORD ===${NC}"
    
    # Show available slots
    echo -e "${YELLOW}Available slots:${NC}"
    cryptsetup luksDump "$LUKS_DEVICE" | grep DISABLED | awk '{print $0}'
    
    while true; do
        read -p "Enter the slot number to use (0-7): " slot
        
        if [[ "$slot" =~ ^[0-7]$ ]] && cryptsetup luksDump "$LUKS_DEVICE" | grep DISABLED | awk '{print $0}'; then
            break
        else
            echo -e "${RED}Invalid slot or already in use. Choose a DISABLED slot${NC}"
        fi
    done
        
    echo -e "\n${YELLOW}Adding password to slot $slot...${NC}"
    cryptsetup luksAddKey "$LUKS_DEVICE" --key-slot "$slot"
    
}

# Function to remove a password
remove_password() {
    echo -e "\n${BLUE}=== REMOVE PASSWORD ===${NC}"
    
    # Show enabled slots excluding slot 1
    echo -e "${YELLOW}Enabled slots (slot 1 protected):${NC}"
    cryptsetup luksDump "$LUKS_DEVICE" | grep -E '^[0-7]: ENABLED' | grep -v '^1:'
    
    while true; do
        read -p "Enter the slot number to remove (0,2-7): " slot
        
        if [[ "$slot" =~ ^[0-7]$ ]] && [ "$slot" -ne 1 ] && cryptsetup luksDump "$LUKS_DEVICE" | grep ENABLED; then
            break
        else
            echo -e "${RED}Invalid slot, already disabled, or protected (slot 1). Choose a valid slot${NC}"
        fi
    done
    
    echo -e "\n${RED}WARNING: You are about to remove the password from slot $slot${NC}"
    read -p "Confirm you want to proceed? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    echo -e "\n${YELLOW}Enter a valid password to authorize the operation${NC}"
    cryptsetup luksKillSlot "$LUKS_DEVICE" "$slot" && \
        echo -e "${GREEN}Password successfully removed from slot $slot${NC}" || \
        echo -e "${RED}Error while removing password${NC}"
}

# Main menu
main_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== LUKS MANAGEMENT MENU ==="
        echo -e "Current device: ${GREEN}$LUKS_DEVICE${NC}"
        echo -e "${BLUE}=========================${NC}"
        echo "1) Show detailed LUKS information"
        echo "2) Test password slots"
        echo "3) Add new password"
        echo "4) Remove password (slot 1 protected)"
        echo "5) Change LUKS device"
        echo "6) Exit"
        echo -e "${BLUE}=========================${NC}"
        
        read -p "Select an option [1-6]: " choice
        
        case $choice in
            1) show_luks_info ;;
            2) test_slots ;;
            3) add_password ;;
            4) remove_password ;;
            5) select_luks_device ;;
            6) echo -e "${GREEN}Exiting...${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

# Script start
check_root
select_luks_device
main_menu