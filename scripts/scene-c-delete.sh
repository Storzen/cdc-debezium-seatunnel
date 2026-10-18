#!/usr/bin/env bash
# Scène c : le DELETE se propage — ce qu'une copie par lot ne verra jamais. Sommet de l'exposé.
. "$(dirname "$0")/lib.sh"
step "Scène c — plot TK-DLA-0002 is sold and removed from the registry"
show_and_run_source "delete from plots where reference = 'TK-DLA-0002';"
sleep 3
show_catalog
