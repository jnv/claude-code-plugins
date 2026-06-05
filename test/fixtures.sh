#!/usr/bin/env bash
# Builds offline fixtures mirroring upstream layout. Sourced by tests.
# make_release_archive <dir> <rid>  -> writes <dir>/v9.9.9/context-king-<rid>.tar.gz
make_release_archive() {
  local out="$1" rid="$2" stage
  stage="$(mktemp -d)"
  mkdir -p "$stage/context-king/skills/ck" \
           "$stage/context-king/models/bge-small-en-v1.5/onnx"
  # fake binary that echoes a marker + its model dir + args
  cat > "$stage/context-king/skills/ck/ck" <<'EOF'
#!/usr/bin/env bash
echo "FAKE-CK rid-marker model=$CK_MODEL_DIR args=$*"
EOF
  chmod +x "$stage/context-king/skills/ck/ck"
  echo "fake-lib-$rid" > "$stage/context-king/skills/ck/libtree-sitter.so"
  echo "vocab" > "$stage/context-king/models/bge-small-en-v1.5/vocab.txt"
  echo "onnx"  > "$stage/context-king/models/bge-small-en-v1.5/onnx/model.onnx"
  mkdir -p "$out/v9.9.9"
  tar -czf "$out/v9.9.9/context-king-${rid}.tar.gz" -C "$stage" context-king
  rm -rf "$stage"
}

# make_source_archive <dir>  -> writes <dir>/v9.9.9.tar.gz (a ContextKing-9.9.9/ tree)
make_source_archive() {
  local out="$1" stage
  stage="$(mktemp -d)"
  local root="$stage/ContextKing-9.9.9"
  mkdir -p "$root/skills/ck-find-files" "$root/skills/ck" "$root/hooks" "$root/agents"
  cat > "$root/skills/ck-find-files/SKILL.md" <<'EOF'
---
name: ck-find-files
---
Run: .claude/skills/ck/ck find-files "<query>"
EOF
  echo "binary placeholder" > "$root/skills/ck/ck"
  for h in ck-bash-guard ck-read-guard ck-search-guard ck-scope-hint ck-postsession agent-usage-guard ck-update-check; do
    echo "#!/usr/bin/env bash" > "$root/hooks/$h.sh"
    echo "# uses .claude/skills/ck/ck internally" >> "$root/hooks/$h.sh"
  done
  echo "explore agent" > "$root/agents/explore.md"
  mkdir -p "$out"
  tar -czf "$out/v9.9.9.tar.gz" -C "$stage" ContextKing-9.9.9
  rm -rf "$stage"
}

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
