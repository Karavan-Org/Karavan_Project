-- Module identité : rôles, permissions, comptes, OTP, sessions, moyens de paiement, KYC.
-- Convention : montants en XOF (DECIMAL 15,2), dates en UTC (DATETIME 3), statuts contraints par CHECK.

CREATE TABLE role (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    nom         VARCHAR(40)  NOT NULL,
    description VARCHAR(255),
    CONSTRAINT uq_role_nom UNIQUE (nom)
) ENGINE = InnoDB;

CREATE TABLE permission (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    code        VARCHAR(60)  NOT NULL,
    description VARCHAR(255),
    CONSTRAINT uq_permission_code UNIQUE (code)
) ENGINE = InnoDB;

CREATE TABLE role_permission (
    role_id       BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES role (id),
    CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id) REFERENCES permission (id)
) ENGINE = InnoDB;

-- RG-01 : téléphone unique, statut initial EN_ATTENTE. RG-06 : un seul rôle par utilisateur.
CREATE TABLE utilisateur (
    id                 BIGINT AUTO_INCREMENT PRIMARY KEY,
    type_acteur        VARCHAR(20)  NOT NULL,
    telephone          VARCHAR(20)  NOT NULL,
    nom                VARCHAR(120) NOT NULL,
    pin_hash           VARCHAR(100) NOT NULL,
    langue             VARCHAR(5)   NOT NULL DEFAULT 'fr',
    statut_compte      VARCHAR(20)  NOT NULL DEFAULT 'EN_ATTENTE',
    telephone_verifie  BOOLEAN      NOT NULL DEFAULT FALSE,
    tentatives_pin     INT          NOT NULL DEFAULT 0,
    verrouille_jusqua  DATETIME(3)  NULL,
    role_id            BIGINT       NOT NULL,
    date_creation      DATETIME(3)  NOT NULL,
    CONSTRAINT uq_utilisateur_telephone UNIQUE (telephone),
    CONSTRAINT ck_utilisateur_type CHECK (type_acteur IN ('COMMERCANT', 'GROSSISTE', 'COURTIER', 'ADMINISTRATEUR')),
    CONSTRAINT ck_utilisateur_statut CHECK (statut_compte IN ('EN_ATTENTE', 'ACTIF', 'SUSPENDU', 'DESACTIVE')),
    CONSTRAINT ck_utilisateur_tentatives CHECK (tentatives_pin >= 0),
    CONSTRAINT fk_utilisateur_role FOREIGN KEY (role_id) REFERENCES role (id)
) ENGINE = InnoDB;

CREATE TABLE commercant (
    utilisateur_id    BIGINT PRIMARY KEY,
    nom_boutique      VARCHAR(120) NOT NULL,
    adresse_livraison VARCHAR(255),
    quartier_bamako   VARCHAR(80),
    canal_vente       VARCHAR(60),
    CONSTRAINT fk_commercant_utilisateur FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id)
) ENGINE = InnoDB;

CREATE TABLE grossiste (
    utilisateur_id       BIGINT PRIMARY KEY,
    nom_boutique_marche  VARCHAR(120) NOT NULL,
    numero_nif           VARCHAR(40),
    registre_commerce    VARCHAR(40),
    note_fiabilite       DECIMAL(3, 2) NOT NULL DEFAULT 0,
    CONSTRAINT ck_grossiste_note CHECK (note_fiabilite BETWEEN 0 AND 5),
    CONSTRAINT fk_grossiste_utilisateur FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id)
) ENGINE = InnoDB;

CREATE TABLE courtier (
    utilisateur_id     BIGINT PRIMARY KEY,
    nom_societe_import VARCHAR(120) NOT NULL,
    licence_transit    VARCHAR(60),
    adresse_depot      VARCHAR(255),
    note_fiabilite     DECIMAL(3, 2) NOT NULL DEFAULT 0,
    CONSTRAINT ck_courtier_note CHECK (note_fiabilite BETWEEN 0 AND 5),
    CONSTRAINT fk_courtier_utilisateur FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id)
) ENGINE = InnoDB;

CREATE TABLE administrateur (
    utilisateur_id     BIGINT PRIMARY KEY,
    matricule_agent    VARCHAR(40) NOT NULL,
    role_administratif VARCHAR(20) NOT NULL,
    CONSTRAINT uq_admin_matricule UNIQUE (matricule_agent),
    CONSTRAINT ck_admin_role CHECK (role_administratif IN ('VALIDATION', 'FINANCE', 'SUPPORT', 'TECHNIQUE')),
    CONSTRAINT fk_admin_utilisateur FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id)
) ENGINE = InnoDB;

