# Démo CDC : Debezium + Apache SeaTunnel

Démo de l'exposé de Big Data (INGE 5 ISI, IUST, 2026-27) sur le thème
**Acquisition / Ingestion — CDC & pipeline integration : Debezium ; Apache SeaTunnel**, en mode **flux**.

Cas d'application : le catalogue des terrains disponibles d'une agence immobilière
(contexte TANK'IMMO, **données entièrement fictives**). Chaque INSERT, UPDATE et DELETE
du registre interne doit atteindre le catalogue public en quelques secondes.

## Le pipeline

```
script de simulation
        │ INSERT / UPDATE / DELETE
        ▼
PostgreSQL « registre interne »   table plots, wal_level=logical
        │ journal de transactions (WAL), décodage pgoutput
        ▼
Debezium, connecteur source dans Kafka Connect (mode distribué, 1 worker)
        │ un événement par changement (op, before, after)
        ▼
Kafka : 3 nœuds KRaft en mode combiné, topics répliqués ×3, min.insync.replicas=2
        │ format debezium_json
        ▼
SeaTunnel, moteur Zeta en mode local : FieldMapper ne garde que les colonnes publiques
        │ sink JDBC, upsert et delete par clé primaire
        ▼
PostgreSQL « catalogue public »   table catalog

À côté : Kafbat UI (brokers, topics, réplicas, messages, Kafka Connect).
```

## Versions figées

| Composant | Image |
|---|---|
| PostgreSQL (source et cible) | `postgres:18.6` |
| Kafka KRaft ×3 | `apache/kafka:4.3.1` |
| Kafka Connect + Debezium 3.7 | `quay.io/debezium/connect:3.7.0.Final` |
| SeaTunnel (Zeta local) | `expose/seatunnel:3.0.0` : `apache/seatunnel:3.0.0` avec le pilote PostgreSQL remplacé par 42.7.5 |
| Interface web Kafka | `kafbat/kafka-ui:v1.5.0` |

Les cinq images de base sont disponibles en arm64 (vérifié le 9 octobre 2026 sur MacBook Pro M1 Pro)
et publiées aussi en amd64 pour les machines Windows / Intel (non testé de notre côté).

## Prérequis

- Docker avec Compose v2 : OrbStack ou Docker Desktop sur macOS, Docker Desktop (backend WSL 2) sous Windows.
- Environ 6 à 8 Go de RAM libres pour le pipeline complet (8 conteneurs).
- Sous Windows : rien à régler pour les fins de ligne, `.gitattributes` force LF (indispensable aux scripts lus par les conteneurs Linux).

## Organisation du dépôt

Le pipeline se monte brique par brique, dans le sens de la donnée. Chaque séance a son dossier
dans `seances/`, avec une fiche (notion, commandes, prédictions à écrire, résultats observés)
qui se termine par une section « À retenir » : ce qu'il faut comprendre, ce qu'on peut conclure, et les questions probables.

```
compose.yaml        le pipeline, complété à chaque séance
.env.example        variables à copier dans .env (mots de passe)
seances/            une fiche par étape du parcours
  00-images/        séance zéro : images, test de fumée Kafka + Kafbat UI
  01-postgresql/    WAL, LSN, slot de réplication, publication, REPLICA IDENTITY
sql/source/         schéma et données initiales du registre interne (table plots)
seatunnel/          image SeaTunnel de la démo (pilote PostgreSQL à jour)
```

À venir au fil des séances : `sql/target/` (catalogue public),
`connect/` (configuration du connecteur Debezium), `seatunnel/jobs/` (job de streaming),
`scripts/` (scènes de la démo numérotées, contrôle avant passage, remise à zéro), `simulator/`.

## Avancement

| Séance | Notion | État |
|---|---|---|
| 0 | Images et test de fumée | terminée le 9 oct. (Mac) |
| 1 | PostgreSQL : WAL, slot de réplication, publication | prête |
| 2 | Kafka à 1 nœud : topic, partition, offset, groupe de consommateurs | |
| 3 | Debezium : snapshot initial, `op` / `before` / `after` | |
| 4 | SeaTunnel : source-transform-sink, upsert par clé | |
| 5 | Kafka à 3 nœuds : réplication, quorum, panne d'un broker | |

## Règles du dépôt

- Aucun secret versionné : les mots de passe vivent dans `.env` (ignoré par git), un `.env.example` documente les variables.
- Les clips vidéo de secours (`clips/`) ne sont pas versionnés.
- Données fictives uniquement.
