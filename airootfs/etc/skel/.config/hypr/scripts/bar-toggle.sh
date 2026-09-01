#!/bin/bash
if pgrep -f "quickshell -c bar" >/dev/null; then
  pkill -f "quickshell -c bar"
else
  setsid quickshell -c bar -n >/dev/null 2>&1 &
fi