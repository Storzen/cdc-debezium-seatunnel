#!/usr/bin/env bash
# Contrôle avant passage : à lancer juste avant de monter sur l'estrade.
. "$(dirname "$0")/lib.sh"

step "Conteneurs"
dc ps --format 'table {{.Service}}\t{{.Status}}'
for s in pg-source pg-target kafka-1 kafka-2 kafka-3 connect seatunnel kafka-ui; do
  dc ps --status running --services | grep -qx "$s" || fail "$s n'est pas démarré"
done
ok "8 conteneurs démarrés"

step "Connecteur Debezium"
curl -sf http://localhost:8083/connectors/registre-plots/status | grep -q '"state":"RUNNING"' \
  && ok "registre-plots RUNNING" || fail "connecteur pas RUNNING"

step "Topic et réplication"
ktool kafka-topics.sh --describe --topic "$TOPIC"
ktool kafka-topics.sh --describe --topic "$TOPIC" | grep -q 'Isr: [0-9],[0-9],[0-9]' \
  && ok "3 copies synchronisées (ISR = 3)" || printf '%s! ISR incomplet (un broker arrêté ?)%s\n' "$RED" "$RESET"

step "Cohérence source / catalogue"
s=$(source_count); c=$(catalog_count)
[ "$s" = "$c" ] && ok "$s lignes de chaque côté" || fail "source $s lignes, catalogue $c lignes"

step "Délai de bout en bout"
"$(dirname "$0")/latency.sh"
