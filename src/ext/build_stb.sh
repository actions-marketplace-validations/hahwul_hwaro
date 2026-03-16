#!/bin/sh
# Build stb_impl.o if it doesn't exist or is older than stb_impl.c
DIR="$(cd "$(dirname "$0")" && pwd)"
OBJ="$DIR/stb_impl.o"
SRC="$DIR/stb_impl.c"

if [ ! -f "$OBJ" ] || [ "$SRC" -nt "$OBJ" ]; then
  cc -c -O2 -o "$OBJ" "$SRC"
fi
