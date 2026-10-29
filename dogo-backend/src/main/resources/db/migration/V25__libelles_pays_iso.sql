-- V25 : Libellés des pays et données de référence en UTF-8 conforme ISO 3166-1 / CLDR
UPDATE pays SET nom_fr = 'Émirats arabes unis' WHERE code_iso = 'AE';
UPDATE pays SET nom_fr = 'Bénin' WHERE code_iso = 'BJ';
UPDATE pays SET nom_fr = 'Brésil' WHERE code_iso = 'BR';
UPDATE pays SET nom_fr = 'Côte d''Ivoire' WHERE code_iso = 'CI';
UPDATE pays SET nom_fr = 'Égypte' WHERE code_iso = 'EG';
UPDATE pays SET nom_fr = 'Nigéria' WHERE code_iso = 'NG';
UPDATE pays SET nom_fr = 'Sénégal' WHERE code_iso = 'SN';
UPDATE pays SET nom_fr = 'Thaïlande' WHERE code_iso = 'TH';
UPDATE pays SET nom_fr = 'États-Unis' WHERE code_iso = 'US';

UPDATE groupe_achat SET titre = 'Beurre de Karité & Cacao' WHERE id = 8417;
UPDATE groupe_achat SET titre = 'Huile d''Argan Cosmétique Bio' WHERE id = 8418;
UPDATE groupe_achat SET titre = 'Noix de Cajou & Épices' WHERE id = 8419;

UPDATE produit SET nom_produit = 'Noix de Cajou & Épices Sahéliennes' WHERE nom_produit LIKE '%Noix de Cajou%';
UPDATE produit SET nom_produit = 'Huile d''Argan Cosmétique Bio' WHERE nom_produit LIKE '%Huile d''Argan%';
UPDATE produit SET nom_produit = 'Beurre de Karité & Cacao Pur' WHERE nom_produit LIKE '%Beurre de Karit%';
UPDATE produit SET nom_produit = 'Chaussures Cuir Véritable Artisanal' WHERE nom_produit LIKE '%Chaussures Cuir%';

UPDATE categorie SET nom_categorie = 'Vêtements', description = 'Prêt-à-porter homme, femme, enfant' WHERE id = 2;
UPDATE categorie SET nom_categorie = 'Électronique', description = 'Téléphones, accessoires, petit électroménager' WHERE id = 3;
UPDATE categorie SET description = 'Ustensiles, décoration, linge de maison' WHERE id = 4;

UPDATE utilisateur SET nom = 'Aliou Traoré' WHERE nom LIKE 'Aliou Traor%';

UPDATE commercant SET nom_boutique = 'Boutique Keita Grand Marché', quartier_bamako = 'Grand Marché' WHERE nom_boutique LIKE '%Keita Grand March%';
UPDATE commercant SET quartier_bamako = 'Grand Marché' WHERE quartier_bamako LIKE '%Grand March%';

UPDATE etape_acheminement SET commentaire = 'Campagne ouverte aux commerçants de Bamako' WHERE commentaire LIKE '%Campagne ouverte aux commer%ants de Bamako%';
