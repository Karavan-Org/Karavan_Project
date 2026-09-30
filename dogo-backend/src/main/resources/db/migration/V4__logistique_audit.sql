-- Retrait (module logistique) et transversal (audit, notifications).
-- Les convois, expéditions, colis et douane viendront dans une migration ultérieure.

CREATE TABLE point_retrait (
    id        BIGINT AUTO_INCREMENT PRIMARY KEY,
    nom       VARCHAR(120) NOT NULL,
    adresse   VARCHAR(255) NOT NULL,
    quartier  VARCHAR(80)
) ENGINE = InnoDB;

-- RG-44 : une commande par participation confirmée.
CREATE TABLE commande (
    id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    participation_id  BIGINT      NOT NULL,
    groupe_id         BIGINT      NOT NULL,
    commercant_id     BIGINT      NOT NULL,
    point_retrait_id  BIGINT      NULL,
    quantite          INT         NOT NULL,
    statut            VARCHAR(30) NOT NULL DEFAULT 'CREEE',
    date_creation     DATETIME(3) NOT NULL,
    CONSTRAINT uq_commande_participation UNIQUE (participation_id),
    CONSTRAINT ck_commande_quantite CHECK (quantite > 0),
    CONSTRAINT ck_commande_statut CHECK (statut IN ('CREEE', 'PREPAREE', 'EXPEDIEE', 'ARRIVEE',
        'EN_ATTENTE_RETRAIT', 'COLLECTEE', 'ANNULEE')),
    CONSTRAINT fk_commande_participation FOREIGN KEY (participation_id) REFERENCES participation (id),
    CONSTRAINT fk_commande_groupe FOREIGN KEY (groupe_id) REFERENCES groupe_achat (id),
    CONSTRAINT fk_commande_commercant FOREIGN KEY (commercant_id) REFERENCES commercant (utilisateur_id),
    CONSTRAINT fk_commande_point FOREIGN KEY (point_retrait_id) REFERENCES point_retrait (id),
    INDEX idx_commande_groupe (groupe_id),
    INDEX idx_commande_commercant (commercant_id)
) ENGINE = InnoDB;

-- RG-53/54 : un code par commande, PIN haché, QR à jeton unique, expiration, tentatives, blocage.
CREATE TABLE code_retrait (
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    commande_id    BIGINT       NOT NULL,
    pin_hash       VARCHAR(100) NOT NULL,
    qr_token       VARCHAR(64)  NOT NULL,
    expiration     DATETIME(3)  NOT NULL,
    tentatives     INT          NOT NULL DEFAULT 0,
    utilise        BOOLEAN      NOT NULL DEFAULT FALSE,
    bloque         BOOLEAN      NOT NULL DEFAULT FALSE,
    date_creation  DATETIME(3)  NOT NULL,
    CONSTRAINT uq_code_commande UNIQUE (commande_id),
    CONSTRAINT uq_code_qr UNIQUE (qr_token),
    CONSTRAINT ck_code_tentatives CHECK (tentatives >= 0),
    CONSTRAINT fk_code_commande FOREIGN KEY (commande_id) REFERENCES commande (id)
) ENGINE = InnoDB;

-- RG-55 : preuve écrite dans la même transaction que la collecte.
CREATE TABLE preuve_retrait (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    commande_id   BIGINT      NOT NULL,
    type          VARCHAR(20) NOT NULL,
    fichier       VARCHAR(255),
    date_retrait  DATETIME(3) NOT NULL,
    CONSTRAINT uq_preuve_commande UNIQUE (commande_id),
    CONSTRAINT ck_preuve_type CHECK (type IN ('QR', 'PIN')),
    CONSTRAINT fk_preuve_commande FOREIGN KEY (commande_id) REFERENCES commande (id)
) ENGINE = InnoDB;

-- RG-66/67 : journal d'audit chaîné par hachage, en ajout seul.
CREATE TABLE journal_audit (
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    acteur_id      BIGINT       NULL,
    action         VARCHAR(80)  NOT NULL,
    avant          TEXT,
    apres          TEXT,
    date_audit     DATETIME(3)  NOT NULL,
    hash_precedent CHAR(64)     NOT NULL,
    hash           CHAR(64)     NOT NULL,
    CONSTRAINT uq_audit_hash UNIQUE (hash),
    INDEX idx_audit_acteur (acteur_id, date_audit)
) ENGINE = InnoDB;

-- Ligne unique qui porte le dernier hash : la verrouiller (SELECT ... FOR UPDATE) sérialise les écritures
-- jusqu'au COMMIT, donc la chaîne ne peut pas se scinder même avec plusieurs transactions simultanées.
CREATE TABLE journal_audit_tete (
    id            TINYINT PRIMARY KEY,
    dernier_hash  CHAR(64) NOT NULL,
    CONSTRAINT ck_audit_tete_id CHECK (id = 1)
) ENGINE = InnoDB;

INSERT INTO journal_audit_tete (id, dernier_hash) VALUES (1, REPEAT('0', 64));

CREATE TRIGGER trg_audit_no_update BEFORE UPDATE ON journal_audit FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RG-67 : le journal d''audit est en ajout seul';

CREATE TRIGGER trg_audit_no_delete BEFORE DELETE ON journal_audit FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RG-67 : le journal d''audit est en ajout seul';

-- RG-69/70 : notifications, avec compteur de tentatives d'envoi.
CREATE TABLE notification (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    utilisateur_id  BIGINT       NOT NULL,
    contenu         VARCHAR(500) NOT NULL,
    canal           VARCHAR(10)  NOT NULL DEFAULT 'SMS',
    statut          VARCHAR(10)  NOT NULL DEFAULT 'ENVOYEE',
    tentatives      INT          NOT NULL DEFAULT 1,
    date_creation   DATETIME(3)  NOT NULL,
    CONSTRAINT ck_notification_canal CHECK (canal IN ('SMS', 'PUSH')),
    CONSTRAINT ck_notification_statut CHECK (statut IN ('ENVOYEE', 'LUE', 'ECHOUEE')),
    CONSTRAINT fk_notification_utilisateur FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id),
    INDEX idx_notification_utilisateur (utilisateur_id, date_creation)
) ENGINE = InnoDB;
