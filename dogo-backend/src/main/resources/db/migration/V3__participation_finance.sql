-- Modules participation et finance.

-- RG-26 : une seule participation active par commerçant, groupe et variante (clé générée nulle quand inactive).
CREATE TABLE participation (
    id                          BIGINT AUTO_INCREMENT PRIMARY KEY,
    groupe_id                   BIGINT      NOT NULL,
    commercant_id               BIGINT      NOT NULL,
    variante_id                 BIGINT      NOT NULL,
    quantite_demandee           INT         NOT NULL,
    statut                      VARCHAR(20) NOT NULL DEFAULT 'DEMANDEE',
    date_creation               DATETIME(3) NOT NULL,
    date_expiration_reservation DATETIME(3) NULL,
    cle_active VARCHAR(70) GENERATED ALWAYS AS (
        IF(statut IN ('DEMANDEE', 'RESERVEE', 'CONFIRMEE'), CONCAT(groupe_id, '-', commercant_id, '-', variante_id), NULL)
    ) STORED,
    CONSTRAINT uq_participation_active UNIQUE (cle_active),
    CONSTRAINT ck_participation_qte CHECK (quantite_demandee > 0),
    CONSTRAINT ck_participation_statut CHECK (statut IN ('DEMANDEE', 'RESERVEE', 'CONFIRMEE', 'ANNULEE', 'EXPIREE')),
    CONSTRAINT fk_participation_groupe FOREIGN KEY (groupe_id) REFERENCES groupe_achat (id),
    CONSTRAINT fk_participation_commercant FOREIGN KEY (commercant_id) REFERENCES commercant (utilisateur_id),
    CONSTRAINT fk_participation_variante FOREIGN KEY (variante_id) REFERENCES variante_produit (id),
    INDEX idx_participation_groupe (groupe_id, statut),
    INDEX idx_participation_expiration (statut, date_expiration_reservation)
) ENGINE = InnoDB;

-- RG-29 : prix, produit et cible figés à la réservation.
CREATE TABLE snapshot_groupe (
    id                    BIGINT AUTO_INCREMENT PRIMARY KEY,
    participation_id      BIGINT         NOT NULL,
    produit_fige          VARCHAR(255)   NOT NULL,
    prix_fige             DECIMAL(15, 2) NOT NULL,
    frais_unitaire_fige   DECIMAL(15, 2) NOT NULL,
    quantite_cible_figee  INT            NOT NULL,
    date_fige             DATETIME(3)    NOT NULL,
    CONSTRAINT uq_snapshot_participation UNIQUE (participation_id),
    CONSTRAINT ck_snapshot_prix CHECK (prix_fige > 0 AND frais_unitaire_fige >= 0),
    CONSTRAINT fk_snapshot_participation FOREIGN KEY (participation_id) REFERENCES participation (id)
) ENGINE = InnoDB;

-- RG-32 : chaque changement de statut crée une ligne d'historique.
CREATE TABLE historique_participation (
    id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    participation_id  BIGINT      NOT NULL,
    ancien_statut     VARCHAR(20),
    nouveau_statut    VARCHAR(20) NOT NULL,
    date_evenement    DATETIME(3) NOT NULL,
    CONSTRAINT fk_historique_participation FOREIGN KEY (participation_id) REFERENCES participation (id),
    INDEX idx_historique_participation (participation_id, date_evenement)
) ENGINE = InnoDB;

-- RG-33/34 : montant positif, clé d'idempotence unique, un seul paiement « vivant » par participation.
CREATE TABLE paiement (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    participation_id    BIGINT         NOT NULL,
    moyen_paiement_id   BIGINT         NOT NULL,
    montant             DECIMAL(15, 2) NOT NULL,
    montant_rembourse   DECIMAL(15, 2) NOT NULL DEFAULT 0,
    statut              VARCHAR(20)    NOT NULL DEFAULT 'INITIE',
    cle_idempotence     VARCHAR(80)    NOT NULL,
    date_initiation     DATETIME(3)    NOT NULL,
    date_maj            DATETIME(3)    NOT NULL,
    cle_vivante BIGINT GENERATED ALWAYS AS (
        IF(statut IN ('INITIE', 'EN_ATTENTE', 'PAYE'), participation_id, NULL)
    ) STORED,
    CONSTRAINT uq_paiement_idempotence UNIQUE (cle_idempotence),
    CONSTRAINT uq_paiement_vivant UNIQUE (cle_vivante),
    CONSTRAINT ck_paiement_montant CHECK (montant > 0),
    CONSTRAINT ck_paiement_rembourse CHECK (montant_rembourse >= 0 AND montant_rembourse <= montant),
    CONSTRAINT ck_paiement_statut CHECK (statut IN ('INITIE', 'EN_ATTENTE', 'PAYE', 'ECHOUE', 'EXPIRE', 'REMBOURSE')),
    CONSTRAINT fk_paiement_participation FOREIGN KEY (participation_id) REFERENCES participation (id),
    CONSTRAINT fk_paiement_moyen FOREIGN KEY (moyen_paiement_id) REFERENCES moyen_paiement_utilisateur (id)
) ENGINE = InnoDB;

-- RG-35 : callback brut conservé ; l'identifiant opérateur unique rend un callback en double sans effet.
CREATE TABLE transaction_mobile_money (
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    paiement_id    BIGINT       NOT NULL,
    tx_id          VARCHAR(80)  NOT NULL,
    operateur      VARCHAR(20)  NOT NULL,
    callback_brut  TEXT,
    date_callback  DATETIME(3),
    CONSTRAINT uq_tx_id UNIQUE (tx_id),
    CONSTRAINT ck_tx_operateur CHECK (operateur IN ('ORANGE_MONEY', 'MOOV_MONEY', 'WAVE')),
    CONSTRAINT fk_tx_paiement FOREIGN KEY (paiement_id) REFERENCES paiement (id),
    INDEX idx_tx_paiement (paiement_id)
) ENGINE = InnoDB;

