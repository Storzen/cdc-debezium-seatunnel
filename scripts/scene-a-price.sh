#!/usr/bin/env bash
# Scène a : baisse de prix dans le registre interne ; le catalogue suit.
. "$(dirname "$0")/lib.sh"
step "Scène a — price drop on plot TK-YDE-0003"
show_and_run_source "update plots set price_fcfa = 18500000 where reference = 'TK-YDE-0003';"
sleep 3
show_catalog
