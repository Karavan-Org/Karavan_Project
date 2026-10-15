-- Adresse réelle du dépôt principal (Plus Code Google « JXJF+76R », Bamako ≈ 12.630738, -8.026984).
-- Les coordonnées du lien servent de destination à l'itinéraire affiché dans l'application commerçant.
UPDATE point_retrait
SET adresse = 'JXJF+76R, Unnamed Road, Bamako',
    lien_google_map = 'https://www.google.com/maps/search/?api=1&query=12.630738,-8.026984'
WHERE id = 1;
