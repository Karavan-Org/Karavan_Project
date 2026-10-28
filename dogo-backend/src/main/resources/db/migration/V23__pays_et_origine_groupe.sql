-- Migration V23 : Table de référence des pays et pays d'origine d'un groupe d'achat
-- Conforme à la mission Tableau de bord administrateur (Globe 3D et Cadran des groupes).

CREATE TABLE pays (
    code_iso      VARCHAR(2)   NOT NULL PRIMARY KEY,
    code_iso_3    VARCHAR(3)   NULL,
    nom_fr        VARCHAR(100) NOT NULL,
    latitude      DOUBLE       NOT NULL,
    longitude     DOUBLE       NOT NULL,
    actif         BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_pays_code_iso_3 UNIQUE (code_iso_3)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Insertion des pays plausibles pour l'import et du Mali comme destination
INSERT INTO pays (code_iso, code_iso_3, nom_fr, latitude, longitude, actif) VALUES
    ('ML', 'MLI', 'Mali', 12.6392, -8.0029, TRUE),
    ('CN', 'CHN', 'Chine', 35.8617, 104.1954, TRUE),
    ('TR', 'TUR', 'Turquie', 38.9637, 35.2433, TRUE),
    ('AE', 'ARE', 'Émirats arabes unis', 23.4241, 53.8478, TRUE),
    ('IN', 'IND', 'Inde', 20.5937, 78.9629, TRUE),
    ('FR', 'FRA', 'France', 46.2276, 2.2137, TRUE),
    ('MA', 'MAR', 'Maroc', 31.7917, -7.0926, TRUE),
    ('SN', 'SEN', 'Sénégal', 14.4974, -14.4524, TRUE),
    ('CI', 'CIV', 'Côte d''Ivoire', 7.5400, -5.5471, TRUE),
    ('GH', 'GHA', 'Ghana', 7.9465, -1.0232, TRUE),
    ('NG', 'NGA', 'Nigéria', 9.0820, 8.6753, TRUE),
    ('TG', 'TGO', 'Togo', 8.6195, 0.8248, TRUE),
    ('BJ', 'BEN', 'Bénin', 9.3077, 2.3158, TRUE),
    ('ES', 'ESP', 'Espagne', 40.4637, -3.7492, TRUE),
    ('DE', 'DEU', 'Allemagne', 51.1657, 10.4515, TRUE),
    ('IT', 'ITA', 'Italie', 41.8719, 12.5674, TRUE),
    ('US', 'USA', 'États-Unis', 37.0902, -95.7129, TRUE),
    ('BR', 'BRA', 'Brésil', -14.2350, -51.9253, TRUE),
    ('VN', 'VNM', 'Vietnam', 14.0583, 108.2772, TRUE),
    ('TH', 'THA', 'Thaïlande', 15.8700, 100.9925, TRUE),
    ('SA', 'SAU', 'Arabie saoudite', 23.8859, 45.0792, TRUE),
    ('EG', 'EGY', 'Égypte', 26.8206, 30.8025, TRUE),
    ('ZA', 'ZAF', 'Afrique du Sud', -30.5595, 22.9375, TRUE);

-- Colonne NULLABLE sur groupe_achat (anciens groupes laissés à NULL)
ALTER TABLE groupe_achat ADD COLUMN pays_origine_code VARCHAR(2) NULL;

-- Clé étrangère et index optimisés
ALTER TABLE groupe_achat
    ADD CONSTRAINT fk_groupe_pays_origine
    FOREIGN KEY (pays_origine_code) REFERENCES pays (code_iso);

CREATE INDEX idx_groupe_pays_origine ON groupe_achat (pays_origine_code);
CREATE INDEX idx_groupe_statut_pays ON groupe_achat (statut, pays_origine_code);

