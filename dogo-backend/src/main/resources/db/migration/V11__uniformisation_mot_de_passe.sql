-- Migration V11 : Uniformisation de l'authentification avec "mot de passe" au lieu de "code PIN".
-- Modification des colonnes de la table utilisateur et mise à jour des comptes existants.

ALTER TABLE utilisateur DROP CHECK ck_utilisateur_tentatives;

ALTER TABLE utilisateur
  CHANGE COLUMN pin_hash mot_de_passe_hash VARCHAR(255) NOT NULL,
  CHANGE COLUMN tentatives_pin tentatives_echecs INT NOT NULL DEFAULT 0;

ALTER TABLE utilisateur
  ADD CONSTRAINT ck_utilisateur_tentatives CHECK (tentatives_echecs >= 0);

-- Mise à jour des mots de passe de test pour tous les comptes existants vers 'Dogo2026!'
UPDATE utilisateur
SET mot_de_passe_hash = '$2a$10$VNiROclYlckAH4ERMjsfsePZ0DHctlkdy684DEdkFhEu8R4Lli.xq',
    tentatives_echecs = 0,
    verrouille_jusqua = NULL;

