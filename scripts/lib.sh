# Fonctions communes aux scripts de la démo. Compatible bash 3.2 (macOS).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "Fichier .env absent : cp .env.example .env, puis changer les mots de passe." >&2
  exit 1
fi
set -a; . ./.env; set +a
: "${SOURCE_DB_PASSWORD:?SOURCE_DB_PASSWORD manquant dans .env}"
: "${TARGET_DB_PASSWORD:?TARGET_DB_PASSWORD manquant dans .env (voir .env.example)}"

TOPIC=registre.public.plots
BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[32m'; RED=$'\033[31m'; CYAN=$'\033[36m'; RESET=$'\033[0m'

dc()   { docker compose --profile deliver "$@"; }
psrc() { dc exec -T pg-source psql -U postgres -d registre -v ON_ERROR_STOP=1 "$@"; }
ptgt() { dc exec -T pg-target psql -U postgres -d catalogue -v ON_ERROR_STOP=1 "$@"; }
ktool() { local t=$1; shift; dc exec -T kafka-1 "/opt/kafka/bin/$t" --bootstrap-server kafka-1:19092 "$@"; }

step() { printf '\n%s▶ %s%s\n' "$BOLD" "$*" "$RESET"; }
ok()   { printf '%s✔ %s%s\n' "$GREEN" "$*" "$RESET"; }
fail() { printf '%s✘ %s%s\n' "$RED" "$*" "$RESET" >&2; exit 1; }

# Affiche le SQL avant de l'exécuter sur la source (ce que la salle voit).
show_and_run_source() {
  printf '%s%s%s\n' "$CYAN" "$1" "$RESET"
  psrc -c "$1"
}

# Le catalogue public tel que le verrait le site.
show_catalog() {
  ptgt -c "select id, reference, district, area_m2, price_fcfa, status from catalog order by id;"
}

# wait_for "description" secondes commande...
wait_for() {
  local what=$1 secs=$2; shift 2
  local i=0
  printf '%s  attente : %s%s' "$DIM" "$what" "$RESET"
  until "$@" >/dev/null 2>&1; do
    i=$((i+1))
    if [ "$i" -ge "$secs" ]; then echo; return 1; fi
    printf '.'; sleep 1
  done
  echo; ok "$what"
}

# Remplace @@VAR@@ par la valeur de la variable (mots de passe sans / & | ni guillemets).
render() {
  sed -e "s|@@SOURCE_DB_PASSWORD@@|${SOURCE_DB_PASSWORD}|g" \
      -e "s|@@TARGET_DB_PASSWORD@@|${TARGET_DB_PASSWORD}|g" "$1" > "$2"
}

catalog_count() { ptgt -At -c "select count(*) from catalog;" 2>/dev/null | tr -d '[:space:]'; }
source_count()  { psrc -At -c "select count(*) from plots;" 2>/dev/null | tr -d '[:space:]'; }
