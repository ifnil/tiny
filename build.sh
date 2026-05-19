#!/usr/bin/env bash

case "$1" in
"obj")
  zig build-obj -O ReleaseFast -femit-bin="obj/tiny.out" -femit-asm="obj/tiny.s"
  ;;
*)
  echo "unimplemented"
  ;;
esac