-- RG-02 : code stocké haché (RG-71), expiration, tentatives limitées, usage unique.
CREATE TABLE code_otp (
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    utilisateur_id BIGINT       NOT NULL,
    code_hash      VARCHAR(100) NOT NULL,
    expiration     DATETIME(3)  NOT NULL,
    tentatives     INT          NOT NULL DEFAULT 0,
    utilise        BOOLEAN      NOT NULL DEFAULT FALSE,
    date_creation  DATETIME(3)  NOT NULL,
    CONSTRAINT ck_otp_tentatives CHECK (tentatives >= 0),
    CONSTRAINT fk_otp_utilisateur FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id),
    INDEX idx_otp_utilisateur (utilisateur_id, date_creation)
) ENGINE = InnoDB;

-- RG-08 : session liée à un appareil, expirant après inactivité, invalidable.
CREATE TABLE session_utilisateur (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    utilisateur_id      BIGINT       NOT NULL,
    device_id           VARCHAR(120),
    ip                  VARCHAR(45),
    empreinte           VARCHAR(120),
    date_creation       DATETIME(3)  NOT NULL,
    derniere_activite   DATETIME(3)  NOT NULL,
    date_expiration     DATETIME(3)  NOT NULL,
    invalidee           BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_session_utilisateur FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id),
    INDEX idx_session_utilisateur (utilisateur_id)
) ENGINE = InnoDB;

-- RG-10 : un seul moyen de paiement par défaut par utilisateur (colonne générée + unicité, les NULL se répètent librement).
CREATE TABLE moyen_paiement_utilisateur (
    id                    BIGINT AUTO_INCREMENT PRIMARY KEY,
    utilisateur_id        BIGINT      NOT NULL,
    numero_mobile_money   VARCHAR(20) NOT NULL,
    operateur             VARCHAR(20) NOT NULL,
    par_defaut            BOOLEAN     NOT NULL DEFAULT FALSE,
    cle_defaut            BIGINT GENERATED ALWAYS AS (IF(par_defaut, utilisateur_id, NULL)) STORED,
    CONSTRAINT ck_moyen_operateur CHECK (operateur IN ('ORANGE_MONEY', 'MOOV_MONEY', 'WAVE')),
    CONSTRAINT uq_moyen_defaut UNIQUE (cle_defaut),
    CONSTRAINT uq_moyen_numero UNIQUE (utilisateur_id, numero_mobile_money),
    CONSTRAINT fk_moyen_utilisateur FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id)
) ENGINE = InnoDB;

-- RG-03 à RG-05 : dossier KYC, documents avec empreinte SHA-256, décision d'un administrateur.
CREATE TABLE dossier_kyc (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    utilisateur_id   BIGINT       NOT NULL,
    statut           VARCHAR(20)  NOT NULL DEFAULT 'EN_ATTENTE',
    date_soumission  DATETIME(3)  NOT NULL,
    motif_rejet      VARCHAR(500),
    CONSTRAINT ck_kyc_statut CHECK (statut IN ('EN_ATTENTE', 'APPROUVE', 'REJETE')),
    CONSTRAINT ck_kyc_rejet CHECK (statut <> 'REJETE' OR motif_rejet IS NOT NULL),
    CONSTRAINT fk_kyc_utilisateur FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id),
    INDEX idx_kyc_statut (statut)
) ENGINE = InnoDB;

CREATE TABLE document_legal (
    id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    dossier_id        BIGINT       NOT NULL,
    type              VARCHAR(30)  NOT NULL,
    fichier           VARCHAR(255) NOT NULL,
    empreinte_sha256  CHAR(64)     NOT NULL,
    date_expiration   DATE,
    CONSTRAINT ck_document_type CHECK (type IN ('NIF', 'REGISTRE_COMMERCE', 'LICENCE_TRANSIT', 'PIECE_IDENTITE')),
    CONSTRAINT fk_document_dossier FOREIGN KEY (dossier_id) REFERENCES dossier_kyc (id)
) ENGINE = InnoDB;

CREATE TABLE validation_compte (
    id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    dossier_id        BIGINT      NOT NULL,
    administrateur_id BIGINT      NOT NULL,
    decision          VARCHAR(20) NOT NULL,
    date_decision     DATETIME(3) NOT NULL,
    commentaire       VARCHAR(500),
    CONSTRAINT ck_validation_decision CHECK (decision IN ('APPROUVE', 'REJETE')),
    CONSTRAINT fk_validation_dossier FOREIGN KEY (dossier_id) REFERENCES dossier_kyc (id),
    CONSTRAINT fk_validation_admin FOREIGN KEY (administrateur_id) REFERENCES administrateur (utilisateur_id)
) ENGINE = InnoDB;
