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

echo
echo "test_secret_scan: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
