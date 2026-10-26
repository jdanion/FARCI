#!/usr/bin/env bash
# FARCI — helpers JSON via python3 stdlib (tests/lib/json.sh)

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "json.sh est une bibliothèque : utilisez 'source tests/lib/json.sh'" >&2
  exit 64
fi

json_get() {
  local json="$1" key="$2"
  python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get(sys.argv[2],''))" "$json" "$key"
}

json_valid() {
  python3 -c "import json,sys; json.loads(sys.argv[1])" "$1" 2>/dev/null
}
