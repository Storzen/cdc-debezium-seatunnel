# Antisèche de la démo (à garder ouverte)

## Avant de monter (10 min avant)

1. `./scripts/up.sh` : remise à zéro, environ 3 min.
2. `./scripts/check.sh` : tout doit être vert. Note le délai mesuré : c'est le « within seconds ».
3. Écran : **à gauche**, un terminal pour les scènes ; **à droite**, `./scripts/watch.sh catalog`. Kafbat UI ouvert dans un onglet : http://localhost:8080 → Topics → `registre.public.plots` → Messages.
4. Clips de secours ouverts dans QuickTime, le PDF des slides ouvert.

## Pendant la démo (5 min 30)

| Scène | Tu tapes | Ce que la salle voit | Ce que tu dis |
|---|---|---|---|
| a, 1 min 30 | `./scripts/scene-a-price.sh` | Le prix de TK-YDE-0003 passe de 21 000 000 à 18 500 000 dans le catalogue, à droite, en quelques secondes | « One UPDATE in the internal registry… and the public catalog follows. Nobody copied anything. » |
| b, 1 min 15 | `./scripts/scene-b-event.sh`, puis Kafbat UI | L'événement : `op: "u"`, `before`, `after` | « This is what Debezium wrote into Kafka: the operation, the row before, the row after. Notice: no owner name in the catalog, SeaTunnel dropped it. » |
| c, 1 min 15 | `./scripts/scene-c-delete.sh` | TK-DLA-0002 disparaît du catalogue | « A batch query could never see this. The row is gone, but its DELETE event still reached the catalog. » **Sommet de l'exposé : marque un temps.** |
| d, 1 min 30, facultative (seulement si l'horloge est sous 15:30) | `./scripts/scene-d-broker.sh` | Un broker s'arrête ; un nouveau terrain arrive quand même dans le catalogue | « We stop one of our three Kafka servers. Two copies are enough: the stream keeps flowing. » |

**Règle de bascule :** si une scène n'a rien montré après 30 s, ta camarade dit « Let's look at the recording » et tu lances le clip de cette scène.

## Ce que fait chaque maillon, en une phrase

- **PostgreSQL source** (`wal_level=logical`) : écrit chaque changement dans son journal (WAL) avant de toucher la table. `REPLICA IDENTITY FULL` : le journal garde la ligne entière d'avant, ce dont le DELETE a besoin.
- **Debezium** (connecteur dans Kafka Connect) : lit ce journal par un *slot de réplication* (un marque-page côté serveur), via le plugin `pgoutput` et la *publication* `dbz_plots` (la liste des tables suivies). Au démarrage, il fait un *snapshot* des lignes existantes (`op: r`), puis émet chaque changement.
- **Kafka** (3 nœuds KRaft, chacun broker et controller) : stocke les événements dans le topic `registre.public.plots`, en 3 copies. `min.insync.replicas=2` : une écriture n'est validée que si 2 copies l'ont reçue, donc un nœud peut tomber.
- **SeaTunnel** (moteur Zeta, mode local) : source Kafka au format `debezium_json` → `FieldMapper` (garde seulement les colonnes publiques) → sink JDBC en *upsert*/*delete* par clé primaire. Rejouer un événement ne change rien (idempotence).
- **PostgreSQL cible** : la table `catalog` ; un trigger note `synced_at`, d'où la mesure du délai (`synced_at - source_updated_at`).

## Questions probables du prof (réponses d'Ange)

- **Pourquoi Kafka entre les deux ?** Pour découpler : Debezium capte une seule fois, et plusieurs lecteurs (catalogue, moteur de recherche, statistiques) lisent les mêmes changements, chacun à son rythme, avec la possibilité de relire. Avec une seule cible, SeaTunnel seul suffirait : il a sa propre source Postgres-CDC (slide 11).
- **Et Spark ou Flink ?** Flink CDC est l'alternative la plus proche : il fait la capture et le traitement dans un même moteur, mais au prix d'un cluster Flink à opérer. Spark Structured Streaming lit Kafka mais ne capte pas lui-même le journal. Zeta, le moteur de SeaTunnel, est plus léger et pensé pour la synchronisation, pas pour le calcul.
- **Que se passe-t-il si SeaTunnel tombe ?** Les événements restent dans Kafka. Au redémarrage, le job relit depuis les offsets de son groupe de consommateurs, et l'upsert par clé absorbe les doublons.
- **Si Debezium tombe ?** Le slot de réplication retient le WAL non lu. Debezium reprend à son dernier LSN confirmé, stocké dans le topic `connect_offsets`. Le revers : un slot abandonné fait grossir le disque de la source, donc il faut le surveiller.
- **Exactly-once ?** Nous sommes en *at-least-once* (au moins une fois), rendu sûr par l'idempotence de l'upsert par clé.
- **Ordre des événements ?** Un topic à 1 partition : l'ordre est garanti. Avec plusieurs partitions, il l'est par clé (même terrain → même partition).
- **Pourquoi pas des triggers ou une double écriture dans l'application ?** Les triggers alourdissent chaque transaction de la source. La double écriture laisse deux systèmes incohérents si l'une des deux échoue. Le journal, lui, est déjà écrit et fait foi.

## En cas de panne

- Un conteneur ne démarre pas : `docker compose logs --tail 50 <service>`.
- Le catalogue ne suit plus : `docker compose --profile deliver logs --tail 50 seatunnel`.
- Tout est cassé, plus de 3 min avant le passage : `./scripts/up.sh`. Sinon, les clips.
