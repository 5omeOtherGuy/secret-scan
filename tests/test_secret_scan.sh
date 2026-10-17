#!/usr/bin/env bash
# test_secret_scan.sh: dash-bearing API key formats must be detected and
# ordinary text must not match. No real credentials are stored or printed.
# Dash-bearing formats include sk-ant-*, sk-proj-*, sk-svcacct-* and sk-or-*.
# The scanner also accepts any word starting with "sk-" and running 20+ chars.
#
# Every test vector is built at runtime; no secret-shaped literal is stored in this
# file or printed by it. The scanner's own output (which echoes the matching line)
# is always discarded; only the exit code is used and only the label is reported.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
SCAN="$ROOT/secret-scan.sh"
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT
export HOME="$TEST_TMP/home"
export XDG_CONFIG_HOME="$TEST_TMP/xdg/config"
export XDG_CACHE_HOME="$TEST_TMP/xdg/cache"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf 'ok   - %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL - %s\n' "$1"; }

# --- runtime-built vectors ------------------------------------------------------
tail_alnum=$(python3 -c 'print("A" * 40)')
tail_hex=$(python3 -c 'print("0123456789abcdef" * 4)')   # 64 hex chars
v_ant_api03=$(printf 'sk-%s%s%s' 'ant-' 'api03-' "$tail_alnum")
v_ant_oat01=$(printf 'sk-%s%s%s' 'ant-' 'oat01-' "$tail_alnum")
v_proj=$(printf 'sk-%s%s' 'proj-' "$tail_alnum")
v_svcacct=$(printf 'sk-%s%s' 'svcacct-' "$tail_alnum")
v_or_v1=$(printf 'sk-%s%s' 'or-v1-' "$tail_hex")
v_admin=$(printf 'sk-%s%s' 'admin-' "$tail_alnum")
v_plain=$(printf 'sk-%s' "$tail_alnum")
v_ghp=$(printf '%s%s' 'ghp_' "$tail_alnum")
v_akia=$(printf '%s%s' 'AKIA' 'A1B2C3D4E5F6G7H8')
v_short=$(printf 'sk-%s%s' 'ant-' 'x')
v_future=$(printf 'sk-%s%s' 'newvendor-v2-' "$tail_alnum")
# Additional vendor formats: xAI, Hugging Face, Google, Groq, and Stripe keys.
v_xai=$(printf '%s%s' 'xai-' "$tail_alnum")
v_hf=$(printf '%s%s' 'hf_' "$tail_alnum")
v_aiza=$(printf '%s%s' 'AIza' "$(python3 -c 'print("B" * 35)')")
v_gsk=$(printf '%s%s' 'gsk_' "$tail_alnum")
v_sk_live=$(printf '%s%s%s' 'sk' '_live_' "$tail_alnum")
v_rk_live=$(printf '%s%s%s' 'rk' '_live_' "$tail_alnum")

# The scanner echoes the matching line, so both streams are discarded here.
feeds() { # vector
  printf '%s' "$1" | "$SCAN" --stdin >/dev/null 2>&1
}

hit() { # label vector -> exit 1
  feeds "$2"; local rc=$?
  [ "$rc" = 1 ] && ok "positive: $1" || bad "positive: $1 (exit $rc, want 1)"
}
miss() { # label vector -> exit 0
  feeds "$2"; local rc=$?
  [ "$rc" = 0 ] && ok "negative: $1" || bad "negative: $1 (exit $rc, want 0)"
}

# --- positives: dash-bearing keys and the pre-existing kinds --------------------
hit 'sk-ant-api03' "$v_ant_api03"
hit 'sk-ant-oat01' "$v_ant_oat01"
hit 'sk-proj'      "$v_proj"
hit 'sk-svcacct'   "$v_svcacct"
hit 'sk-or-v1'     "$v_or_v1"
hit 'sk-admin'     "$v_admin"
hit 'sk-plain'     "$v_plain"
hit 'ghp_'         "$v_ghp"
hit 'AKIA'         "$v_akia"
hit 'sk-future-vendor (word-anchored)' "$v_future"
# Accepted false positive of the word-anchored alternative: a slug that starts with "sk-".
hit 'sk-learn slug' "$(printf 'sk-%s' 'learn-compatible-wrapper-module-v2')"
hit 'xai-'        "$v_xai"
hit 'hf_'         "$v_hf"
hit 'AIza'        "$v_aiza"
hit 'gsk_'        "$v_gsk"
hit 'sk_live_'    "$v_sk_live"
hit 'rk_live_'    "$v_rk_live"
# Realistic vendor lengths. The floors (xai- 40, gsk_ 40, hf_ 34, [rs]k_live_ 24)
# sit below current documented formats (80, 52, 34, 24+) but above ordinary
# names.
hit 'xai- (80)'     "$(printf '%s%s' 'xai-' "$(python3 -c 'print("C" * 80)')")"
hit 'hf_ (34)'      "$(printf '%s%s' 'hf_' "$(python3 -c 'print("C" * 34)')")"
hit 'gsk_ (52)'     "$(printf '%s%s' 'gsk_' "$(python3 -c 'print("C" * 52)')")"
hit 'sk_live_ (24)' "$(printf '%s%s%s' 'sk' '_live_' "$(python3 -c 'print("C" * 24)')")"

