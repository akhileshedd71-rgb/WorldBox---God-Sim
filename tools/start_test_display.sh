#!/usr/bin/env bash
# Optional local software display for Godot screenshots in Linux cloud tasks.
set -euo pipefail
display_number="${VERDANT_DISPLAY_NUMBER:-99}"
if [[ ! "$display_number" =~ ^[0-9]+$ ]]; then
  printf '%s\n' 'VERDANT_DISPLAY_NUMBER must be numeric.' >&2
  exit 1
fi
display_name=":$display_number"
if DISPLAY="$display_name" xdpyinfo >/dev/null 2>&1; then
  printf 'Display %s is already available.\n' "$display_name"
  exit 0
fi
command -v Xorg >/dev/null
test_dir="/tmp/verdant-xorg-$UID-$display_number"
mkdir -p "$test_dir"
cat > "$test_dir/dummy.conf" <<'EOF'
Section "Device"
 Identifier "Dummy"
 Driver "dummy"
 VideoRam 256000
EndSection
Section "Monitor"
 Identifier "Monitor"
 HorizSync 5.0-1000.0
 VertRefresh 5.0-200.0
 Modeline "1440x900" 106.5 1440 1520 1672 1904 900 903 909 934
EndSection
Section "Screen"
 Identifier "Screen"
 Device "Dummy"
 Monitor "Monitor"
 DefaultDepth 24
 SubSection "Display"
  Depth 24
  Modes "1440x900"
  Virtual 1920 1080
 EndSubSection
EndSection
Section "ServerFlags"
 Option "AutoAddDevices" "false"
 Option "AutoEnableDevices" "false"
EndSection
EOF
nohup Xorg "$display_name" -noreset -nolisten tcp -config "$test_dir/dummy.conf" -logfile "$test_dir/server.log" > "$test_dir/output.log" 2>&1 &
display_pid=$!
printf '%s\n' "$display_pid" > "$test_dir/pid"
for attempt in {1..30}; do
  if DISPLAY="$display_name" xdpyinfo >/dev/null 2>&1; then
    printf 'Local display %s started; PID %s.\n' "$display_name" "$display_pid"
    exit 0
  fi
  if ! kill -0 "$display_pid" 2>/dev/null; then
    cat "$test_dir/output.log" >&2
    exit 1
  fi
  sleep 0.1
done
printf 'Display did not become ready. Inspect %s/output.log.\n' "$test_dir" >&2
exit 1
