-- V12__refresh_token.sql : Table des jetons de rafraîchissement (rotation, détection de réutilisation, révocation)
CREATE TABLE refresh_token (
    id                   BIGINT AUTO_INCREMENT PRIMARY KEY,
    token_hash           VARCHAR(64)  NOT NULL,
    utilisateur_id       BIGINT       NOT NULL,
    session_id           BIGINT       NULL,
    device_id            VARCHAR(120),
    ip_creation          VARCHAR(45),
    date_expiration      DATETIME(3)  NOT NULL,
    revoque              BOOLEAN      NOT NULL DEFAULT FALSE,
    date_revocation      DATETIME(3)  NULL,
    remplace_par_hash    VARCHAR(64)  NULL,
    derniere_utilisation DATETIME(3)  NULL,
    date_creation        DATETIME(3)  NOT NULL,
    CONSTRAINT fk_refresh_token_utilisateur FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id) ON DELETE CASCADE,
    CONSTRAINT fk_refresh_token_session FOREIGN KEY (session_id) REFERENCES session_utilisateur (id) ON DELETE SET NULL,
    CONSTRAINT uq_refresh_token_hash UNIQUE (token_hash),
    INDEX idx_refresh_token_user (utilisateur_id),
    INDEX idx_refresh_token_expiration (date_expiration)
) ENGINE = InnoDB;

