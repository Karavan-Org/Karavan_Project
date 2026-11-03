-- Rollback de la migration V28__qr_retrait_et_colis.sql

DROP TABLE IF EXISTS qr_colis;

ALTER TABLE code_retrait DROP INDEX idx_code_retrait_token_hash;
ALTER TABLE code_retrait DROP INDEX idx_code_retrait_code_court_hash;

ALTER TABLE code_retrait DROP COLUMN valide_par_id;
ALTER TABLE code_retrait DROP COLUMN date_utilisation;
ALTER TABLE code_retrait DROP COLUMN statut;
ALTER TABLE code_retrait DROP COLUMN code_court_hash;
ALTER TABLE code_retrait DROP COLUMN token_hash;

DELETE FROM flyway_schema_history WHERE version = '28';
