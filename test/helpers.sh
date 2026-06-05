#!/usr/bin/env bash
# Minimal assert helpers for plain-bash tests.
FAILED=0

assert_eq() { # actual expected message
  if [ "$1" = "$2" ]; then
    echo "  ok: $3"
  else
    echo "  FAIL: $3 (expected '$2', got '$1')"
    FAILED=1
  fi
}

assert_file() { # path message
  if [ -f "$1" ]; then echo "  ok: $2"; else echo "  FAIL: $2 (missing $1)"; FAILED=1; fi
}

assert_contains() { # file substring message
  if grep -qF "$2" "$1"; then echo "  ok: $3"; else echo "  FAIL: $3 ('$2' not in $1)"; FAILED=1; fi
}

assert_not_contains() { # file substring message
  if grep -qF "$2" "$1"; then echo "  FAIL: $3 ('$2' still in $1)"; FAILED=1; else echo "  ok: $3"; fi
}

finish() { [ "$FAILED" -eq 0 ] && echo "PASS" || { echo "FAIL"; exit 1; }; }
