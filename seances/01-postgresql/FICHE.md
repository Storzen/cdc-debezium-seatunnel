# Séance 1 : ce que PostgreSQL écrit quand une ligne change

Durée : environ 2 heures. Toutes les commandes se lancent depuis la racine du dépôt.

**Méthode.** Avant chaque commande marquée 🔮, écris ta prédiction dans ta note Obsidian de la séance, *avant* d'exécuter. Ensuite, note ce que tu observes. C'est l'écart entre les deux qui t'apprend quelque chose : une prédiction fausse est un bon résultat.

**À lire (une seule page)** : [Logical Decoding Concepts](https://www.postgresql.org/docs/18/logicaldecoding-explanation.html), documentation PostgreSQL 18, les trois premières sous-parties (Logical Decoding, Replication Slots, Output Plugins). Environ 10 minutes, idéalement après l'étape 1.

## Les notions, depuis zéro

**Le WAL (Write-Ahead Log).** Avant de modifier une table sur le disque, PostgreSQL écrit le changement dans un journal, le WAL, rangé dans des fichiers de 16 Mo. Si le serveur s'arrête brutalement, il relit ce journal au redémarrage et refait ce qui manque. Le journal existe d'abord pour la fiabilité, pas pour le CDC.

**Le LSN (Log Sequence Number).** La position d'un octet dans le WAL, notée comme `0/1A2B3C4`. Elle ne fait qu'augmenter. Toute la chaîne CDC raisonne en LSN : « j'ai lu jusqu'ici ».

**`wal_level`.** Ce que PostgreSQL note dans le WAL. Avec `replica` (le défaut, vu en séance zéro), le journal permet de refaire une copie physique de la base, octet par octet. Avec `logical`, il contient en plus de quoi reconstituer chaque changement sous forme de lignes : quelle table, quelles colonnes, quelles valeurs.

**Le décodage logique et le plugin de sortie.** PostgreSQL lit son propre WAL et le traduit en changements lisibles. Le format de sortie dépend d'un plugin : `test_decoding` produit du texte (pratique pour apprendre), `pgoutput` produit du binaire (c'est celui qu'utilise Debezium, et celui de la réplication logique native de PostgreSQL).

**Le slot de réplication.** Un marque-page côté serveur, au nom d'un consommateur. Il retient la position jusqu'où ce consommateur a confirmé sa lecture, et il empêche PostgreSQL d'effacer le WAL que ce consommateur n'a pas encore lu. Debezium aura son propre slot.

**La publication.** La liste des tables dont un consommateur `pgoutput` a le droit de recevoir les changements. C'est elle qui limitera notre flux à la table `plots`.

**`REPLICA IDENTITY`.** Ce que PostgreSQL note de l'*ancienne* version d'une ligne quand elle est modifiée ou supprimée.

## 0. Préparation

```bash
cp .env.example .env      # puis remplace change-me par un mot de passe
docker compose up -d pg-source
docker compose ps         # attendu : pg-source "healthy" après quelques secondes
```

Pour ne pas retaper la commande psql (macOS, Linux) :

```bash
alias psrc='docker compose exec -T pg-source psql -U postgres -d registre'
```

`-T` désactive le terminal interactif : indispensable pour envoyer plusieurs requêtes d'un coup (blocs `<<'SQL'` plus bas).

Lis `compose.yaml` et `sql/source/01-schema.sql` : tu dois pouvoir dire à quoi sert chaque ligne. Questions à te poser : pourquoi `wal_level` est passé en `command` et pas en variable d'environnement ? Que se passe-t-il si on modifie `01-schema.sql` et qu'on relance `docker compose up` ?

## 1. Le décodage logique sans `wal_level=logical`

On lance un PostgreSQL jetable avec le réglage par défaut, et on lui demande quand même un slot logique.

🔮 Prédiction : la création du slot réussit-elle ? Si non, quel message ?

```bash
docker run --rm -d --name pg-replica -e POSTGRES_PASSWORD=test postgres:18.6
sleep 5
docker exec pg-replica psql -U postgres -c "select pg_create_logical_replication_slot('essai', 'test_decoding');"
docker rm -f pg-replica
```

Puis la même question à notre base :

```bash
psrc -c "show wal_level;"
```

## 2. Le WAL avance

```bash
psrc -c "select * from plots order by id;"
psrc -c "select pg_current_wal_lsn();"
```

🔮 Prédiction : après un simple `SELECT`, le LSN a-t-il bougé ?

```bash
psrc -c "select count(*) from plots;" -c "select pg_current_wal_lsn();"
```

🔮 Prédiction : après une baisse de prix, de combien d'octets le WAL avance-t-il (ordre de grandeur : 10, 100, 10 000) ?

```bash
psrc <<'SQL'
select pg_current_wal_lsn() as avant \gset
update plots set price_fcfa = price_fcfa - 500000 where reference = 'TK-YDE-0003';
select pg_wal_lsn_diff(pg_current_wal_lsn(), :'avant') as octets_ecrits;
SQL
```

Les fichiers eux-mêmes :

```bash
docker compose exec pg-source ls -lh /var/lib/postgresql/18/docker/pg_wal
```

## 3. Un slot, et ce qu'il voit

```bash
psrc -c "select * from pg_create_logical_replication_slot('lab', 'test_decoding');"
psrc -c "select slot_name, plugin, slot_type, active, restart_lsn, confirmed_flush_lsn from pg_replication_slots;"
```

🔮 Prédiction : les 5 parcelles insérées au démarrage apparaissent-elles dans le slot ?

```bash
psrc -c "select * from pg_logical_slot_peek_changes('lab', null, null, 'include-xids', '0', 'skip-empty-xacts', '1');"
```

Cette question deviendra centrale à la séance 3 : comment Debezium obtient-il les lignes qui existaient avant lui ?

## 4. INSERT, UPDATE, DELETE dans le journal

Trois changements, chacun dans sa propre transaction :

```bash
psrc <<'SQL'
insert into plots (reference, city, district, area_m2, price_fcfa, has_land_title, owner_name, floor_price_fcfa)
values ('TK-YDE-0004', 'Yaoundé', 'Ekounou', 350, 9000000, true, 'Bertrand Fouda', 8200000);
update plots set price_fcfa = 7500000 where reference = 'TK-YDE-0002';
delete from plots where reference = 'TK-DLA-0002';
SQL
```

🔮 Prédictions, avant de lire le slot :
- l'INSERT montre-t-il toutes les colonnes, y compris `owner_name` ?
- l'UPDATE montre-t-il l'ancien prix, le nouveau, ou les deux ?
- le DELETE montre-t-il toute la ligne supprimée, ou autre chose ?
- voit-on la modification de `updated_at` faite par le trigger ?

```bash
psrc -c "select data from pg_logical_slot_peek_changes('lab', null, null, 'include-xids', '0', 'skip-empty-xacts', '1');"
```

## 5. Lire sans consommer, lire en consommant

`peek` lit le slot sans le faire avancer ; `get` lit et confirme la lecture.

🔮 Prédiction : que renvoie un second `peek` ? Et un `peek` juste après un `get` ? Que devient `confirmed_flush_lsn` ?

```bash
psrc -c "select count(*) from pg_logical_slot_peek_changes('lab', null, null, 'skip-empty-xacts', '1');"
psrc -c "select count(*) from pg_logical_slot_peek_changes('lab', null, null, 'skip-empty-xacts', '1');"
psrc -c "select count(*) from pg_logical_slot_get_changes('lab', null, null, 'skip-empty-xacts', '1');"
psrc -c "select count(*) from pg_logical_slot_peek_changes('lab', null, null, 'skip-empty-xacts', '1');"
psrc -c "select slot_name, restart_lsn, confirmed_flush_lsn from pg_replication_slots;"
```

À relier plus tard aux offsets Kafka (séance 2) : même idée, un consommateur qui confirme sa position.

## 6. Une transaction annulée

🔮 Prédiction : l'INSERT annulé est-il écrit dans le WAL ? Apparaît-il dans le slot ?

```bash
psrc <<'SQL'
select pg_current_wal_lsn() as avant \gset
begin;
insert into plots (reference, city, district, area_m2, price_fcfa, has_land_title, owner_name, floor_price_fcfa)
values ('TK-YDE-9999', 'Yaoundé', 'Essos', 300, 6000000, false, 'Annulé', 5000000);
rollback;
select pg_wal_lsn_diff(pg_current_wal_lsn(), :'avant') as octets_ecrits;
select data from pg_logical_slot_peek_changes('lab', null, null, 'include-xids', '0', 'skip-empty-xacts', '1');
SQL
```

## 7. `REPLICA IDENTITY FULL`

```bash
psrc -c "alter table plots replica identity full;"
psrc <<'SQL'
update plots set status = 'reserved' where reference = 'TK-YDE-0001';
delete from plots where reference = 'TK-YDE-0004';
SQL
```

🔮 Prédiction : par rapport à l'étape 4, qu'est-ce qui change dans la sortie de l'UPDATE et du DELETE ?

```bash
psrc -c "select data from pg_logical_slot_get_changes('lab', null, null, 'include-xids', '0', 'skip-empty-xacts', '1');"
```

Question de fond : un consommateur qui doit supprimer la parcelle dans *un autre système*, qu'est-ce qui lui suffit ? Et un consommateur qui veut savoir *quel était le prix avant* la suppression ?

## 8. Le danger du slot oublié

On ne lit plus le slot `lab`, et on écrit beaucoup, dans une autre table.

🔮 Prédiction : la quantité de WAL retenue par `lab` augmente-t-elle, alors que la table `plots` n'a pas changé ?

```bash
psrc <<'SQL'
select slot_name, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) as wal_retenu from pg_replication_slots;
create table scratch as select g as n, md5(g::text) as h from generate_series(1, 200000) g;
select slot_name, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) as wal_retenu from pg_replication_slots;
drop table scratch;
SQL
```

Question de production : si Debezium est arrêté une semaine pendant que la base travaille, que devient le disque du serveur ? Quel réglage de PostgreSQL protège le disque (cherche `max_slot_wal_keep_size`), et quel prix cela fait-il payer au consommateur ?

## 9. La publication et `pgoutput`

```bash
psrc -c "create publication dbz_publication for table plots;"
psrc -c "\dRp+"
psrc -c "select * from pg_create_logical_replication_slot('lab_pgoutput', 'pgoutput');"
psrc -c "update plots set price_fcfa = price_fcfa + 100000 where reference = 'TK-DLA-0001';"
psrc -c "select data from pg_logical_slot_peek_binary_changes('lab_pgoutput', null, null, 'proto_version', '1', 'publication_names', 'dbz_publication');"
```

🔮 Avant la dernière commande : à quoi ressemblera la sortie de `pgoutput` ?

Ce que tu vois explique le rôle de Debezium : transformer ce flux binaire en événements JSON lisibles, et les publier dans Kafka.

## 10. Rangement

Les slots de test doivent disparaître : un slot oublié retient du WAL indéfiniment (étape 8).

```bash
psrc -c "select pg_drop_replication_slot('lab');" -c "select pg_drop_replication_slot('lab_pgoutput');"
psrc -c "drop publication dbz_publication;"
docker compose down -v
```

`down -v` efface le volume : à la séance 3, la base repartira d'un état propre, avec la publication, `REPLICA IDENTITY FULL` et l'utilisateur dédié à Debezium créés par un second script SQL, écrit à partir de tes observations.

## Explication en anglais (1 minute, sans notes)

Explique à voix haute, comme devant la classe : *what the WAL is, why `wal_level=logical` is needed, what a replication slot does, and why a forgotten slot is dangerous.* Enregistre-toi ou fais-le devant ta camarade.

## Ce que tu rapportes

| Étape | Observé |
|---|---|
| 1. Slot logique avec `wal_level=replica` | |
| 2. LSN après un SELECT ; octets écrits par un UPDATE | |
| 3. Les 5 parcelles initiales dans le slot ? | |
| 4. Contenu de l'INSERT, de l'UPDATE, du DELETE | |
| 5. peek / get / peek : nombres de lignes, `confirmed_flush_lsn` | |
| 6. Transaction annulée : octets écrits, présence dans le slot | |
| 7. Ce qui change avec `REPLICA IDENTITY FULL` | |
| 8. WAL retenu avant / après `scratch` | |
| 9. Allure de la sortie `pgoutput` | |
| Prédictions fausses (lesquelles) | |

Copie-colle les sorties brutes si c'est plus simple : je remplis la fiche et j'écris la section « À retenir » à partir de ce que tu as observé.

## À retenir

*Rédigé en fin de séance, à partir des observations.*
