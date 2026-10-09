# Séance zéro : les images démarrent-elles sur la machine ?

Durée : environ 1 heure. Aucune notion à apprendre ici, aucune prédiction à écrire.
But : lever les doutes laissés par la recherche sur les versions **avant** de construire dessus, et décider d'un repli tout de suite si une image pose problème.

Toutes les commandes se lancent depuis la **racine du dépôt** (`~/Developer/cdc-debezium-seatunnel`).
Note ce que tu observes dans le tableau de la fin.

## 0. Docker répond

```bash
docker version --format '{{.Server.Version}} {{.Server.Arch}}'
```

Attendu : un numéro de version suivi de `arm64` (sur le Mac). Si la commande échoue, ouvre OrbStack d'abord.

## 1. Télécharger les cinq images ✅ (9 octobre 2026)

```bash
docker pull postgres:18.6
docker pull apache/kafka:4.3.1
docker pull quay.io/debezium/connect:3.7.0.Final
docker pull apache/seatunnel:3.0.0
docker pull kafbat/kafka-ui:v1.5.0
```

Vérification de l'architecture :

```bash
for i in postgres:18.6 apache/kafka:4.3.1 quay.io/debezium/connect:3.7.0.Final apache/seatunnel:3.0.0 kafbat/kafka-ui:v1.5.0; do
  echo "$i -> $(docker image inspect --format '{{.Architecture}}' $i)"
done
```

Résultat : `arm64` pour les cinq. Premier doute levé : le tag `3.7.0.Final` de Debezium existe bien en arm64 sur quay.io.

## 2. PostgreSQL démarre, et où range-t-il ses données ?

```bash
docker run --rm -d --name pg-test -e POSTGRES_PASSWORD=test postgres:18.6
sleep 5
docker exec pg-test psql -U postgres -c "select version();" -c "show data_directory;" -c "show wal_level;"
docker rm -f pg-test
```

Note le `data_directory` (il décidera du chemin du volume à la séance 1) et le `wal_level` par défaut (on le changera à la séance 1).

## 3. Debezium : le connecteur PostgreSQL est-il dans l'image ?

```bash
docker run --rm --entrypoint ls quay.io/debezium/connect:3.7.0.Final /kafka/connect
```

Attendu : une liste de dossiers dont `debezium-connector-postgres`.

## 4. Kafka à 1 nœud et l'interface web

```bash
docker compose -f seances/00-images/compose-smoke.yml up -d
```

Attends 20 secondes, puis ouvre http://localhost:8080 dans le navigateur.

- Le cluster `smoke` apparaît-il en ligne, avec 1 broker ?
- Crée un topic `test` depuis l'interface (Topics → Add a Topic), puis produis un message (Produce Message) et relis-le (onglet Messages).

Si l'interface reste hors ligne ou affiche des erreurs :

```bash
docker compose -f seances/00-images/compose-smoke.yml logs kafka-ui | tail -40
```

C'est le doute principal de la séance : le client Kafka de Kafbat UI est plus ancien (3.9) que le broker (4.3.1). Si cela échoue, le repli décidé est Redpanda Console.

Puis on éteint :

```bash
docker compose -f seances/00-images/compose-smoke.yml down -v
```

## 5. SeaTunnel : l'image officielle tourne

```bash
docker run --rm apache/seatunnel:3.0.0 sh -c 'pwd; ls; ls connectors; cat config/plugin_config | head -30'
docker run --rm apache/seatunnel:3.0.0 ./bin/seatunnel.sh -m local -c config/v2.batch.config.template
```

La première commande montre le dossier de travail (attendu : `/opt/seatunnel`), les connecteurs présents (attendu : seulement fake et console) et la forme du fichier `plugin_config` d'origine.
La seconde lance le job d'exemple fourni : des lignes inventées s'affichent dans la console, puis un tableau de statistiques. C'est la preuve que le moteur Zeta fonctionne en mode local sur ta machine.

## 6. Construire l'image SeaTunnel de la démo

```bash
docker build -t expose/seatunnel:3.0.0 seatunnel/
```

Le build télécharge les connecteurs et le pilote PostgreSQL (plus besoin de le récupérer à la main) : quelques minutes. Lis `seatunnel/Dockerfile` pendant ce temps. Puis vérifie :

```bash
docker run --rm expose/seatunnel:3.0.0 sh -c 'ls connectors; ls lib | grep -i postgres'
```

Attendu : `connector-kafka-3.0.0.jar` et `connector-jdbc-3.0.0.jar` dans la première liste, `postgresql-42.7.5.jar` dans la seconde.

Si le build échoue, copie les 30 dernières lignes. Deux causes probables : la forme de `plugin_config` a changé en 3.0.0 (compare avec ce que l'étape 5 a affiché), ou le script attend d'autres arguments.

## Ce que tu rapportes

| Point | Observé |
|---|---|
| Architecture des 5 images | arm64 pour les cinq (9 oct.) |
| `data_directory` de PostgreSQL 18.6 | |
| `debezium-connector-postgres` présent | |
| Kafbat UI : cluster en ligne, message produit et relu | |
| Dossier de travail de SeaTunnel, connecteurs d'origine | |
| Job d'exemple SeaTunnel terminé | |
| Image `expose/seatunnel:3.0.0` : connecteurs et jar présents | |

## Ce que cette séance ne peut pas lever

Quatre points de la liste « À tester au montage » demandent un pipeline en marche et se lèvent plus tard :
les noms `KAFKA_DEFAULT_REPLICATION_FACTOR` et `KAFKA_MIN_INSYNC_REPLICAS` (séance 5), la forme du sink et son comportement sur un update (séance 4), le bloc `schema` de la source (séance 4), la reprise par les offsets du groupe (séance 4).
