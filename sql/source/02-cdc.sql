-- Ce que PostgreSQL note de l'ancienne version d'une ligne : toutes les colonnes.
-- Nécessaire au sink JDBC de SeaTunnel, qui refuse un DELETE dont « before » est vide.
ALTER TABLE plots REPLICA IDENTITY FULL;