-- RG-36 : un séquestre par paiement ; RG-62 : gelé quand un litige est ouvert.
CREATE TABLE sequestre (
    id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    paiement_id       BIGINT         NOT NULL,
    montant_bloque    DECIMAL(15, 2) NOT NULL,
    statut            VARCHAR(20)    NOT NULL DEFAULT 'BLOQUE',
    gele              BOOLEAN        NOT NULL DEFAULT FALSE,
    date_blocage      DATETIME(3)    NOT NULL,
    date_liberation   DATETIME(3)    NULL,
    CONSTRAINT uq_sequestre_paiement UNIQUE (paiement_id),
    CONSTRAINT ck_sequestre_montant CHECK (montant_bloque > 0),
    CONSTRAINT ck_sequestre_statut CHECK (statut IN ('BLOQUE', 'LIBERE', 'RESTITUE')),
    CONSTRAINT ck_sequestre_date CHECK (statut = 'BLOQUE' OR date_liberation IS NOT NULL),
    CONSTRAINT fk_sequestre_paiement FOREIGN KEY (paiement_id) REFERENCES paiement (id)
) ENGINE = InnoDB;

-- RG-41 : le solde bloqué est intouchable, seul le disponible peut être retiré ; aucun solde négatif.
CREATE TABLE portefeuille (
    id                 BIGINT AUTO_INCREMENT PRIMARY KEY,
    courtier_id        BIGINT         NOT NULL,
    solde_bloque       DECIMAL(15, 2) NOT NULL DEFAULT 0,
    solde_disponible   DECIMAL(15, 2) NOT NULL DEFAULT 0,
    devise             VARCHAR(3)     NOT NULL DEFAULT 'XOF',
    CONSTRAINT uq_portefeuille_courtier UNIQUE (courtier_id),
    CONSTRAINT ck_portefeuille_soldes CHECK (solde_bloque >= 0 AND solde_disponible >= 0),
    CONSTRAINT fk_portefeuille_courtier FOREIGN KEY (courtier_id) REFERENCES courtier (utilisateur_id)
) ENGINE = InnoDB;

-- RG-40 : journal des mouvements en ajout seul (les déclencheurs ci-dessous interdisent UPDATE et DELETE).
CREATE TABLE mouvement_financier (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    paiement_id      BIGINT         NULL,
    portefeuille_id  BIGINT         NULL,
    type             VARCHAR(30)    NOT NULL,
    montant          DECIMAL(15, 2) NOT NULL,
    date_mouvement   DATETIME(3)    NOT NULL,
    reference        VARCHAR(100)   NOT NULL,
    CONSTRAINT uq_mouvement_reference UNIQUE (reference),
    CONSTRAINT ck_mouvement_montant CHECK (montant > 0),
    CONSTRAINT ck_mouvement_type CHECK (type IN ('DEBIT_COMMERCANT', 'BLOCAGE_SEQUESTRE', 'LIBERATION_SEQUESTRE',
        'FRAIS_PLATEFORME', 'REMBOURSEMENT', 'RETRAIT_COURTIER')),
    CONSTRAINT fk_mouvement_paiement FOREIGN KEY (paiement_id) REFERENCES paiement (id),
    CONSTRAINT fk_mouvement_portefeuille FOREIGN KEY (portefeuille_id) REFERENCES portefeuille (id),
    INDEX idx_mouvement_paiement (paiement_id)
) ENGINE = InnoDB;

CREATE TRIGGER trg_mouvement_no_update BEFORE UPDATE ON mouvement_financier FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RG-40 : un mouvement financier est immuable';

CREATE TRIGGER trg_mouvement_no_delete BEFORE DELETE ON mouvement_financier FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RG-40 : un mouvement financier ne peut pas être supprimé';

-- RG-37 : frais prélevés à la libération du séquestre.
CREATE TABLE frais_plateforme (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    paiement_id      BIGINT         NOT NULL,
    montant          DECIMAL(15, 2) NOT NULL,
    taux_commission  DECIMAL(5, 4)  NOT NULL,
    date_prelevement DATETIME(3)    NOT NULL,
    CONSTRAINT uq_frais_paiement UNIQUE (paiement_id),
    CONSTRAINT ck_frais_montant CHECK (montant >= 0),
    CONSTRAINT fk_frais_paiement FOREIGN KEY (paiement_id) REFERENCES paiement (id)
) ENGINE = InnoDB;

CREATE TABLE remboursement (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    paiement_id   BIGINT         NOT NULL,
    montant       DECIMAL(15, 2) NOT NULL,
    statut        VARCHAR(20)    NOT NULL DEFAULT 'DEMANDE',
    motif         VARCHAR(30)    NOT NULL,
    approuve_par  BIGINT         NULL,
    date_demande  DATETIME(3)    NOT NULL,
    date_maj      DATETIME(3)    NOT NULL,
    CONSTRAINT ck_remboursement_montant CHECK (montant > 0),
    CONSTRAINT ck_remboursement_statut CHECK (statut IN ('DEMANDE', 'APPROUVE', 'REJETE', 'EXECUTE')),
    CONSTRAINT ck_remboursement_motif CHECK (motif IN ('ANNULATION_CLIENT', 'ECHEC_GROUPE', 'ECHEC_FOURNISSEUR',
        'COLIS_PERDU', 'LITIGE_RESOLU')),
    CONSTRAINT fk_remboursement_paiement FOREIGN KEY (paiement_id) REFERENCES paiement (id),
    INDEX idx_remboursement_paiement (paiement_id)
) ENGINE = InnoDB;
