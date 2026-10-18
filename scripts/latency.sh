#!/usr/bin/env bash
# Mesure le délai source → catalogue sur une modification neutre (prix inchangé).
. "$(dirname "$0")/lib.sh"
psrc -q -c "update plots set price_fcfa = price_fcfa where reference = 'TK-YDE-0001';"
before=$(ptgt -At -c "select synced_at from catalog where reference = 'TK-YDE-0001';")
for i in $(seq 1 30); do
  now=$(ptgt -At -c "select synced_at from catalog where reference = 'TK-YDE-0001';")
  [ "$now" != "$before" ] && break
  sleep 0.5
done
ptgt -c "select reference,
                round(extract(epoch from synced_at - source_updated_at::timestamptz)::numeric, 2) as delai_secondes
         from catalog where reference = 'TK-YDE-0001';"