# --- negatives: hyphenated words and a short sk-ant- must not match -------------
miss 'disk-usage'  'disk-usage-monitoring-tool-2026'
miss 'issue-tracker'  'issue-tracker-lead-worktree-cleanup-pass'
miss 'disk-usage-report' 'disk-usage-report-for-the-whole-repo'
miss 'sk-ant-short' "$v_short"
miss 'hf_hub identifier' 'hf_hub_download_with_retries_and_cache_dir'
miss 'hf_ inside an identifier (no word boundary)' "$(printf 'model_%s%s' 'hf_' "$tail_alnum")"
miss 'short AIza' "$(printf '%s%s' 'AIza' 'ShortValue')"
miss 'xai- slug (20 letters)' "$(printf '%s%s' 'xai-' 'internationalization')"
miss 'gsk_ camelCase identifier' "$(printf '%s%s' 'gsk_' 'someLongCamelCaseIdentifierName')"
miss 'hf_ 33 chars' "$(printf '%s%s' 'hf_' "$(python3 -c 'print("C" * 33)')")"

# --- scanner file-name mode ----------------------------------------------------
if printf '%s\n' 'src/example.txt' | "$SCAN" --names >/dev/null 2>&1; then
  ok 'file-name mode accepts ordinary names'
else
  bad 'file-name mode accepts ordinary names'
fi
if printf '%s\n' 'secrets/example.key' | "$SCAN" --names >/dev/null 2>&1; then
  bad 'file-name mode rejects private-key files (exit 0)'
else
  rc=$?
  [ "$rc" = 1 ] && ok 'file-name mode rejects private-key files' || bad "file-name mode rejects private-key files (exit $rc)"
fi

# --- git fixtures ----------------------------------------------------------------
# Throwaway repositories under $TEST_TMP with a fixed identity; no user or system
# Git configuration is read. All git and scanner output is discarded.
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$TEST_TMP/gitconfig"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
: > "$GIT_CONFIG_GLOBAL"
G="$TEST_TMP/git"
mkdir -p "$G"

expect() { # label want got
  [ "$2" = "$3" ] && ok "$1" || bad "$1 (exit $3, want $2)"
}
q() { "$@" >/dev/null 2>&1; }
# copy_tool <dir>: put the scanner, hook and installer into <dir> as a user would.
copy_tool() {
  mkdir -p "$1/hooks"
  cp "$ROOT/secret-scan.sh" "$ROOT/install-git-hooks.sh" "$1/"
  cp "$ROOT/hooks/pre-push" "$1/hooks/"
}
# put <repo> <file> <content> <message>: write a file and commit it.
put() {
  printf '%s\n' "$3" > "$1/$2"
  q git -C "$1" add -A && q git -C "$1" commit -m "$4"
}
push() { # repo args... -> exit status of git push
  q git -C "$1" push "${@:2}"; echo $?
}
scan_tree() { # path -> exit status of tree mode
  q "$SCAN" "$1"; echo $?
}

# --- tree mode -----------------------------------------------------------------
t="$G/tree"
q git init -b main "$t"
put "$t" notes.txt 'ordinary example text' 'notes'
expect 'tree: clean Git working tree' 0 "$(scan_tree "$t")"
put "$t" deploy.pem 'not a key' 'pem'
expect 'tree: tracked forbidden file name' 1 "$(scan_tree "$t")"
q git -C "$t" rm -q deploy.pem && q git -C "$t" commit -m 'rm pem'
put "$t" config.txt "token=$v_ghp" 'key'
expect 'tree: credential-like content' 1 "$(scan_tree "$t")"
q git -C "$t" rm -q config.txt && q git -C "$t" commit -m 'rm key'
printf 'garbage' > "$t/.git/index"
expect 'tree: git ls-files failure is a scanner error' 2 "$(scan_tree "$t")"

d="$G/plain"
mkdir -p "$d/sub"
printf '%s\n' 'ordinary example text' > "$d/sub/notes.txt"
expect 'tree: clean directory outside Git' 0 "$(scan_tree "$d")"
printf '%s\n' 'not a key' > "$d/sub/id.pem"
expect 'tree: forbidden file name outside Git' 1 "$(scan_tree "$d")"
expect 'tree: missing path is a scanner error' 2 "$(scan_tree "$G/does-not-exist")"

