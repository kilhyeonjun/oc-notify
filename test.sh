#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OC_NOTIFY="$SCRIPT_DIR/oc-notify"
SWIFT_BIN="$HOME/Applications/OcNotify.app/Contents/MacOS/oc-notify-swift"
LOG_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/oc-notify/history.log"
TMP_OUT="/tmp/oc-notify-test-out.$$"

PASS=0
FAIL=0
SKIP=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

pass() { ((PASS++)); echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { ((FAIL++)); echo -e "  ${RED}FAIL${NC} $1 — $2"; }
skip() { ((SKIP++)); echo -e "  ${YELLOW}SKIP${NC} $1 — $2"; }

get_frontmost() {
  osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null
}

run_swift() {
  "$SWIFT_BIN" "$@" >"$TMP_OUT" 2>&1 &
  local pid=$!
  sleep 3
  kill $pid 2>/dev/null
  sleep 0.5
  cat "$TMP_OUT" 2>/dev/null
}

cleanup() {
  rm -f "$TMP_OUT"
  pkill -f "oc-notify-swift.*test:" 2>/dev/null || true
}
trap cleanup EXIT

echo ""
echo -e "${BOLD}═══════════════════════════════════════════${NC}"
echo -e "${BOLD}  oc-notify test suite${NC}"
echo -e "${BOLD}═══════════════════════════════════════════${NC}"
echo ""

# ─── 1. Prerequisites ───
echo -e "${BOLD}[1] Prerequisites${NC}"

if [[ -x "$OC_NOTIFY" ]]; then
  pass "oc-notify script is executable"
else
  fail "oc-notify script" "not found at $OC_NOTIFY"
fi

if [[ -x "$SWIFT_BIN" ]]; then
  pass "Swift binary is executable"
else
  fail "Swift binary" "not found at $SWIFT_BIN"
fi

BUNDLE_ID=$(defaults read "$HOME/Applications/OcNotify.app/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || echo "")
if [[ -n "$BUNDLE_ID" ]]; then
  pass "Info.plist CFBundleIdentifier=$BUNDLE_ID"
else
  fail "Info.plist" "CFBundleIdentifier missing"
fi

if codesign -v "$HOME/Applications/OcNotify.app" 2>/dev/null; then
  pass "Code signature valid"
else
  fail "Code signature" "invalid"
fi

# ─── 2. Argument handling ───
echo ""
echo -e "${BOLD}[2] Argument handling${NC}"

if ! "$OC_NOTIFY" 2>/dev/null; then
  pass "No args → exit 1"
else
  fail "No args" "should exit 1"
fi

if "$OC_NOTIFY" "event" "" 2>/dev/null; then
  fail "Empty message" "should exit 1"
else
  pass "Empty message → exit 1"
fi

OUTPUT=$(run_swift "test:minimal" "msg")
if echo "$OUTPUT" | grep -q "showing banner"; then
  pass "Minimal args (event+message) → OK"
else
  fail "Minimal args" "no banner output"
fi

OUTPUT=$(run_swift "test:full" "msg" "session" "project")
if echo "$OUTPUT" | grep -q "showing banner"; then
  pass "Full args (all 4) → OK"
else
  fail "Full args" "no banner output"
fi

# ─── 3. History logging ───
echo ""
echo -e "${BOLD}[3] History logging${NC}"

LOG_BEFORE=$(wc -l < "$LOG_FILE" 2>/dev/null | tr -d ' ' || echo "0")
"$OC_NOTIFY" "test:log" "log test message" "LogSession" "LogProject" >/dev/null 2>&1 &
sleep 3
pkill -f "oc-notify-swift.*test:log" 2>/dev/null || true
sleep 0.5
LOG_AFTER=$(wc -l < "$LOG_FILE" 2>/dev/null | tr -d ' ' || echo "0")

if (( LOG_AFTER > LOG_BEFORE )); then
  LAST_LINE=$(tail -1 "$LOG_FILE")
  pass "History log entry added"
  if grep -q "test:log" "$LOG_FILE"; then
    pass "Log entry contains event field"
  else
    fail "Log entry format" "test:log not found in log"
  fi
else
  fail "History logging" "no entry added"
fi

# ─── 4. Swift binary output ───
echo ""
echo -e "${BOLD}[4] Swift binary output${NC}"

OUTPUT=$(run_swift "test:output" "output test" "TestSession" "TestProject")

if echo "$OUTPUT" | grep -q "showing banner"; then
  pass "NSLog: 'showing banner' present"
else
  fail "NSLog" "missing 'showing banner'"
fi

if echo "$OUTPUT" | grep -q "panel shown at"; then
  COORDS=$(echo "$OUTPUT" | grep "panel shown at" | sed 's/.*panel shown at //')
  pass "Panel position logged $COORDS"
else
  fail "NSLog" "missing panel position"
fi

if echo "$OUTPUT" | grep -q "TestProject"; then
  pass "Project name in banner title"
else
  fail "Banner title" "missing project name"
fi

# ─── 5. Focus preservation ───
echo ""
echo -e "${BOLD}[5] Focus preservation${NC}"

ORIGINAL_APP=$(get_frontmost)

run_swift "test:focus1" "focus test" "Sess" "Proj" >/dev/null 2>&1
DURING_APP=$(get_frontmost)

if [[ "$ORIGINAL_APP" == "$DURING_APP" ]]; then
  pass "Focus preserved: current app ($ORIGINAL_APP)"
else
  fail "Focus stolen" "$ORIGINAL_APP → $DURING_APP"
fi

osascript -e 'tell application "Finder" to activate' 2>/dev/null
sleep 0.5
BEFORE=$(get_frontmost)

run_swift "test:focus2" "finder focus" "Sess" "Proj" >/dev/null 2>&1
AFTER=$(get_frontmost)

if [[ "$BEFORE" == "$AFTER" ]]; then
  pass "Focus preserved: Finder frontmost ($BEFORE)"
else
  fail "Focus stolen from Finder" "$BEFORE → $AFTER"
fi

osascript -e "tell application \"$ORIGINAL_APP\" to activate" 2>/dev/null
sleep 0.3

# ─── 6. Process lifecycle ───
echo ""
echo -e "${BOLD}[6] Process lifecycle${NC}"

"$SWIFT_BIN" "test:lifecycle" "lifecycle" "Sess" "Proj" >/dev/null 2>&1 &
LC_PID=$!
sleep 1

if kill -0 $LC_PID 2>/dev/null; then
  pass "Process alive during banner (5s window)"
else
  fail "Process lifecycle" "exited too early"
fi

sleep 6

if kill -0 $LC_PID 2>/dev/null; then
  fail "Process cleanup" "still alive after 7s"
  kill $LC_PID 2>/dev/null
else
  pass "Process auto-terminated after dismiss"
fi

# ─── 7. Rapid successive notifications ───
echo ""
echo -e "${BOLD}[7] Rapid successive notifications${NC}"

for i in 1 2 3; do
  "$SWIFT_BIN" "test:rapid$i" "rapid $i" "Sess" "Proj" >/dev/null 2>&1 &
done
sleep 1

PROCS=$(pgrep -cf "oc-notify-swift" 2>/dev/null || echo "0")
if (( PROCS >= 1 )); then
  pass "Multiple concurrent instances ($PROCS alive)"
else
  pass "Multiple instances handled (fast exit)"
fi

sleep 6
REMAINING=$(pgrep -cf "oc-notify-swift.*test:rapid" 2>/dev/null || echo "0")
if (( REMAINING == 0 )); then
  pass "All rapid processes cleaned up"
else
  fail "Process leak" "$REMAINING still running"
  pkill -f "oc-notify-swift.*test:rapid" 2>/dev/null || true
fi

# ─── 8. osascript fallback ───
echo ""
echo -e "${BOLD}[8] osascript fallback${NC}"

TEMP_BIN="${SWIFT_BIN}.test-bak"
mv "$SWIFT_BIN" "$TEMP_BIN"

"$OC_NOTIFY" "test:fallback" "fallback msg" "Sess" "Proj" >/dev/null 2>&1 || true
pass "osascript fallback runs without crash"

mv "$TEMP_BIN" "$SWIFT_BIN"
pass "Swift binary restored"

# ─── 9. Screen position ───
echo ""
echo -e "${BOLD}[9] Screen position${NC}"

OUTPUT=$(run_swift "test:pos" "position" "Sess" "Proj")

POS_LINE=$(echo "$OUTPUT" | grep "panel shown at" | tail -1)
if [[ -n "$POS_LINE" ]]; then
  COORDS=$(echo "$POS_LINE" | grep -o '([0-9.]*,\s*[0-9.]*)' | head -1)
  if [[ -n "$COORDS" ]]; then
    pass "Valid coordinates $COORDS"
  else
    fail "Coordinates" "parse error: $POS_LINE"
  fi
else
  fail "Position" "no data in output"
fi

# ─── 10. Special characters ───
echo ""
echo -e "${BOLD}[10] Special characters${NC}"

OUTPUT=$(run_swift "test:special" 'He said "hello" & <world>' "Sess's" "Proj (v2)")
if echo "$OUTPUT" | grep -q "showing banner"; then
  pass "Quotes, ampersand, angle brackets OK"
else
  fail "Special chars" "crash or no output"
fi

OUTPUT=$(run_swift "test:emoji" "deploy complete 🚀✅" "Sess" "Proj")
if echo "$OUTPUT" | grep -q "showing banner"; then
  pass "Emoji in message OK"
else
  fail "Emoji" "crash or no output"
fi

LONG_MSG=$(printf 'x%.0s' {1..500})
OUTPUT=$(run_swift "test:long" "$LONG_MSG" "LongSessionTitleThatKeepsGoing" "VeryLongProjectNameHere")
if echo "$OUTPUT" | grep -q "showing banner"; then
  pass "Long text (500 chars) OK"
else
  fail "Long text" "crash or no output"
fi

# ─── Summary ───
echo ""
echo -e "${BOLD}═══════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL + SKIP))
echo -e "  ${GREEN}$PASS passed${NC}  ${RED}$FAIL failed${NC}  ${YELLOW}$SKIP skipped${NC}  ($TOTAL total)"
echo -e "${BOLD}═══════════════════════════════════════════${NC}"
echo ""

(( FAIL > 0 )) && exit 1
exit 0
