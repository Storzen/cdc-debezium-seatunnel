# Image SeaTunnel de la démo : l'image officielle ne contient que les
# connecteurs Fake et Console. On ajoute Kafka (source), JDBC (sink)
# et le pilote PostgreSQL, une fois pour toutes, au moment du build.
FROM apache/seatunnel:3.0.0

# Liste des connecteurs à installer (lue par install-plugin.sh)
COPY plugin_config config/plugin_config

# Télécharge les connecteurs listés dans connectors/ (réseau requis au build)
RUN sh bin/install-plugin.sh 3.0.0

# Pilote JDBC PostgreSQL, version figée, téléchargé depuis Maven Central au build
# (rien à télécharger à la main : même commande sur Mac et sous Windows)
ADD https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.5/postgresql-42.7.5.jar lib/
