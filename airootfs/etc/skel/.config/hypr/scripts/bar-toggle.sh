#!/bin/bash
# Toggle Pyramid OS bar - with proper cleanup
if pgrep -f "quickshell -c bar" >/dev/null; then
  pkill -9 -f "quickshell -c bar"
  sleep 0.3
else
  nohup quickshell -c bar >/dev/null 2>&1 &
fi
