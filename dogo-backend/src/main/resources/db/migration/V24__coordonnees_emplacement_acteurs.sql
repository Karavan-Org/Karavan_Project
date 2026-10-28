-- Migration V24 : Coordonnées géographiques et quartier/adresse pour Commerçant, Grossiste et Courtier
-- Permet de configurer le nom de la structure et l'emplacement par carte ou coordonnées dans les paramètres.

ALTER TABLE commercant
    ADD COLUMN latitude DOUBLE NULL,
    ADD COLUMN longitude DOUBLE NULL;

ALTER TABLE grossiste
    ADD COLUMN latitude DOUBLE NULL,
    ADD COLUMN longitude DOUBLE NULL,
    ADD COLUMN quartier_marche VARCHAR(120) NULL;

ALTER TABLE courtier
    ADD COLUMN latitude DOUBLE NULL,
    ADD COLUMN longitude DOUBLE NULL;
