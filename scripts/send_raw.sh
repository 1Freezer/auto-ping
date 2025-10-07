#!/usr/bin/env bash
set -euo pipefail

RAW="raw_request.txt"
if [ ! -f "$RAW" ]; then
  echo "ERROR: $RAW no existe. Crealo con la request cruda." >&2
  exit 1
fi

# Separa encabezados y body (primera línea = request line)
headers=$(awk 'BEGIN{h=1} { if(h){ if($0==""){ h=0; next } print $0 } }' "$RAW")
body=$(awk 'BEGIN{h=1} { if(h){ if($0==""){ h=0; next } } else print $0 }' "$RAW")

request_line=$(echo "$headers" | sed -n '1p' || true)
method=$(echo "$request_line" | awk '{print $1}')
path=$(echo "$request_line" | awk '{print $2}')

host=$(echo "$headers" | awk -F': ' '/^[Hh]ost:/{print $2; exit}')

if [ -z "$method" ] || [ -z "$path" ] || [ -z "$host" ]; then
  echo "ERROR: no pude parsear método/path/host. Verificá raw_request.txt" >&2
  echo "Request line: $request_line" >&2
  exit 1
fi

# Construir headers para curl (omitimos Host y Content-Length)
header_args=()
while IFS= read -r line; do
  if [[ "$line" =~ ^(GET|POST|PUT|DELETE|PATCH|OPTIONS|HEAD)\  ]]; then
    continue
  fi
  if [[ "$line" =~ ^[Hh]ost: ]] || [[ "$line" =~ ^[Cc]ontent-Length: ]]; then
    continue
  fi
  if [ -z "$line" ]; then
    continue
  fi
  header_args+=("-H" "$line")
done < <(echo "$headers" | tail -n +2)

# URL completo (asumimos HTTPS -> puerto 443)
url="https://${host}${path}"

# Guardar body si existe
tmpbody=""
if [ -n "$body" ]; then
  tmpbody=$(mktemp)
  printf "%s" "$body" > "$tmpbody"
fi

# Ejecutar curl con cookies (se guardan en cookies.txt)
cmd=(curl -i -sS -X "$method")
for h in "${header_args[@]}"; do
  cmd+=("$h")
done
if [ -n "$tmpbody" ]; then
  cmd+=(--data-binary "@$tmpbody")
fi
cmd+=("$url" "-c" "cookies.txt" "-b" "cookies.txt")

echo "Ejecutando request a: $url (HTTPS puerto 443)"
# Ejecuta y muestra la respuesta completa en los logs
"${cmd[@]}"
