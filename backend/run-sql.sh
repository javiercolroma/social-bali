#!/bin/bash
# Ejecuta un archivo SQL (o "-" para stdin) contra el proyecto. Uso: run-sql.sh <project_ref> <archivo|->
set -uo pipefail
TOKEN=$(cat "${SUPABASE_TOKEN_FILE:-$HOME/.supabase/access-token}")
REF="${1:?falta project ref}"; SRC="${2:?falta archivo}"
body=$(python3 -c 'import json,sys; print(json.dumps({"query": (sys.stdin if sys.argv[1]=="-" else open(sys.argv[1], encoding="utf-8")).read()}))' "$SRC")
curl -s -X POST "https://api.supabase.com/v1/projects/$REF/database/query" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data-binary "$body" --max-time 120
echo
