#!/bin/bash
if pgrep -x hypridle >/dev/null; then
  pkill -x hypridle
  notify-send "Idle locking disabled" -u low
else
  hypridle &
  notify-send "Idle locking enabled" -u low
fi