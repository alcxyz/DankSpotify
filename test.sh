#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

pass() { ((PASS++)); echo "  PASS: $1"; }
fail() { ((FAIL++)); echo "  FAIL: $1 — $2"; }

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$desc"
    else
        fail "$desc" "expected '$expected', got '$actual'"
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        pass "$desc"
    else
        fail "$desc" "expected to contain '$needle'"
    fi
}

# ── plugin.json validation ──────────────────────────────────────────

echo "plugin.json"
python3 -c "import json; d=json.load(open('plugin.json')); assert d['id']=='dankSpotify'; assert d['name']=='Spotify'" \
    && pass "valid JSON with correct id and name" \
    || fail "plugin.json" "invalid or wrong id/name"

python3 -c "
import json
d = json.load(open('plugin.json'))
required = ['id','name','description','version','author','type','capabilities','component','settings','trigger','requires_dms','requires','permissions']
missing = [f for f in required if f not in d]
assert not missing, f'missing fields: {missing}'
" && pass "all required fields present" \
  || fail "plugin.json" "missing required fields"

# ── VERSION format ──────────────────────────────────────────────────

echo "VERSION"
VERSION=$(cat VERSION | tr -d '[:space:]')
if echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    pass "semver format ($VERSION)"
else
    fail "VERSION" "'$VERSION' is not valid semver"
fi

# ── QML file references ─────────────────────────────────────────────

echo "file references"
COMPONENT=$(python3 -c "import json; print(json.load(open('plugin.json'))['component'])")
SETTINGS=$(python3 -c "import json; print(json.load(open('plugin.json'))['settings'])")
COMPONENT="${COMPONENT#./}"
SETTINGS="${SETTINGS#./}"

[ -f "$COMPONENT" ] && pass "component file exists ($COMPONENT)" || fail "component" "$COMPONENT not found"
[ -f "$SETTINGS" ] && pass "settings file exists ($SETTINGS)" || fail "settings" "$SETTINGS not found"

# ── pluginId consistency ─────────────────────────────────────────────

echo "pluginId consistency"
EXPECTED_ID=$(python3 -c "import json; print(json.load(open('plugin.json'))['id'])")

QML_ID=$(grep -oP 'pluginId:\s*"\K[^"]+' "$COMPONENT")
assert_eq "main QML pluginId matches plugin.json" "$EXPECTED_ID" "$QML_ID"

SETTINGS_ID=$(grep -oP 'pluginId:\s*"\K[^"]+' "$SETTINGS")
assert_eq "settings QML pluginId matches plugin.json" "$EXPECTED_ID" "$SETTINGS_ID"

# ── MPRIS bus name parsing ───────────────────────────────────────────

echo "MPRIS bus name parsing"

BUSCTL_OUTPUT=$(printf ':1.42  1000 systemd      org.mpris.MediaPlayer2.ncspot.instance1  - -\n:1.43  1000 systemd      org.freedesktop.Notifications            - -\n')

RESULT=$(echo "$BUSCTL_OUTPUT" | grep -oP 'org\.mpris\.MediaPlayer2\.ncspot\S*' | head -1)
assert_eq "extracts ncspot bus name" "org.mpris.MediaPlayer2.ncspot.instance1" "$RESULT"

# No match
NOMATCH=$(echo "no mpris here" | grep -oP 'org\.mpris\.MediaPlayer2\.ncspot\S*' || true)
assert_eq "empty when no bus found" "" "$NOMATCH"

# ── metadata parsing ─────────────────────────────────────────────────

echo "MPRIS metadata parsing"

# Simulated busctl metadata output
METADATA='"xesam:title" s "Bohemian Rhapsody" "xesam:artist" as 1 "Queen" "xesam:album" s "A Night at the Opera"'

TITLE=$(echo "$METADATA" | grep -oP '"xesam:title"\s+s\s+"\K[^"]+')
assert_eq "extracts track title" "Bohemian Rhapsody" "$TITLE"

ARTIST=$(echo "$METADATA" | grep -oP '"xesam:artist"\s+as\s+\d+\s+"\K[^"]+')
assert_eq "extracts artist" "Queen" "$ARTIST"

# ── PlaybackStatus parsing ──────────────────────────────────────────

echo "PlaybackStatus parsing"

STATUS_RAW='s "Playing"'
STATUS=$(echo "$STATUS_RAW" | sed 's/^s "//;s/"$//')
assert_eq "parses Playing status" "Playing" "$STATUS"

STATUS_RAW2='s "Paused"'
STATUS2=$(echo "$STATUS_RAW2" | sed 's/^s "//;s/"$//')
assert_eq "parses Paused status" "Paused" "$STATUS2"

# ── tab-separated output assembly ────────────────────────────────────

echo "status output format"

COMBINED=$(printf '%s\t%s\t%s' "Playing" "Bohemian Rhapsody" "Queen")
assert_eq "status field" "Playing" "$(echo "$COMBINED" | cut -f1)"
assert_eq "title field" "Bohemian Rhapsody" "$(echo "$COMBINED" | cut -f2)"
assert_eq "artist field" "Queen" "$(echo "$COMBINED" | cut -f3)"

# ── summary ──────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
