#!/usr/bin/env bash

. "$(dirname "$0")/lib.sh"
step "Scène e — status change on plot TK-YDE-0001"
show_and_run_source "update plots set status = 'sold' where reference = 'TK-YDE-0001';"
sleep 3
show_catalog
