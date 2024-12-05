#!/bin/bash

LINK_PATH="/usr/local/bin/tsc-cli"
OWNER="WeCanSTU" 
REPO="TechSync"
GITHUB_TOKEN="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"

# Function to add udev rules if they don't already exist
add_udev_rule() {
  HIDRAW_RULE_FILE="/etc/udev/rules.d/99-hidraw-permissions.rules"
  HIDRAW_RULE='SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3743", ATTRS{idProduct}=="a022", MODE="0666", GROUP="plugdev"'

  TTY_RULE_FILE="/etc/udev/rules.d/99-tty-permissions.rules"
  TTY_RULE='SUBSYSTEM=="tty", ATTRS{idVendor}=="3743", ATTRS{idProduct}=="a022", MODE="0666", GROUP="dialout"'

  # Add HIDRAW rule if it doesn't exist
  if [ -f "$HIDRAW_RULE_FILE" ]; then
    if ! grep -q "$HIDRAW_RULE" "$HIDRAW_RULE_FILE"; then
      echo "$HIDRAW_RULE" | sudo tee -a "$HIDRAW_RULE_FILE" > /dev/null
    fi
  else
    echo "$HIDRAW_RULE" | sudo tee "$HIDRAW_RULE_FILE" > /dev/null
  fi

  # Add TTY rule if it doesn't exist
  if [ -f "$TTY_RULE_FILE" ]; then
    if ! grep -q "$TTY_RULE" "$TTY_RULE_FILE"; then
      echo "$TTY_RULE" | sudo tee -a "$TTY_RULE_FILE" > /dev/null
    fi
  else
    echo "$TTY_RULE" | sudo tee "$TTY_RULE_FILE" > /dev/null
  fi

  # Reload udev rules and trigger
  sudo udevadm control --reload-rules
  sudo udevadm trigger
}

# Functions to check and install tools on Ubuntu
check_install_ubuntu() {
  PACKAGE=$1
  if ! dpkg -s $PACKAGE >/dev/null 2>&1; then
    echo "$PACKAGE is not installed. Installing..."
    sudo apt-get update
    sudo apt-get install -y $PACKAGE
  fi
}

# Functions to check and install tools on macOS
check_install_macos() {
  PACKAGE=$1
  if ! brew list $PACKAGE >/dev/null 2>&1; then
    echo "$PACKAGE is not installed. Installing..."
    brew install $PACKAGE
  fi
}

# Determine OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  OS="ubuntu"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
else
  echo "Unsupported OS: $OSTYPE"
  exit 1
fi

# Main installation logic
if [ "$OS" == "ubuntu" ]; then
  if ! command -v dpkg >/dev/null 2>&1; then
    echo "dpkg is not installed and it is critical to continue the installation. Exiting."
    exit 1
  fi
  check_install_ubuntu wget

  ASSET_URL=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    https://api.github.com/repos/$OWNER/$REPO/releases/latest \
    | grep "browser_download_url.*\.deb\"" \
    | cut -d '"' -f 4)

  if [ -z "$ASSET_URL" ]; then
    echo "No .deb release asset found."
    exit 1
  fi

  wget -q --show-progress $ASSET_URL -O /tmp/$(basename $ASSET_URL)
  sudo dpkg -i /tmp/$(basename $ASSET_URL)
  sudo apt-get install -f -y
  rm /tmp/$(basename $ASSET_URL)
  if [ ! -L "$LINK_PATH" ]; then
    sudo ln -s /opt/TechSync/resources/extraResources/bin/tsc-cli "$LINK_PATH"
  fi
  add_udev_rule
  echo "Installation of $(basename $ASSET_URL) completed on Ubuntu."


elif [ "$OS" == "macos" ]; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  check_install_macos wget

  ASSET_URL=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    https://api.github.com/repos/$OWNER/$REPO/releases/latest \
    | grep "browser_download_url.*\.dmg\"" \
    | cut -d '"' -f 4)

  if [ -z "$ASSET_URL" ]; then
    echo "No .dmg release asset found."
    exit 1
  fi

  FILE_PATH="/tmp/$(basename $ASSET_URL)"

  wget -q --show-progress $ASSET_URL -O $FILE_PATH

  if [[ $FILE_PATH == *.dmg ]]; then
    # Attach the DMG and capture the output
    ATTACH_OUTPUT=$(hdiutil attach "$FILE_PATH" -nobrowse)

    # Extract the correct volume mount point
    MOUNT_POINT=$(echo "$ATTACH_OUTPUT" | grep '/Volumes/' | awk '{for(i=3;i<=NF;++i) printf "%s ", $i; print ""}' | xargs)

    if [ -d "$MOUNT_POINT/TechSync.app" ]; then
      cp -r "$MOUNT_POINT/TechSync.app" /Applications
    fi
    # Detach the volume safely
    hdiutil detach "$MOUNT_POINT" -quiet
  else
    echo "Downloaded file is not a .dmg file"
    exit 1
  fi

  rm $FILE_PATH

  if [ ! -L "$LINK_PATH" ]; then
    sudo ln -s /Applications/TechSync.app/Contents/Resources/extraResources/bin/tsc-cli "$LINK_PATH"
  fi

  echo "Installation of TechSync completed on macOS."

else
  echo "Unsupported OS for installation."
  exit 1
fi
