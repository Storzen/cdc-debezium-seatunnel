-- Registre interne des terrains de l'agence. Données entièrement fictives.
-- Colonnes publiques : celles que le catalogue public recevra.
-- Colonnes internes : owner_name et floor_price_fcfa, filtrées par SeaTunnel (séance 4).

CREATE TABLE plots (
    id               integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reference        text        NOT NULL UNIQUE,           -- ex. TK-YDE-0001
    city             text        NOT NULL,
    district         text        NOT NULL,                  -- quartier
    area_m2          integer     NOT NULL CHECK (area_m2 > 0),
    price_fcfa       bigint      NOT NULL CHECK (price_fcfa > 0),
    has_land_title   boolean     NOT NULL,                  -- titre foncier établi
    status           text        NOT NULL DEFAULT 'available'
                                 CHECK (status IN ('available', 'reserved', 'sold')),
    owner_name       text        NOT NULL,                  -- interne
    floor_price_fcfa bigint      NOT NULL,                  -- interne : prix plancher de négociation
    updated_at       timestamptz NOT NULL DEFAULT now()
);

-- Types choisis pour le flux : entiers plutôt que numeric, car Debezium encode
-- numeric en binaire par défaut (illisible dans l'interface web).

-- updated_at suit chaque modification : il servira à mesurer le délai de bout en bout.
CREATE FUNCTION touch_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER plots_touch_updated_at
    BEFORE UPDATE ON plots
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

INSERT INTO plots (reference, city, district, area_m2, price_fcfa, has_land_title, owner_name, floor_price_fcfa) VALUES
    ('TK-YDE-0001', 'Yaoundé', 'Odza',         500, 12500000, true,  'Clarisse Ondoua',  11000000),
    ('TK-YDE-0002', 'Yaoundé', 'Nkolbisson',   400,  8000000, false, 'Hervé Mbarga',      7000000),
    ('TK-YDE-0003', 'Yaoundé', 'Mvan',         600, 21000000, true,  'Sandrine Abega',   19000000),
    ('TK-DLA-0001', 'Douala',  'Bonamoussadi', 450, 27000000, true,  'Patrick Ekwalla',  25000000),
    ('TK-DLA-0002', 'Douala',  'Logbessou',    800, 16000000, false, 'Mireille Ngo Bassa', 14500000);
