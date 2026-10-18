#!/usr/bin/env bash
# Remise à zéro complète et démarrage ordonné du pipeline (≈ 2 à 3 min).
# Sert aussi de « reset » entre deux répétitions.
. "$(dirname "$0")/lib.sh"

step "1/7 Arrêt et suppression de l'état précédent (volumes compris)"
dc down -v --remove-orphans

step "2/7 Rendu des fichiers de configuration (.run/, non versionné)"
mkdir -p .run
render connect/registre-plots.json.template .run/registre-plots.json
render seatunnel/jobs/plots-to-catalog.conf.template .run/plots-to-catalog.conf
ok "configurations rendues"

step "3/7 Image SeaTunnel"
dc build seatunnel

step "4/7 Bases PostgreSQL et Kafka à 3 nœuds"
dc up -d --wait pg-source pg-target
dc up -d kafka-1 kafka-2 kafka-3
wait_for "quorum Kafka (3 nœuds)" 90 sh -c \
  "docker compose exec -T kafka-1 /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server kafka-1:19092 describe --status | grep -q 'CurrentVoters:.*\"id\": 3'" \
  || wait_for "Kafka répond" 60 sh -c "docker compose exec -T kafka-1 /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka-1:19092 --list" \
  || fail "Kafka ne répond pas : docker compose logs kafka-1"

step "5/7 Kafka Connect et interface web"
dc up -d connect kafka-ui
wait_for "API REST de Kafka Connect (port 8083)" 120 curl -sf http://localhost:8083/connectors \
  || fail "Kafka Connect ne répond pas : docker compose logs connect"

step "6/7 Enregistrement du connecteur Debezium"
curl -sf -X PUT -H 'Content-Type: application/json' \
  --data @.run/registre-plots.json http://localhost:8083/connectors/registre-plots/config >/dev/null \
  || fail "enregistrement refusé : curl -s -X PUT … pour voir l'erreur, ou docker compose logs connect"
wait_for "connecteur RUNNING" 60 sh -c \
  "curl -sf http://localhost:8083/connectors/registre-plots/status | grep -q '\"tasks\":\[{\"id\":0,\"state\":\"RUNNING\"'" \
  || { curl -s http://localhost:8083/connectors/registre-plots/status; echo; fail "connecteur pas RUNNING"; }
wait_for "topic $TOPIC créé par le snapshot" 60 sh -c \
  "docker compose exec -T kafka-1 /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka-1:19092 --describe --topic $TOPIC" \
  || fail "topic absent"

step "7/7 Job SeaTunnel (streaming)"
dc up -d seatunnel
n=$(source_count)
wait_for "catalogue rempli ($n lignes attendues)" 120 sh -c \
  "[ \"\$(docker compose exec -T pg-target psql -U postgres -d catalogue -At -c 'select count(*) from catalog')\" = \"$n\" ]" \
  || { dc logs --tail 60 seatunnel; fail "le catalogue ne se remplit pas (logs SeaTunnel ci-dessus)"; }

show_catalog
printf '\n%sPipeline prêt.%s Interface Kafka : http://localhost:8080   Contrôle : ./scripts/check.sh\n' "$BOLD" "$RESET"
