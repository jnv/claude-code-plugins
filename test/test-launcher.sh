#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
. test/helpers.sh

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Fake plugin root: real launcher, a stub bootstrap, a pinned version.
proot="$work/plugin"
mkdir -p "$proot/bin"
cp plugins/context-king/bin/ck "$proot/bin/ck"
echo "v9.9.9" > "$proot/UPSTREAM_VERSION"
# stub bootstrap: create a fake ck + model under the target dir it is given
cat > "$proot/bin/ck-bootstrap.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
target="$3"
mkdir -p "$target/models/bge-small-en-v1.5"
cat > "$target/ck" <<'INNER'
#!/usr/bin/env bash
echo "RAN model=$CK_MODEL_DIR args=$*"
INNER
chmod +x "$target/ck"
EOF
chmod +x "$proot/bin/ck-bootstrap.sh"

data="$work/data"

# First call: triggers bootstrap, then execs and passes args + model env.
out="$(CLAUDE_PLUGIN_ROOT="$proot" CLAUDE_PLUGIN_DATA="$data" \
       bash "$proot/bin/ck" find-files hello 2>&1)"
assert_contains <(echo "$out") "RAN" "launcher execs bootstrapped binary"
assert_contains <(echo "$out") "args=find-files hello" "args forwarded"
assert_contains <(echo "$out") "$data/v9.9.9/models/bge-small-en-v1.5" "CK_MODEL_DIR set"

# Second call: binary present, bootstrap must NOT run again (remove stub to prove it).
rm "$proot/bin/ck-bootstrap.sh"
out2="$(CLAUDE_PLUGIN_ROOT="$proot" CLAUDE_PLUGIN_DATA="$data" \
        bash "$proot/bin/ck" signatures x 2>&1)"
assert_contains <(echo "$out2") "args=signatures x" "second call skips bootstrap"

finish
