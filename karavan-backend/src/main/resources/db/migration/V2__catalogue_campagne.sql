-- Modules catalogue et campagne.

CREATE TABLE categorie (
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    nom_categorie  VARCHAR(80)  NOT NULL,
    description    VARCHAR(255),
    active         BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_categorie_nom UNIQUE (nom_categorie)
) ENGINE = InnoDB;

-- RG-11 : un produit appartient à une catégorie et à un Grossiste.
CREATE TABLE produit (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    grossiste_id  BIGINT       NOT NULL,
    categorie_id  BIGINT       NOT NULL,
    nom_produit   VARCHAR(160) NOT NULL,
    description   TEXT,
    pays_origine  VARCHAR(60),
    CONSTRAINT fk_produit_grossiste FOREIGN KEY (grossiste_id) REFERENCES grossiste (utilisateur_id),
    CONSTRAINT fk_produit_categorie FOREIGN KEY (categorie_id) REFERENCES categorie (id),
    INDEX idx_produit_grossiste (grossiste_id)
) ENGINE = InnoDB;

-- RG-12 : SKU unique. RG-13 : stock jamais négatif.
CREATE TABLE variante_produit (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    produit_id      BIGINT       NOT NULL,
    sku             VARCHAR(60)  NOT NULL,
    taille          VARCHAR(20),
    couleur         VARCHAR(30),
    qte_disponible  INT          NOT NULL DEFAULT 0,
    CONSTRAINT uq_variante_sku UNIQUE (sku),
    CONSTRAINT ck_variante_stock CHECK (qte_disponible >= 0),
    CONSTRAINT fk_variante_produit FOREIGN KEY (produit_id) REFERENCES produit (id)
) ENGINE = InnoDB;

-- RG-17 : cible positive, date limite après ouverture.
-- RG-23 : quantité confirmée + réservée jamais supérieure à la cible (contrainte en base, doublée par un UPDATE conditionnel).
CREATE TABLE groupe_achat (
    id                    BIGINT AUTO_INCREMENT PRIMARY KEY,
    courtier_id           BIGINT        NOT NULL,
    grossiste_id          BIGINT        NOT NULL,
    produit_id            BIGINT        NOT NULL,
    quantite_cible        INT           NOT NULL,
    quantite_confirmee    INT           NOT NULL DEFAULT 0,
    quantite_reservee     INT           NOT NULL DEFAULT 0,
    prix_unitaire         DECIMAL(15, 2) NOT NULL,
    date_ouverture        DATETIME(3)   NOT NULL,
    date_limite           DATETIME(3)   NOT NULL,
    statut                VARCHAR(20)   NOT NULL DEFAULT 'BROUILLON',
    disponibilite_validee BOOLEAN       NOT NULL DEFAULT FALSE,
    version               BIGINT        NOT NULL DEFAULT 0,
    CONSTRAINT ck_groupe_cible CHECK (quantite_cible > 0),
    CONSTRAINT ck_groupe_quantites CHECK (quantite_confirmee >= 0 AND quantite_reservee >= 0
        AND quantite_confirmee + quantite_reservee <= quantite_cible),
    CONSTRAINT ck_groupe_dates CHECK (date_limite > date_ouverture),
    CONSTRAINT ck_groupe_prix CHECK (prix_unitaire > 0),
    CONSTRAINT ck_groupe_statut CHECK (statut IN ('BROUILLON', 'EN_VALIDATION', 'OUVERT', 'OBJECTIF_ATTEINT',
        'EN_EXPEDITION', 'LIVRE', 'TERMINE', 'ANNULE', 'ECHOUE')),
    CONSTRAINT fk_groupe_courtier FOREIGN KEY (courtier_id) REFERENCES courtier (utilisateur_id),
    CONSTRAINT fk_groupe_grossiste FOREIGN KEY (grossiste_id) REFERENCES grossiste (utilisateur_id),
    CONSTRAINT fk_groupe_produit FOREIGN KEY (produit_id) REFERENCES produit (id),
    INDEX idx_groupe_statut_limite (statut, date_limite)
) ENGINE = InnoDB;

-- RG-20 : une grille par groupe, figée à l'ouverture (l'application refuse toute modification après).
CREATE TABLE grille_tarifaire (
    id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    groupe_id         BIGINT         NOT NULL,
    prix_marchandise  DECIMAL(15, 2) NOT NULL,
    transport         DECIMAL(15, 2) NOT NULL,
    frais_plateforme  DECIMAL(15, 2) NOT NULL,
    douane            DECIMAL(15, 2) NOT NULL,
    autres            DECIMAL(15, 2) NOT NULL,
    devise            VARCHAR(3)     NOT NULL DEFAULT 'XOF',
    taux_commission   DECIMAL(5, 4)  NOT NULL,
    CONSTRAINT uq_grille_groupe UNIQUE (groupe_id),
    CONSTRAINT ck_grille_positive CHECK (prix_marchandise > 0 AND transport >= 0 AND frais_plateforme >= 0
        AND douane >= 0 AND autres >= 0),
    CONSTRAINT fk_grille_groupe FOREIGN KEY (groupe_id) REFERENCES groupe_achat (id)
) ENGINE = InnoDB;

CREATE TABLE condition_commerciale (
    id                          BIGINT AUTO_INCREMENT PRIMARY KEY,
    groupe_id                   BIGINT       NOT NULL,
    delai_livraison_jours       INT          NOT NULL,
    politique_annulation        VARCHAR(255),
    quantite_min_par_commercant INT          NOT NULL DEFAULT 1,
    CONSTRAINT uq_condition_groupe UNIQUE (groupe_id),
    CONSTRAINT ck_condition_min CHECK (quantite_min_par_commercant >= 1),
    CONSTRAINT fk_condition_groupe FOREIGN KEY (groupe_id) REFERENCES groupe_achat (id)
) ENGINE = InnoDB;

-- RG-19 : chaque changement de statut est historisé.
CREATE TABLE transition_statut_groupe (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    groupe_id       BIGINT       NOT NULL,
    ancien_statut   VARCHAR(20)  NOT NULL,
    nouveau_statut  VARCHAR(20)  NOT NULL,
    date_transition DATETIME(3)  NOT NULL,
    auteur          VARCHAR(80)  NOT NULL,
    CONSTRAINT fk_transition_groupe FOREIGN KEY (groupe_id) REFERENCES groupe_achat (id),
    INDEX idx_transition_groupe (groupe_id, date_transition)
) ENGINE = InnoDB;

CREATE TABLE validation_groupe (
    id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    groupe_id         BIGINT      NOT NULL,
    administrateur_id BIGINT      NOT NULL,
    decision          VARCHAR(20) NOT NULL,
    date_decision     DATETIME(3) NOT NULL,
    commentaire       VARCHAR(500),
    CONSTRAINT ck_vgroupe_decision CHECK (decision IN ('APPROUVE', 'REJETE')),
    CONSTRAINT fk_vgroupe_groupe FOREIGN KEY (groupe_id) REFERENCES groupe_achat (id),
    CONSTRAINT fk_vgroupe_admin FOREIGN KEY (administrateur_id) REFERENCES administrateur (utilisateur_id)
) ENGINE = InnoDB;
