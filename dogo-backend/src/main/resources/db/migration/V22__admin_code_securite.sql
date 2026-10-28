-- V22 : Code de sécurité à 4 chiffres pour validation des actions administrateur
ALTER TABLE administrateur
    ADD COLUMN code_securite_hash VARCHAR(100) NULL,
    ADD COLUMN code_securite_date TIMESTAMP NULL;

