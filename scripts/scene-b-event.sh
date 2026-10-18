#!/usr/bin/env bash
# Scène b : l'événement brut dans Kafka (à montrer aussi dans Kafbat UI, http://localhost:8080).
. "$(dirname "$0")/lib.sh"
step "Scène b — the raw event in Kafka (last message of $TOPIC)"
end=$(dc exec -T kafka-1 /opt/kafka/bin/kafka-get-offsets.sh --bootstrap-server kafka-1:19092 --topic "$TOPIC" | awk -F: '{print $3}' | tr -d '[:space:]')
off=$((end-1))
msg=$(dc exec -T kafka-1 /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka-1:19092 \
      --topic "$TOPIC" --partition 0 --offset "$off" --max-messages 1 2>/dev/null)
if command -v python3 >/dev/null 2>&1; then
  printf '%s' "$msg" | python3 -c 'import json,sys; e=json.load(sys.stdin); print(json.dumps({k:e.get(k) for k in ("op","before","after")}, indent=2, ensure_ascii=False))'
else
  echo "$msg"
fi
echo "Kafbat UI : http://localhost:8080 → Topics → $TOPIC → Messages"
