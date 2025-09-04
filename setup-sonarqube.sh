#!/usr/bin/env bash

set -e

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "Configuring vm.max_map_count on Linux..."
  sudo sysctl -w vm.max_map_count=262144
  echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
  sudo sysctl --system
elif [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Configuring vm.max_map_count inside Docker Desktop VM (macOS)..."
  docker run --rm --privileged --pid=host alpine:3.18 sysctl -w vm.max_map_count=262144
elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
  echo "Configuring vm.max_map_count in WSL2 (Windows)..."
  wsl sudo sysctl -w vm.max_map_count=262144
  wsl bash -c "echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf && sudo sysctl --system"
else
  echo "Unsupported OS: $OSTYPE"
  exit 1
fi

echo "✅ vm.max_map_count is set to 262144"
