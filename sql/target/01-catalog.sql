-- Catalogue public : seulement les colonnes publiques, écrites par SeaTunnel.
-- owner_name et floor_price_fcfa n'arrivent jamais ici (filtrés par FieldMapper).
CREATE TABLE catalog (
    id                integer PRIMARY KEY,
    reference         text    NOT NULL,
    city              text    NOT NULL,
    district          text    NOT NULL,
    area_m2           integer NOT NULL,
    price_fcfa        bigint  NOT NULL,
    has_land_title    boolean NOT NULL,
    status            text    NOT NULL,
    source_updated_at text,                          -- updated_at de la source (texte ISO de Debezium)
    synced_at         timestamptz NOT NULL DEFAULT now()  -- heure d'arrivée dans le catalogue
);

-- synced_at suit chaque écriture de SeaTunnel : synced_at - source_updated_at = délai de bout en bout.
CREATE FUNCTION touch_synced_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.synced_at := clock_timestamp();
    RETURN NEW;
END;
$$;

CREATE TRIGGER catalog_touch_synced_at
    BEFORE INSERT OR UPDATE ON catalog
    FOR EACH ROW EXECUTE FUNCTION touch_synced_at();
