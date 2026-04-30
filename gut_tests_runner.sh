#!/bin/bash
# Run GUT tests headless
GODOT="${GODOT_BIN:-godot}"
if [ -x "/tmp/godot/Godot_v4.3-stable_linux.x86_64" ]; then
    GODOT="/tmp/godot/Godot_v4.3-stable_linux.x86_64"
fi
"$GODOT" --headless --path "$(dirname "$0")" -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit/,res://tests/integration/ -gexit "$@"
