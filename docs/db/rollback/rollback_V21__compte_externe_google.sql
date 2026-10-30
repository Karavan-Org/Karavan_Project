-- Script de Rollback pour la migration V21 (Fédération Google / compte_externe)
-- À exécuter en cas de retour arrière sur la base de données.

-- 1. Suppression de la table compte_externe
DROP TABLE IF EXISTS compte_externe;

-- 2. Restauration de l'obligation de mot de passe (valeur par défaut temporaire si NULL)
UPDATE utilisateur
SET mot_de_passe_hash = '$2a$10$VNiROclYlckAH4ERMjsfsePZ0DHctlkdy684DEdkFhEu8R4Lli.xq'
WHERE mot_de_passe_hash IS NULL;

ALTER TABLE utilisateur
    MODIFY COLUMN mot_de_passe_hash VARCHAR(255) NOT NULL,
    DROP COLUMN email;

