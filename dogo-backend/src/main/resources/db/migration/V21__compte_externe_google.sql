-- Migration V21 : Fédération d'identité OAuth2 Google et table compte_externe
-- Permet la connexion et inscription via Google tout en préservant le numéro de téléphone malien (+223).

-- 1. Ajout de la colonne email et assouplissement de mot_de_passe_hash pour les comptes externes sans mot de passe
ALTER TABLE utilisateur
    ADD COLUMN email VARCHAR(255) NULL AFTER nom,
    MODIFY COLUMN mot_de_passe_hash VARCHAR(255) NULL;

-- 2. Création de la table compte_externe
CREATE TABLE compte_externe (
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    fournisseur    VARCHAR(30)  NOT NULL,
    sub            VARCHAR(255) NOT NULL,
    utilisateur_id BIGINT       NOT NULL,
    email          VARCHAR(255) NULL,
    cree_le        DATETIME(3)  NOT NULL,
    CONSTRAINT uq_compte_externe_fournisseur_sub UNIQUE (fournisseur, sub),
    CONSTRAINT fk_compte_externe_utilisateur FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- 3. Index de recherche rapide par utilisateur
CREATE INDEX idx_compte_externe_utilisateur ON compte_externe (utilisateur_id);

