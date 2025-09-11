#!/bin/bash

# Weekday runner and scheduler helper.
#
# Run now (auto single/multi):
#   ./run-weekdays.sh
# Force multi or single:
#   ./run-weekdays.sh --multi | --single
# Install scheduler (Linux systemd user, macOS launchd, or cron fallback):
#   ./run-weekdays.sh --install [--time HH:MM] [--multi|--single]

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DEFAULT_TIME="09:00"

usage() {
  echo "Usage: $0 [--install] [--time HH:MM] [--multi|--single]" >&2
}

MODE="run"
RUN_VARIANT="auto"  # auto|multi|single
RUN_TIME="$DEFAULT_TIME"

while [ $# -gt 0 ]; do
  case "$1" in
    --install) MODE="install" ; shift ;;
    --time) RUN_TIME="${2:-}" ; shift 2 ;;
    --multi) RUN_VARIANT="multi" ; shift ;;
    --single) RUN_VARIANT="single" ; shift ;;
    -h|--help) usage ; exit 0 ;;
    *) echo "Unknown argument: $1" >&2 ; usage ; exit 2 ;;
  esac
done

pick_variant() {
  if [ "$RUN_VARIANT" = "multi" ]; then echo multi; return; fi
  if [ "$RUN_VARIANT" = "single" ]; then echo single; return; fi
  shopt -s nullglob
  local envs=("$SCRIPT_DIR/configs"/*.env)
  if [ ${#envs[@]} -gt 0 ]; then echo multi; else echo single; fi
}

ensure_stamp_dir() {
  STAMP_DIR="$SCRIPT_DIR/.state"
  mkdir -p "$STAMP_DIR"
  STAMP_FILE="$STAMP_DIR/last_run.date"
}

run_now() {
  # Skip weekends
  local dow
  dow=$(date +%u)  # 1..7 (Mon=1)
  if [ "$dow" -ge 6 ]; then
    echo "[Weekdays] Weekend detected (DOW=$dow). Skipping run."
    exit 0
  fi

  # Avoid duplicate runs on the same day
  ensure_stamp_dir
  local today
  today=$(date +%F)
  if [ -f "$STAMP_FILE" ] && grep -q "^$today$" "$STAMP_FILE"; then
    echo "[Weekdays] Already ran today ($today); skipping."
    exit 0
  fi

  local variant
  variant=$(pick_variant)
  if [ "$variant" = "multi" ]; then
    "$SCRIPT_DIR/run-multi.sh"
  else
    "$SCRIPT_DIR/run.sh"
  fi

  # Mark success for today
  echo "$today" > "$STAMP_FILE"
}

install_linux_systemd() {
  local variant unit_base time="$RUN_TIME"
  variant=$(pick_variant)
  unit_base="sonar-weekdays"
  local user_dir="$HOME/.config/systemd/user"
  mkdir -p "$user_dir"

  local svc="$user_dir/$unit_base.service"
  local tmr="$user_dir/$unit_base.timer"

  cat >"$svc" <<EOF
[Unit]
Description=Run Sonar scripts on weekdays

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash -lc '$SCRIPT_DIR/run-weekdays.sh --${variant}'
EOF

  cat >"$tmr" <<EOF
[Unit]
Description=Weekday schedule for $unit_base

[Timer]
OnCalendar=Mon..Fri $time
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now "$unit_base.timer"
  echo "[Install] systemd user timer installed: $tmr (Mon..Fri $time, Persistent=true)"
}

install_macos_launchd() {
  local variant plist label time="$RUN_TIME"
  variant=$(pick_variant)
  label="com.local.sonar.weekdays"
  local dir="$HOME/Library/LaunchAgents"
  mkdir -p "$dir"
  plist="$dir/$label.plist"
  local hour min
  hour=${time%:*}
  min=${time#*:}
  cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key><string>$label</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/bash</string>
      <string>-lc</string>
      <string>$SCRIPT_DIR/run-weekdays.sh --$variant</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
      <dict><key>Hour</key><integer>$hour</integer><key>Minute</key><integer>$min</integer><key>Weekday</key><integer>1</integer></dict>
      <dict><key>Hour</key><integer>$hour</integer><key>Minute</key><integer>$min</integer><key>Weekday</key><integer>2</integer></dict>
      <dict><key>Hour</key><integer>$hour</integer><key>Minute</key><integer>$min</integer><key>Weekday</key><integer>3</integer></dict>
      <dict><key>Hour</key><integer>$hour</integer><key>Minute</key><integer>$min</integer><key>Weekday</key><integer>4</integer></dict>
      <dict><key>Hour</key><integer>$hour</integer><key>Minute</key><integer>$min</integer><key>Weekday</key><integer>5</integer></dict>
    </array>
    <key>RunAtLoad</key><true/>
    <key>StandardOutPath</key><string>$SCRIPT_DIR/sonar-weekdays.log</string>
    <key>StandardErrorPath</key><string>$SCRIPT_DIR/sonar-weekdays.err</string>
  </dict>
  </plist>
EOF
  launchctl unload "$plist" >/dev/null 2>&1 || true
  launchctl load "$plist"
  echo "[Install] launchd job installed: $plist (Mon–Fri $time, RunAtLoad=true)"
}

install_cron_fallback() {
  # Fallback for environments without systemd/launchd.
  # Add @daily at time and @reboot entries calling this script; stamp file prevents duplicates.
  local variant cron_line_daily cron_line_boot time="$RUN_TIME"
  variant=$(pick_variant)
  cron_line_daily="0 $(echo "$time" | cut -d: -f2) $(echo "$time" | cut -d: -f1) * * [ -x '$SCRIPT_DIR/run-weekdays.sh' ] && '$SCRIPT_DIR/run-weekdays.sh' --$variant"
  cron_line_boot="@reboot [ -x '$SCRIPT_DIR/run-weekdays.sh' ] && '$SCRIPT_DIR/run-weekdays.sh' --$variant"
  # Read current crontab
  local tmp
  tmp=$(mktemp)
  crontab -l 2>/dev/null >"$tmp" || true
  grep -Fq "$cron_line_daily" "$tmp" || echo "$cron_line_daily" >>"$tmp"
  grep -Fq "$cron_line_boot" "$tmp" || echo "$cron_line_boot" >>"$tmp"
  crontab "$tmp"
  rm -f "$tmp"
  echo "[Install] cron entries added (@daily $time and @reboot)."
  echo "           Note: cron does not re-run missed times; @reboot + stamp avoids duplicates."
}

install_schedule() {
  local os
  os=$(uname -s)
  case "$os" in
    Linux)
      if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
        install_linux_systemd
      else
        install_cron_fallback
      fi
      ;;
    Darwin)
      if command -v launchctl >/dev/null 2>&1; then
        install_macos_launchd
      else
        install_cron_fallback
      fi
      ;;
    *)
      echo "Unsupported OS for auto-schedule: $os" >&2
      exit 2
      ;;
  esac
}

if [ "$MODE" = "install" ]; then
  install_schedule
else
  run_now
fi
