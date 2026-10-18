#!/usr/bin/env bash
# Vue en continu pour la démo. Usage : ./scripts/watch.sh catalog   (ou : source)
. "$(dirname "$0")/lib.sh"
side=${1:-catalog}
while true; do
  out=$(
    if [ "$side" = source ]; then
      psrc -c "select id, reference, district, price_fcfa, status, owner_name, floor_price_fcfa from plots order by id;"
    else
      ptgt -c "select id, reference, district, area_m2, price_fcfa, status,
                      to_char(synced_at, 'HH24:MI:SS') as synced from catalog order by id;"
    fi 2>&1)
  clear
  if [ "$side" = source ]; then printf '%sREGISTRE INTERNE (source)%s   %s\n' "$BOLD" "$RESET" "$(date +%H:%M:%S)"
  else printf '%sCATALOGUE PUBLIC (cible)%s   %s\n' "$BOLD" "$RESET" "$(date +%H:%M:%S)"; fi
  echo "$out"
  sleep 1
done
