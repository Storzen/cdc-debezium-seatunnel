# Image SeaTunnel de la démo.
#
# L'image officielle 3.0.0 contient déjà les connecteurs dont on a besoin
# (connector-kafka, connector-jdbc) et un pilote PostgreSQL. Constat de la séance zéro.
#
# Une seule modification : remplacer ce pilote, postgresql-42.4.3 (2022), touché par
# la CVE-2024-1597 (injection SQL en mode preferQueryMode=simple, corrigée en 42.4.4),
# par une version récente figée. On garde le même dossier lib/, lu par le moteur Zeta.
FROM apache/seatunnel:3.0.0

RUN rm lib/postgresql-42.4.3.jar
ADD https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.5/postgresql-42.7.5.jar lib/
