# CDC demo: Debezium + Apache SeaTunnel

Demo for a Big Data class talk (INGE 5 ISI, IUST, 2026-27) on
**Acquisition / Ingestion: CDC & pipeline integration with Debezium and Apache SeaTunnel**, in **streaming** mode.

Use case: the catalog of available plots of land at a real estate agency
(TANK'IMMO context, **all data is fictional**). Every INSERT, UPDATE and DELETE
in the internal registry must reach the public catalog within a few seconds.

## The pipeline

```
simulation script
        │ INSERT / UPDATE / DELETE
        ▼
PostgreSQL "internal registry"   table plots, wal_level=logical
        │ write-ahead log (WAL), pgoutput decoding
        ▼
Debezium, source connector in Kafka Connect (distributed mode, 1 worker)
        │ one event per change (op, before, after)
        ▼
Kafka: 3 KRaft nodes in combined mode, topics replicated ×3, min.insync.replicas=2
        │ debezium_json format
        ▼
SeaTunnel, Zeta engine in local mode: FieldMapper keeps only the public columns
        │ JDBC sink, upsert and delete by primary key
        ▼
PostgreSQL "public catalog"   table catalog

Alongside: Kafbat UI (brokers, topics, replicas, messages, Kafka Connect).
```

## Pinned versions

| Component | Image |
|---|---|
| PostgreSQL (source and target) | `postgres:18.6` |
| Kafka KRaft ×3 | `apache/kafka:4.3.1` |
| Kafka Connect + Debezium 3.7 | `quay.io/debezium/connect:3.7.0.Final` |
| SeaTunnel (local Zeta) | `expose/seatunnel:3.0.0`: `apache/seatunnel:3.0.0` with the PostgreSQL driver replaced by 42.7.5 |
| Kafka web UI | `kafbat/kafka-ui:v1.5.0` |

All five base images ship for arm64 (checked on October 9, 2026 on a MacBook Pro M1 Pro)
and are also published for amd64, for Windows / Intel machines (not tested on our side).

## Requirements

- Docker with Compose v2: OrbStack or Docker Desktop on macOS, Docker Desktop (WSL 2 backend) on Windows.
- About 6 to 8 GB of free RAM for the full pipeline (8 containers).
- On Windows, line endings need no setup. `.gitattributes` forces LF, which the scripts read by the Linux containers require.

## Running the demo (rush mode)

```bash
cp .env.example .env          # then change both passwords (letters and digits only)
./scripts/up.sh               # reset + ordered startup, 2 to 3 min
./scripts/check.sh            # pre-show check, with latency measurement
./scripts/watch.sh catalog    # in a 2nd terminal: the live catalog
./scripts/scene-a-price.sh    # price drop
./scripts/scene-b-event.sh    # the raw event (+ Kafbat UI: http://localhost:8080)
./scripts/scene-c-delete.sh   # the DELETE propagated
./scripts/scene-d-broker.sh   # optional: stop one broker
./scripts/down.sh             # free the memory
```

## Repository layout

The pipeline is built one component at a time, following the data. Each session has its own folder
in `seances/`, with a sheet (concept, commands, predictions to write down, observed results)
that ends with a "Takeaways" section: what to understand, what can be concluded, and the likely questions.

```
compose.yaml        the full pipeline
.env.example        variables to copy into .env (passwords)
seances/            one sheet per step of the course
  00-images/        session zero: images, Kafka + Kafbat UI smoke test
  01-postgresql/    WAL, LSN, replication slot, publication, REPLICA IDENTITY
sql/source/         schema and seed data of the internal registry (table plots)
sql/target/         public catalog schema (table catalog)
connect/            Debezium connector configuration
seatunnel/          demo SeaTunnel image (updated PostgreSQL driver)
  jobs/             streaming job from Kafka to the catalog
scripts/            startup, pre-show check, demo scenes, teardown
DEMO.md             cheat sheet for the live demo
```

## Progress

The full pipeline already runs in rush mode: all four demo scenes passed on October 18, 2026,
with a measured delay of 0.23 to 0.76 s (see `DEMO.md`). The sheets for sessions 2 to 5 are still to be written.

| Session | Concept | Status |
|---|---|---|
| 0 | Images and smoke test | done on Oct 9 (Mac) |
| 1 | PostgreSQL: WAL, replication slot, publication | ready |
| 2 | Single-node Kafka: topic, partition, offset, consumer group | |
| 3 | Debezium: initial snapshot, `op` / `before` / `after` | |
| 4 | SeaTunnel: source-transform-sink, upsert by key | |
| 5 | 3-node Kafka: replication, quorum, broker failure | |

## Repository rules

- No secrets in git: passwords live in `.env` (ignored by git), and `.env.example` documents the variables.
- Backup video clips (`clips/`) are not versioned.
- Fictional data only.
