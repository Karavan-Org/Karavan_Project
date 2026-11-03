-- V28 : Ajout des colonnes de sécurisation du code de retrait (hash, code court, statut, traçabilité)
-- et création de la table qr_colis pour la validation des arrivées d'expéditions.

-- 1. Extension de code_retrait
ALTER TABLE code_retrait
    ADD COLUMN token_hash VARCHAR(64) NULL AFTER qr_token,
    ADD COLUMN code_court_hash VARCHAR(64) NULL AFTER token_hash,
    ADD COLUMN statut VARCHAR(20) NOT NULL DEFAULT 'ACTIF' AFTER expiration,
    ADD COLUMN date_utilisation DATETIME(3) NULL AFTER date_creation,
    ADD COLUMN valide_par_id BIGINT NULL AFTER date_utilisation;

CREATE INDEX idx_code_retrait_token_hash ON code_retrait(token_hash);
CREATE INDEX idx_code_retrait_code_court_hash ON code_retrait(code_court_hash);

-- Migration des données existantes (rétro-compatibilité)
UPDATE code_retrait
SET token_hash = SHA2(qr_token, 256)
WHERE token_hash IS NULL AND qr_token IS NOT NULL;

UPDATE code_retrait
SET statut = CASE
    WHEN utilise = 1 THEN 'UTILISE'
    WHEN bloque = 1 THEN 'BLOQUE'
    WHEN expiration < NOW() THEN 'EXPIRE'
    ELSE 'ACTIF'
END;

-- 2. Création de la table qr_colis
CREATE TABLE IF NOT EXISTS qr_colis (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    expedition_id BIGINT NOT NULL,
    token_hash VARCHAR(64) NOT NULL,
    code_court_hash VARCHAR(64) NOT NULL,
    statut VARCHAR(20) NOT NULL DEFAULT 'ACTIF',
    expiration DATETIME(3) NOT NULL,
    date_creation DATETIME(3) NOT NULL,
    date_utilisation DATETIME(3) NULL,
    valide_par_id BIGINT NULL,
    tentatives INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_qr_colis_expedition FOREIGN KEY (expedition_id) REFERENCES expedition(id) ON DELETE CASCADE,
    CONSTRAINT uq_qr_colis_token_hash UNIQUE (token_hash),
    CONSTRAINT uq_qr_colis_code_court_hash UNIQUE (code_court_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_qr_colis_expedition_id ON qr_colis(expedition_id);
CREATE INDEX idx_qr_colis_statut ON qr_colis(statut);
