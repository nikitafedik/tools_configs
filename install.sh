#!/bin/bash

# Define config directories
CONFIG_DIR="$HOME/.config/zellij"
CONFIG_FILE="config.kdl"

# Function to prompt user for confirmation
confirm() {
    read -r -p "Do you want to install custom Zellij config? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Ask for confirmation
if ! confirm; then
    echo "Installation cancelled."
    exit 1
fi

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# If existing config exists, rename it with _old suffix
if [ -f "$CONFIG_FILE" ]; then
    echo "Backing up existing config to ${CONFIG_DIR}/${CONFIG_FILE}_old"
    mv "${CONFIG_DIR}/${CONFIG_FILE}" "${CONFIG_DIR}/${CONFIG_FILE}_old"
fi

# Copy new config file
cp ".config/zellij/config.kdl" "${CONFIG_DIR}/$CONFIG_FILE"
echo "New config installed successfully!"