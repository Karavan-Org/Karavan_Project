-- Ajout du lien Google Maps pour les dépôts / points de retrait (géolocalisation pour les commerçants)
ALTER TABLE point_retrait ADD COLUMN lien_google_map VARCHAR(500) NULL;

-- Initialisation des points de référence avec des coordonnées réelles à Bamako
UPDATE point_retrait 
SET lien_google_map = 'https://maps.google.com/?q=12.6174,-7.9942' 
WHERE id = 1 AND lien_google_map IS NULL;

UPDATE point_retrait 
SET lien_google_map = 'https://maps.google.com/?q=12.6450,-7.9950' 
WHERE id = 2 AND lien_google_map IS NULL;

