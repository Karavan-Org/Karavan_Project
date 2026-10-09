-- Étapes d'acheminement signalées par le grossiste qui porte lui-même un groupe (suivi du colis).
-- Chaque signalement notifie les administrateurs, qui mettent à jour le suivi officiel vu par les commerçants.
CREATE TABLE etape_acheminement (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    groupe_id     BIGINT        NOT NULL,
    etape         VARCHAR(80)   NOT NULL,
    commentaire   VARCHAR(500)  NULL,
    date_signalee DATETIME(3)   NOT NULL,
    auteur_id     BIGINT        NOT NULL,
    CONSTRAINT fk_etape_groupe FOREIGN KEY (groupe_id) REFERENCES groupe_achat (id),
    INDEX idx_etape_groupe (groupe_id, date_signalee)
) ENGINE = InnoDB;
