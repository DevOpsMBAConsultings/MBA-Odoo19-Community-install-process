#!/usr/bin/env bash
set -euo pipefail

# ====== CONFIG (edit if needed) ======
BASE="https://testnucpa.digifact.com"
TOKEN_PATH="/api/login/get_token"
TRANSFORM_PATH="/api/v2/transform/nuc"

TAXID="155704849-2-2021"
USERNAME="PA.155704849-2-2021.GONZALEZB"
PASSWORD="Digifact*25"
FORMAT="XML"

INPUT_XML="digifact/test/nuc.xml"
WORK_XML="digifact/test/nuc_work.xml"
OUT_JSON="digifact/test/response.json"
# ====================================

# Jump to repo root (this script lives in digifact/test/)
cd "$(dirname "$0")/../.."

if [[ ! -f "$INPUT_XML" ]]; then
  echo "ERROR: Missing $INPUT_XML"
  exit 1
fi

# 1) Get token
TOKEN="$(curl -sS -X POST "${BASE}${TOKEN_PATH}" \
  -H "Content-Type: application/json" \
  -d "{\"Username\":\"${USERNAME}\",\"Password\":\"${PASSWORD}\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('Token',''))")"

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: Token is empty. Check credentials or endpoint."
  exit 1
fi

echo "TOKEN=${TOKEN:0:25}..."

# 2) Build new values (Panama -05:00)
NUMERODF="$(python3 - <<'PY'
import time
print(str(int(time.time()))[-10:])  # 10 digits, changes every second
PY
)"

CODSEG="$(python3 - <<'PY'
import random
print(str(random.randint(100000000, 999999999)))  # 9 digits
PY
)"

ISSUED="$(python3 - <<'PY'
from datetime import datetime, timezone, timedelta
tz = timezone(timedelta(hours=-5))
print(datetime.now(tz).strftime("%Y-%m-%dT%H:%M:%S-05:00"))
PY
)"

echo "NUMERODF=$NUMERODF"
echo "CODSEG=$CODSEG"
echo "ISSUED=$ISSUED"

# 3) Prepare work xml from base xml (always start clean)
cp -f "$INPUT_XML" "$WORK_XML"

# Replace NumeroDF (dNroDF)
sed -i "s/Info Name=\"NumeroDF\" Value=\"[^\"]*\"/Info Name=\"NumeroDF\" Value=\"$NUMERODF\"/" "$WORK_XML"

# Replace CodigoSeguridad (dSeg)
sed -i "s/Info Name=\"CodigoSeguridad\" Value=\"[^\"]*\"/Info Name=\"CodigoSeguridad\" Value=\"$CODSEG\"/" "$WORK_XML"

# Replace IssuedDateTime (dFechaEm)
sed -i "s#<IssuedDateTime>[^<]*</IssuedDateTime>#<IssuedDateTime>$ISSUED</IssuedDateTime>#" "$WORK_XML"

echo ""
echo "VERIFY FIELDS IN WORK XML:"
grep -n 'IssuedDateTime' "$WORK_XML" || true
grep -n 'Info Name="NumeroDF"' "$WORK_XML" || true
grep -n 'Info Name="CodigoSeguridad"' "$WORK_XML" || true
echo ""

# 4) POST transform (XML body, token in Authorization)
URL="${BASE}${TRANSFORM_PATH}?TAXID=${TAXID}&USERNAME=${USERNAME}&FORMAT=${FORMAT}"

echo "POST -> $URL"
curl -sS -X POST "$URL" \
  -H "Authorization: $TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/xml" \
  --data-binary @"$WORK_XML" \
  -o "$OUT_JSON"

echo ""
echo "Saved response to: $OUT_JSON"
python3 -m json.tool "$OUT_JSON" | head -n 60
