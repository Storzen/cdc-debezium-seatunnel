#!/usr/bin/env bash
# Scène d (facultative) : un broker Kafka s'arrête, le flux continue.
. "$(dirname "$0")/lib.sh"
step "Scène d — stopping Kafka broker 2"
dc stop kafka-2
ktool kafka-topics.sh --describe --topic "$TOPIC" | grep -o 'Leader: [0-9]*.*Isr: [0-9,]*' || true
step "A new plot enters the registry while broker 2 is down"
show_and_run_source "insert into plots (reference, city, district, area_m2, price_fcfa, has_land_title, owner_name, floor_price_fcfa) values ('TK-YDE-0005', 'Yaoundé', 'Simbock', 300, 7000000, true, 'Joël Essomba', 6300000);"
sleep 4
show_catalog
step "Restarting broker 2"
dc start kafka-2
echo "Dans ~20 s, l'ISR revient à 3 : ./scripts/check.sh"
