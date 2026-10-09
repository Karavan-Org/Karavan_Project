-- Un Grossiste peut monter lui-même un groupe d'achat sur ses produits, sans Courtier :
-- il achemine la marchandise par ses propres moyens et signale les étapes à l'Administrateur.

-- Le courtier devient facultatif (NULL = groupe porté par le grossiste du produit).
ALTER TABLE groupe_achat MODIFY courtier_id BIGINT NULL;

-- Titre libre donné au groupe par son créateur (à défaut, on affiche le nom du produit).
ALTER TABLE groupe_achat ADD COLUMN titre VARCHAR(120) NULL;

-- Prix de gros unitaire indicatif saisi à la création du produit : il pré-remplit le groupe d'achat.
ALTER TABLE produit ADD COLUMN prix_gros DECIMAL(15, 2) NULL;

-- Le séquestre d'un groupe porté par un grossiste est tenu dans le portefeuille du grossiste.
ALTER TABLE portefeuille DROP FOREIGN KEY fk_portefeuille_courtier;
ALTER TABLE portefeuille
    ADD CONSTRAINT fk_portefeuille_utilisateur FOREIGN KEY (courtier_id) REFERENCES utilisateur (id);

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.code IN ('GROUPE_CREER', 'GROUPE_ANNULER', 'PORTEFEUILLE_RETIRER')
WHERE r.nom = 'GROSSISTE'
  AND NOT EXISTS (SELECT 1 FROM role_permission rp WHERE rp.role_id = r.id AND rp.permission_id = p.id);
