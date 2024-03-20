#!/bin/sh

sleep 1 # give Hyprland a moment to set its defaults

way-displays > "/tmp/way-displays.${XDG_VTNR}.${USER}.log" 2>&1