# --- installer -----------------------------------------------------------------
outer="$G/outer"
q git init -b main "$outer"
p="$outer/project"
q git init -b main "$p"
copy_tool "$p"
q "$p/install-git-hooks.sh"
[ -x "$p/.git/hooks/pre-push" ] && [ ! -e "$outer/.git/hooks/pre-push" ] \
  && ok 'installer: run from repository root' || bad 'installer: run from repository root'
rm -f "$p/.git/hooks/pre-push"
(cd "$outer" && q ./project/install-git-hooks.sh)
[ -x "$p/.git/hooks/pre-push" ] && [ ! -e "$outer/.git/hooks/pre-push" ] \
  && ok 'installer: run from outside the repository' || bad 'installer: run from outside the repository'
put "$p" notes.txt 'ordinary example text' 'init'
rm -f "$p/.git/hooks/pre-push"
q git -C "$p" worktree add "$G/project-wt"
(cd "$G/project-wt" && q ./install-git-hooks.sh)
[ -x "$p/.git/hooks/pre-push" ] && ok 'installer: run from a linked worktree' || bad 'installer: run from a linked worktree'
for f in hooks/pre-push secret-scan.sh; do
  m="$G/missing-${f##*/}"
  q git init -b main "$m"
  copy_tool "$m"
  rm "$m/$f"
  q "$m/install-git-hooks.sh"; rc=$?
  [ "$rc" != 0 ] && [ ! -e "$m/.git/hooks/pre-push" ] \
    && ok "installer: refuses without $f" || bad "installer: refuses without $f (exit $rc)"
done

# --- pre-push hook, driven through git push to local bare remotes ---------------
r="$G/hook"
q git init -b main "$r"
copy_tool "$r"
q "$r/install-git-hooks.sh"
for name in origin upstream mirror; do
  q git init --bare -b main "$G/$name.git"
  q git -C "$r" remote add "$name" "$G/$name.git"
done
put "$r" notes.txt 'ordinary example text' 'init'
expect 'hook: clean push succeeds' 0 "$(push "$r" origin main)"
clean_sha=$(git -C "$r" rev-parse main)
[ "$(git -C "$G/origin.git" rev-parse main 2>/dev/null)" = "$clean_sha" ] \
  && ok 'hook: clean push reaches the remote' || bad 'hook: clean push reaches the remote'

put "$r" config.txt "token=$v_ghp" 'add key'
q git -C "$r" rm -q config.txt && q git -C "$r" commit -m 'remove key'
expect 'hook: key added then removed is refused' 1 "$(push "$r" origin main)"
[ "$(git -C "$G/origin.git" rev-parse main)" = "$clean_sha" ] \
  && ok 'hook: refused push leaves the remote unchanged' || bad 'hook: refused push leaves the remote unchanged'
q git -C "$r" reset --hard "$clean_sha"

# The remaining main pushes use +main so that an earlier push wrongly accepted
# cannot turn a later case into a non-fast-forward rejection that looks like a
# refusal. With the hook working, the remote is still at $clean_sha.
put "$r" deploy.pem 'not a key' 'add pem'
expect 'hook: forbidden file name is refused' 1 "$(push "$r" origin +main)"
q git -C "$r" reset --hard "$clean_sha"

put "$r" more.txt 'more ordinary text' 'more'
mv "$r/secret-scan.sh" "$G/scanner.bak"
expect 'hook: missing scanner is refused' 1 "$(push "$r" origin +main)"
mv "$G/scanner.bak" "$r/secret-scan.sh"
chmod -x "$r/secret-scan.sh"
expect 'hook: non-executable scanner is refused' 1 "$(push "$r" origin +main)"
chmod +x "$r/secret-scan.sh"
q git -C "$r" reset --hard "$clean_sha"

# New branches. origin's default branch holds only the clean commit; upstream's
# and mirror's main also hold a key commit pushed before the hook existed.
q git -C "$r" remote set-head origin main
put "$r" config.txt "token=$v_ghp" 'old key'
q git -C "$r" push --no-verify upstream main
q git -C "$r" push --no-verify mirror main
q git -C "$r" remote set-head upstream main
q git -C "$r" checkout -b feature
put "$r" feature.txt 'feature text' 'feature'
expect "hook: new branch scans only commits missing from the remote's default branch" \
  0 "$(push "$r" upstream feature)"
expect 'hook: new branch refuses an outgoing key commit' 1 "$(push "$r" origin feature)"
expect 'hook: new branch without a known default branch scans full history' \
  1 "$(push "$r" mirror feature)"

echo
echo "test_secret_scan: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
