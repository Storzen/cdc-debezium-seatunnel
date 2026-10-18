#!/usr/bin/env bash
# Arrête tout et libère la mémoire (les volumes sont gardés ; up.sh repart de zéro de toute façon).
. "$(dirname "$0")/lib.sh"
dc down --remove-orphans
