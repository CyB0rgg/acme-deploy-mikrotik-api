#!/usr/bin/env bash
# Unit tests for certificate selection helpers in mikrotik.sh
# Run: bash tests/test_certificate_selection.sh
# Copyright (c) CyB0rgg <dev@bluco.re>
# License: MIT

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../mikrotik.sh"
set +e

pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
nok()  { fail=$((fail+1)); echo "FAIL - $1"; echo "       got: $2"; }

# RouterOS REST /certificate?common-name=X returns an array; the OLD cert
# (lowest .id) comes first. serial-number is lowercase hex without colons.
FIXTURE='[{".id":"*1","name":"kiroshi.group-20270208","common-name":"kiroshi.group","serial-number":"e6cb62b353c659b64b31752269e67bf3","invalid-after":"2026-05-12 23:59:59"},{".id":"*5","name":"temp-kiroshi.group-1787701725.cer_0","common-name":"kiroshi.group","serial-number":"70ec990f855ad47a29836acde7898980","invalid-after":"2027-02-08 23:59:59"}]'

# 1. picks the cert whose serial matches, not the first one
r=$(find_certificate_by_serial "$FIXTURE" "70ec990f855ad47a29836acde7898980")
[ "$r" = '*5|temp-kiroshi.group-1787701725.cer_0' ] && ok "selects by serial, not by position" || nok "selects by serial, not by position" "$r"

# 2. serial given in openssl style (upper-case, colons) still matches
r=$(find_certificate_by_serial "$FIXTURE" "70:EC:99:0F:85:5A:D4:7A:29:83:6A:CD:E7:89:89:80")
[ "$r" = '*5|temp-kiroshi.group-1787701725.cer_0' ] && ok "normalises colons/case" || nok "normalises colons/case" "$r"

# 3. old cert still findable
r=$(find_certificate_by_serial "$FIXTURE" "e6cb62b353c659b64b31752269e67bf3")
[ "$r" = '*1|kiroshi.group-20270208' ] && ok "finds first entry too" || nok "finds first entry too" "$r"

# 4. unknown serial -> empty output and non-zero rc
r=$(find_certificate_by_serial "$FIXTURE" "deadbeef"); rc=$?
[ -z "$r" ] && [ $rc -ne 0 ] && ok "unknown serial -> empty + rc!=0" || nok "unknown serial -> empty + rc!=0" "rc=$rc out=$r"

# 5. empty / [] response
r=$(find_certificate_by_serial "[]" "e6cb62b353c659b64b31752269e67bf3"); rc=$?
[ -z "$r" ] && [ $rc -ne 0 ] && ok "empty list -> rc!=0" || nok "empty list -> rc!=0" "rc=$rc out=$r"

# 6. free_certificate_name: a DIFFERENT cert holds the final name -> it gets renamed out of the way
CALLS=()
api_call() { CALLS+=("$1 $2 ${3:-}"); case "$1 $2" in
  "GET /certificate?name=kiroshi.group-20270208") echo '[{".id":"*1","name":"kiroshi.group-20270208","serial-number":"e6cb62b353c659b64b31752269e67bf3"}]';;
  PATCH*) echo '{}';;
  *) echo '[]';; esac; return 0; }
free_certificate_name "kiroshi.group-20270208" "*5" >/dev/null; rc=$?
if [ $rc -eq 0 ] && printf "%s\n" "${CALLS[@]:-}" | grep -q '^PATCH /certificate/\*1 {"name":"kiroshi.group-20270208-superseded-'; then ok "renames the squatter before final rename"; else nok "renames the squatter before final rename" "$(printf "%s;" "${CALLS[@]:-}")"; fi

# 7. free_certificate_name: the name is held by the SAME cert -> no rename
CALLS=()
free_certificate_name "kiroshi.group-20270208" "*1" >/dev/null; rc=$?
if [ $rc -eq 0 ] && ! printf "%s\n" "${CALLS[@]:-}" | grep -q '^PATCH'; then ok "no rename when name already ours"; else nok "no rename when name already ours" "$(printf "%s;" "${CALLS[@]:-}")"; fi

# 8. free_certificate_name: name unused -> no rename
api_call() { echo '[]'; return 0; }
CALLS=()
free_certificate_name "kiroshi.group-20270208" "*5" >/dev/null; rc=$?
[ $rc -eq 0 ] && ok "no rename when name unused" || nok "no rename when name unused" "rc=$rc"

# 9. service certificate lookup must isolate the right object (reverse-proxy "none" comes first)
SVC='[{".id":"*A","certificate":"none","name":"reverse-proxy","port":"443"},{".id":"*6","certificate":"kiroshi.group-20270208","name":"www-ssl","port":"443"},{".id":"*9","certificate":"*F","name":"api-ssl","port":"8729"}]'
r=$(service_certificate_from_response "$SVC" "www-ssl")
[ "$r" = "kiroshi.group-20270208" ] && ok "service lookup isolates www-ssl object" || nok "service lookup isolates www-ssl object" "$r"
r=$(service_certificate_from_response "$SVC" "api-ssl")
[ "$r" = "*F" ] && ok "service lookup finds api-ssl" || nok "service lookup finds api-ssl" "$r"
r=$(service_certificate_from_response "$SVC" "nope"); rc=$?
[ -z "$r" ] && [ $rc -ne 0 ] && ok "unknown service -> empty + rc!=0" || nok "unknown service -> empty + rc!=0" "rc=$rc out=$r"

# 10. verify_service_certificate end-to-end with mocked API
api_call() { echo "$SVC"; return 0; }
verify_service_certificate "www-ssl" "kiroshi.group-20270208" >/dev/null 2>&1 && ok "verify_service_certificate passes on correct binding" || nok "verify_service_certificate passes on correct binding" "rc=$?"
verify_service_certificate "www-ssl" "other" >/dev/null 2>&1 && nok "verify_service_certificate fails on wrong binding" "rc=0" || ok "verify_service_certificate fails on wrong binding"

echo "passed=$pass failed=$fail"
[ $fail -eq 0 ]
