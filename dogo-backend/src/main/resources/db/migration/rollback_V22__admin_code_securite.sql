-- Rollback V22 : Suppression des colonnes de code de sécurité administrateur
ALTER TABLE administrateur
    DROP COLUMN code_securite_hash,
    DROP COLUMN code_securite_date;

