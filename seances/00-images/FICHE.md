# Séance zéro : les images démarrent-elles sur la machine ?

**Terminée le 9 octobre 2026 sur le Mac : aucun repli nécessaire.**

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

## 2. PostgreSQL démarre, et où range-t-il ses données ? ✅ (9 octobre 2026)

```bash
docker run --rm -d --name pg-test -e POSTGRES_PASSWORD=test postgres:18.6
sleep 5
docker exec pg-test psql -U postgres -c "select version();" -c "show data_directory;" -c "show wal_level;"
docker rm -f pg-test
```

Note le `data_directory` (il décidera du chemin du volume à la séance 1) et le `wal_level` par défaut (on le changera à la séance 1).

Résultat : PostgreSQL 18.6 sur `aarch64`, `data_directory = /var/lib/postgresql/18/docker`, `wal_level = replica`.
Conséquence pour la séance 1 : depuis la version 18, l'image range les données dans un sous-dossier par version majeure.
Le volume se monte donc sur `/var/lib/postgresql` (et non plus `/var/lib/postgresql/data` comme dans les anciens tutoriels).

## 3. Debezium : le connecteur PostgreSQL est-il dans l'image ? ✅ (9 octobre 2026)

```bash
docker run --rm --entrypoint ls quay.io/debezium/connect:3.7.0.Final /kafka/connect
```

Attendu : une liste de dossiers dont `debezium-connector-postgres`.

Résultat : `debezium-connector-postgres` présent, parmi 13 connecteurs (cockroachdb, db2, ibmi, informix, jdbc, mariadb, mongodb, mysql, oracle, postgres, spanner, sqlserver, vitess).
Une seule image sert donc toutes les bases ; le connecteur effectivement utilisé est choisi par la propriété `connector.class` de la configuration enregistrée à la séance 3.

## 4. Kafka à 1 nœud et l'interface web ✅ (9 octobre 2026)

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

Résultat : cluster `smoke` en ligne, 1 broker ; topic `test` créé ; message (clé `City`, valeur `"Yaoundé"`) produit puis relu à l'offset 0 de la partition 0.
Kafbat UI v1.5.0 est retenu, pas de repli vers Redpanda Console.
Réserve d'affichage : la colonne Version du tableau de bord indique « Unknown » au lieu de 4.3.1 (sans effet sur le fonctionnement ; réponse prête si la question vient pendant la démo).

Puis on éteint :

```bash
docker compose -f seances/00-images/compose-smoke.yml down -v
```

## 5. SeaTunnel : l'image officielle tourne ✅ (9 octobre 2026)

```bash
docker run --rm apache/seatunnel:3.0.0 sh -c 'pwd; ls; ls connectors; cat config/plugin_config | head -30'
docker run --rm apache/seatunnel:3.0.0 ./bin/seatunnel.sh -m local -c config/v2.batch.config.template
```

La première commande montre le dossier de travail (attendu : `/opt/seatunnel`), les connecteurs présents (attendu : seulement fake et console) et la forme du fichier `plugin_config` d'origine.
La seconde lance le job d'exemple fourni : des lignes inventées s'affichent dans la console, puis un tableau de statistiques. C'est la preuve que le moteur Zeta fonctionne en mode local sur ta machine.

Résultat :
- Dossier de travail `/opt/seatunnel`.
- **Écart avec la recherche** : l'image 3.0.0 n'embarque pas seulement fake et console, mais environ 120 connecteurs, dont `connector-kafka-3.0.0.jar`, `connector-jdbc-3.0.0.jar` et `connector-cdc-postgres-3.0.0.jar`. L'étape `install-plugin.sh` du Dockerfile devient inutile (voir étape 6).
- Job d'exemple (FakeSource → Console) terminé à l'état `FINISHED` en 2 s : 32 lignes lues, 32 écrites, 0 échec. Zeta tourne en mode local sur le Mac.
- Au passage, les logs montrent que Zeta repose sur Hazelcast (grille de données en mémoire) et ouvre une API REST sur le port 8080 du conteneur.

## 6. Construire l'image SeaTunnel de la démo ✅ (9 octobre 2026)

Constat de l'étape 5 et de `ls lib` : l'image officielle a déjà les connecteurs Kafka et JDBC, et un pilote `postgresql-42.4.3.jar`.
Ce pilote date de 2022 et est touché par la CVE-2024-1597 (injection SQL, seulement en mode `preferQueryMode=simple`, que nous n'utilisons pas).
Le Dockerfile se réduit donc à une seule opération : remplacer ce pilote par `postgresql-42.7.5.jar`, figé.

```bash
docker build -t expose/seatunnel:3.0.0 seatunnel/
docker run --rm expose/seatunnel:3.0.0 sh -c 'ls lib | grep -i postgres'
```

Attendu : une seule ligne, `postgresql-42.7.5.jar`. Le build ne télécharge qu'un fichier d'environ 1 Mo : quelques secondes.

Résultat : build en 2,4 s, `lib/` ne contient plus que `postgresql-42.7.5.jar`.

Repli si le sink JDBC pose problème avec ce pilote à la séance 4 : utiliser directement `apache/seatunnel:3.0.0` (pilote d'origine), en le disant à l'oral.

## Ce que tu rapportes

| Point | Observé |
|---|---|
| Architecture des 5 images | arm64 pour les cinq (9 oct.) |
| `data_directory` de PostgreSQL 18.6 | `/var/lib/postgresql/18/docker` ; `wal_level` par défaut `replica` |
| `debezium-connector-postgres` présent | oui (13 connecteurs dans `/kafka/connect`) |
| Kafbat UI : cluster en ligne, message produit et relu | oui ; version affichée « Unknown » |
| Dossier de travail de SeaTunnel, connecteurs d'origine | `/opt/seatunnel` ; ~120 connecteurs dont kafka, jdbc, cdc-postgres |
| Job d'exemple SeaTunnel terminé | oui, FINISHED, 32 lues / 32 écrites / 0 échec |
| Image `expose/seatunnel:3.0.0` : pilote 42.7.5 seul présent | oui |

## Ce que cette séance ne peut pas lever

Quatre points de la liste « À tester au montage » demandent un pipeline en marche et se lèvent plus tard :
les noms `KAFKA_DEFAULT_REPLICATION_FACTOR` et `KAFKA_MIN_INSYNC_REPLICAS` (séance 5), la forme du sink et son comportement sur un update (séance 4), le bloc `schema` de la source (séance 4), la reprise par les offsets du groupe (séance 4).
