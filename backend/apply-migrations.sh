#!/bin/bash
# Aplica las migraciones de backend/supabase/migrations en orden contra el proyecto.
# Uso: migrate.sh <project_ref> [directorio]
set -uo pipefail
TOKEN=$(cat "${SUPABASE_TOKEN_FILE:-$HOME/.supabase/access-token}")
REF="${1:?falta project ref}"
DIR="${2:-$(cd "$(dirname "$0")" && pwd)/supabase/migrations}"
API="https://api.supabase.com/v1/projects/$REF/database/query"

fail=0
for f in "$DIR"/*.sql; do
  name=$(basename "$f")
  body=$(python3 -c 'import json,sys; print(json.dumps({"query": open(sys.argv[1], encoding="utf-8").read()}))' "$f")
  resp=$(curl -s -w $'\n%{http_code}' -X POST "$API" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    --data-binary "$body" --max-time 120)
  code=$(printf '%s' "$resp" | tail -1)
  payload=$(printf '%s' "$resp" | sed '$d')
  if [ "$code" = "200" ] || [ "$code" = "201" ]; then
    printf "  ✓ %-32s\n" "$name"
  else
    printf "  ✗ %-32s HTTP %s\n" "$name" "$code"
    printf '    %s\n' "$(printf '%s' "$payload" | head -c 400)"
    fail=$((fail+1))
  fi
done
echo "---"
[ "$fail" -eq 0 ] && echo "TODAS LAS MIGRACIONES OK" || echo "FALLARON: $fail"
