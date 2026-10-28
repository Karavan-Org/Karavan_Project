-- Rollback V24 : Suppression des colonnes latitude, longitude et quartier_marche
ALTER TABLE commercant
    DROP COLUMN latitude,
    DROP COLUMN longitude;

ALTER TABLE grossiste
    DROP COLUMN latitude,
    DROP COLUMN longitude,
    DROP COLUMN quartier_marche;

ALTER TABLE courtier
    DROP COLUMN latitude,
    DROP COLUMN longitude;

DELETE FROM flyway_schema_history WHERE version = '24';
