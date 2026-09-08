#!/bin/bash

# Scheduled runner and scheduler helper.
#
# Run now (auto single/multi):
#   ./run-weekdays.sh
# Force multi or single:
#   ./run-weekdays.sh --multi | --single
# Install scheduler (Linux systemd user, macOS launchd, or cron fallback):
#   ./run-weekdays.sh --install [--time HH:MM] [--days mon,wed,fri|all] [--multi|--single]

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DEFAULT_TIME="09:00"
DEFAULT_DAYS="mon,tue,wed,thu,fri"

usage() {
  echo "Usage: $0 [--install] [--time HH:MM] [--days mon,tue,wed,thu,fri|all] [--multi|--single]" >&2
}

MODE="run"
RUN_VARIANT="auto"  # auto|multi|single
RUN_TIME="$DEFAULT_TIME"
RUN_DAYS="$DEFAULT_DAYS"

while [ $# -gt 0 ]; do
  case "$1" in
    --install) MODE="install" ; shift ;;
    --time) RUN_TIME="${2:-}" ; shift 2 ;;
    --days) RUN_DAYS="${2:-}" ; shift 2 ;;
    --multi) RUN_VARIANT="multi" ; shift ;;
    --single) RUN_VARIANT="single" ; shift ;;
    -h|--help) usage ; exit 0 ;;
    *) echo "Unknown argument: $1" >&2 ; usage ; exit 2 ;;
  esac
done

normalize_days() {
  SCHEDULE_DAYS_LABEL=""
  SYSTEMD_DAYS=""
  MACOS_WEEKDAYS=""
  CRON_WEEKDAYS=""
  RUN_DAYS_NUMS=","

  local raw="${RUN_DAYS// /}"
  if [ -z "$raw" ]; then
    echo "Error: --days cannot be empty" >&2
    exit 2
  fi
  case "$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')" in
    all|daily|everyday|todos|todo|diario|diário)
      raw="mon,tue,wed,thu,fri,sat,sun"
      ;;
  esac

  local IFS=,
  local token name num
  for token in $raw; do
    case "$(printf '%s' "$token" | tr '[:upper:]' '[:lower:]')" in
      mon|monday|seg|segunda|1) name="Mon"; num="1" ;;
      tue|tues|tuesday|ter|terca|terça|2) name="Tue"; num="2" ;;
      wed|wednesday|qua|quarta|3) name="Wed"; num="3" ;;
      thu|thur|thurs|thursday|qui|quinta|4) name="Thu"; num="4" ;;
      fri|friday|sex|sexta|5) name="Fri"; num="5" ;;
      sat|saturday|sab|sábado|sabado|6) name="Sat"; num="6" ;;
      sun|sunday|dom|domingo|7|0) name="Sun"; num="7" ;;
      *) echo "Error: invalid day in --days: $token" >&2 ; usage ; exit 2 ;;
    esac

    if [[ "$RUN_DAYS_NUMS" == *",$num,"* ]]; then
      continue
    fi

    SCHEDULE_DAYS_LABEL="${SCHEDULE_DAYS_LABEL:+$SCHEDULE_DAYS_LABEL,}$name"
    SYSTEMD_DAYS="${SYSTEMD_DAYS:+$SYSTEMD_DAYS,}$name"
    MACOS_WEEKDAYS="${MACOS_WEEKDAYS:+$MACOS_WEEKDAYS }$num"
    CRON_WEEKDAYS="${CRON_WEEKDAYS:+$CRON_WEEKDAYS,}$num"
    RUN_DAYS_NUMS="$RUN_DAYS_NUMS$num,"
  done
}

normalize_days

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
  local dow
  dow=$(date +%u)  # 1..7 (Mon=1)
  if [[ "$RUN_DAYS_NUMS" != *",$dow,"* ]]; then
    echo "[Scheduler] Today is not scheduled (DOW=$dow; scheduled=$SCHEDULE_DAYS_LABEL). Skipping run."
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
Description=Run Sonar scripts on scheduled days

