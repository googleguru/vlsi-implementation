#!/bin/bash

set -euo pipefail

# allow this script to be invoked from any folder
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ $EUID -ne 0 ]; then
  echo "This script must be run with sudo"
  exit 1
fi

if git submodule status --recursive | grep -q "^-"; then
  git submodule update --init --recursive
fi

"$DIR/etc/DependencyInstaller.sh" -base
"$DIR/tools/OpenROAD/etc/DependencyInstaller.sh" -base

sudo -u $SUDO_USER "$DIR/etc/DependencyInstaller.sh" -common -prefix="$DIR/dependencies"
sudo -u $SUDO_USER "$DIR/tools/OpenROAD/etc/DependencyInstaller.sh" -common -prefix="$DIR/dependencies"
