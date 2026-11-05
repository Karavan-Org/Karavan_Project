-- V29 : Référentiel étendu des pays d'approvisionnement internationaux
-- Ajoute les pays majeurs d'importation manquants (Australie, Japon, Corée du Sud, Canada, etc.)
-- et rectifie les groupes existants dont le pays avait été par défaut rattaché au Mali.

INSERT INTO pays (code_iso, code_iso_3, nom_fr, latitude, longitude, actif) VALUES
    ('AU', 'AUS', 'Australie', -25.2744, 133.7751, TRUE),
    ('JP', 'JPN', 'Japon', 36.2048, 138.2529, TRUE),
    ('KR', 'KOR', 'Corée du Sud', 35.9078, 127.7669, TRUE),
    ('CA', 'CAN', 'Canada', 56.1304, -106.3468, TRUE),
    ('GB', 'GBR', 'Royaume-Uni', 55.3781, -3.4360, TRUE),
    ('CH', 'CHE', 'Suisse', 46.8182, 8.2275, TRUE),
    ('BE', 'BEL', 'Belgique', 50.5039, 4.4699, TRUE),
    ('NL', 'NLD', 'Pays-Bas', 52.1326, 5.2913, TRUE),
    ('PT', 'PRT', 'Portugal', 39.3999, -8.2245, TRUE),
    ('ID', 'IDN', 'Indonésie', -0.7893, 113.9213, TRUE),
    ('MY', 'MYS', 'Malaisie', 4.2105, 101.9758, TRUE),
    ('PK', 'PAK', 'Pakistan', 30.3753, 69.3451, TRUE),
    ('BD', 'BGD', 'Bangladesh', 23.6850, 90.3563, TRUE),
    ('CM', 'CMR', 'Cameroun', 7.3697, 12.3547, TRUE),
    ('MR', 'MRT', 'Mauritanie', 21.0079, -10.9408, TRUE),
    ('DZ', 'DZA', 'Algérie', 28.0339, 1.6596, TRUE),
    ('TN', 'TUN', 'Tunisie', 33.8869, 9.5375, TRUE),
    ('GN', 'GIN', 'Guinée', 9.9456, -9.6966, TRUE),
    ('BF', 'BFA', 'Burkina Faso', 12.2383, -1.5616, TRUE),
    ('NE', 'NER', 'Niger', 17.6078, 8.0817, TRUE),
    ('AZ', 'AZE', 'Azerbaïdjan', 40.1431, 47.5769, TRUE),
    ('GA', 'GAB', 'Gabon', -0.8037, 11.6094, TRUE),
    ('CG', 'COG', 'Congo', -0.2280, 15.8277, TRUE),
    ('CD', 'COD', 'RDC', -4.0383, 21.7587, TRUE),
    ('MG', 'MDG', 'Madagascar', -18.7669, 46.8691, TRUE),
    ('MU', 'MUS', 'Maurice', -20.3484, 57.5522, TRUE)
ON DUPLICATE KEY UPDATE
    nom_fr = VALUES(nom_fr),
    code_iso_3 = VALUES(code_iso_3),
    latitude = VALUES(latitude),
    longitude = VALUES(longitude),
    actif = VALUES(actif);

-- Harmonisation des groupes existants créés avec un pays d'origine du produit spécifique
UPDATE groupe_achat g
JOIN produit p ON g.produit_id = p.id
SET g.pays_origine_code = 'AU'
WHERE (p.pays_origine LIKE '%Australie%' OR p.pays_origine LIKE '%Australia%')
  AND (g.pays_origine_code IS NULL OR g.pays_origine_code = 'ML');

UPDATE groupe_achat g
JOIN produit p ON g.produit_id = p.id
SET g.pays_origine_code = 'JP'
WHERE (p.pays_origine LIKE '%Japon%' OR p.pays_origine LIKE '%Japan%')
  AND (g.pays_origine_code IS NULL OR g.pays_origine_code = 'ML');

UPDATE groupe_achat g
JOIN produit p ON g.produit_id = p.id
SET g.pays_origine_code = 'AZ'
WHERE (p.pays_origine LIKE '%Azerba%' OR p.pays_origine LIKE '%Azerbai%')
  AND (g.pays_origine_code IS NULL OR g.pays_origine_code = 'ML');