[Service]
Type=oneshot
# Ensure Docker daemon is available before running; if not, skip this run.
ExecStartPre=/usr/bin/env bash -lc 'docker info >/dev/null 2>&1'
# Optional: ensure container list is readable (no hard failure if missing container)
ExecStartPre=/usr/bin/env bash -lc 'docker ps >/dev/null 2>&1'
WorkingDirectory=$SCRIPT_DIR
Environment=SONAR_CONTAINER_NAME=sa_sonarqube
Environment=SONAR_UP_TIMEOUT=120
Environment=SONAR_UP_RETRY_AFTER=300
ExecStart=/usr/bin/env bash -lc '"$SCRIPT_DIR/run-weekdays.sh" --${variant} --days "$RUN_DAYS"'
EOF

  cat >"$tmr" <<EOF
[Unit]
Description=Schedule for $unit_base

[Timer]
OnCalendar=$SYSTEMD_DAYS $time
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now "$unit_base.timer"
  echo "[Install] systemd user timer installed: $tmr ($SCHEDULE_DAYS_LABEL $time, Persistent=true)"
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
      <string>/usr/bin/osascript</string>
      <string>-e</string>
      <string>tell application "Terminal" to do script "/bin/bash '$SCRIPT_DIR/run-weekdays.sh' --$variant --days '$RUN_DAYS' &gt;&gt; '$SCRIPT_DIR/sonar-weekdays.log' 2&gt;&gt; '$SCRIPT_DIR/sonar-weekdays.err'"</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
EOF
  local day
  for day in $MACOS_WEEKDAYS; do
    cat >>"$plist" <<EOF
      <dict><key>Hour</key><integer>$hour</integer><key>Minute</key><integer>$min</integer><key>Weekday</key><integer>$day</integer></dict>
EOF
  done
  cat >>"$plist" <<EOF
    </array>
    <key>RunAtLoad</key><false/>
    <key>StandardOutPath</key><string>$SCRIPT_DIR/sonar-weekdays.log</string>
    <key>StandardErrorPath</key><string>$SCRIPT_DIR/sonar-weekdays.err</string>
  </dict>
  </plist>
EOF
  launchctl unload "$plist" >/dev/null 2>&1 || true
  launchctl load "$plist"
  echo "[Install] launchd job installed: $plist ($SCHEDULE_DAYS_LABEL $time, RunAtLoad=false)"
}

install_cron_fallback() {
  # Fallback for environments without systemd/launchd.
  # Add @daily at time and @reboot entries calling this script; stamp file prevents duplicates.
  local variant cron_line_daily cron_line_boot time="$RUN_TIME"
  variant=$(pick_variant)
  # Only run if Docker is available; otherwise skip silently.
  cron_line_daily="$(echo "$time" | cut -d: -f2) $(echo "$time" | cut -d: -f1) * * $CRON_WEEKDAYS [ -S /var/run/docker.sock ] && docker info >/dev/null 2>&1 && [ -x '$SCRIPT_DIR/run-weekdays.sh' ] && '$SCRIPT_DIR/run-weekdays.sh' --$variant --days '$RUN_DAYS'"
  cron_line_boot="@reboot [ -S /var/run/docker.sock ] && docker info >/dev/null 2>&1 && [ -x '$SCRIPT_DIR/run-weekdays.sh' ] && '$SCRIPT_DIR/run-weekdays.sh' --$variant --days '$RUN_DAYS'"
  # Read current crontab
  local tmp
  tmp=$(mktemp)
  crontab -l 2>/dev/null >"$tmp" || true
  grep -Fq "$cron_line_daily" "$tmp" || echo "$cron_line_daily" >>"$tmp"
  grep -Fq "$cron_line_boot" "$tmp" || echo "$cron_line_boot" >>"$tmp"
  crontab "$tmp"
  rm -f "$tmp"
  echo "[Install] cron entries added ($SCHEDULE_DAYS_LABEL $time and @reboot)."
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
