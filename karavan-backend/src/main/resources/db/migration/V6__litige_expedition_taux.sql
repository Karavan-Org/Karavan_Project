-- Tables litiges, expéditions et taux de change

CREATE TABLE IF NOT EXISTS litige (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    commande_id BIGINT NOT NULL,
    motif VARCHAR(1000) NOT NULL,
    statut VARCHAR(30) NOT NULL,
    date_ouverture DATETIME(3) NOT NULL,
    date_resolution DATETIME(3),
    CONSTRAINT fk_litige_commande FOREIGN KEY (commande_id) REFERENCES commande(id)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS preuve_litige (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    litige_id BIGINT NOT NULL,
    type VARCHAR(50) NOT NULL,
    fichier VARCHAR(255) NOT NULL,
    date DATETIME(3) NOT NULL,
    CONSTRAINT fk_preuve_litige FOREIGN KEY (litige_id) REFERENCES litige(id)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS expedition (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    groupe_id BIGINT,
    reference VARCHAR(60) NOT NULL UNIQUE,
    statut VARCHAR(30) NOT NULL,
    date_depart DATETIME(3),
    transporteur VARCHAR(100),
    CONSTRAINT fk_expedition_groupe FOREIGN KEY (groupe_id) REFERENCES groupe_achat(id)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS evenement_logistique (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    expedition_id BIGINT,
    statut VARCHAR(50) NOT NULL,
    date DATETIME(3) NOT NULL,
    localisation VARCHAR(100) NOT NULL,
    CONSTRAINT fk_evenement_expedition FOREIGN KEY (expedition_id) REFERENCES expedition(id)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS taux_de_change (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    devise_source VARCHAR(10) NOT NULL,
    devise_cible VARCHAR(10) NOT NULL,
    taux DECIMAL(12, 4) NOT NULL,
    date_mise_a_jour DATETIME(3) NOT NULL
) ENGINE = InnoDB;

INSERT INTO taux_de_change (devise_source, devise_cible, taux, date_mise_a_jour) VALUES
('CNY', 'XOF', 85.5000, NOW(3)),
('USD', 'XOF', 610.0000, NOW(3)),
('EUR', 'XOF', 655.9570, NOW(3));
