-- V26 : un seul administrateur principal, plus aucun compte administrateur de démonstration.
--
-- 1. Mot de passe provisoire : tant que l'indicateur est levé, le compte ne peut que changer son mot de passe
--    (RG-07b, filtre FiltreMotDePasseProvisoire). Posé sur l'administrateur principal et sur chaque administrateur
--    créé depuis la console.
-- 2. Suppression de tous les administrateurs existants (comptes de démo +2237000000x, ADM-000x).
--    Le journal d'audit est en ajout seul et chaîné (RG-66, RG-67) : il n'est pas modifié, ses lignes gardent
--    l'identifiant de l'ancien acteur. Les décisions KYC et de publication déjà prises sont conservées, leur auteur
--    devient inconnu (NULL) plutôt que d'être réattribué à quelqu'un qui ne les a pas prises.
-- 3. Création de l'administrateur principal (rôle TECHNIQUE), mot de passe provisoire « 1234 » à changer
--    à la première connexion.

ALTER TABLE utilisateur ADD COLUMN mot_de_passe_provisoire TINYINT(1) NOT NULL DEFAULT 0 AFTER mot_de_passe_hash;

-- Décisions passées : l'auteur supprimé devient inconnu
ALTER TABLE validation_compte MODIFY administrateur_id BIGINT NULL;
ALTER TABLE validation_groupe MODIFY administrateur_id BIGINT NULL;

CREATE TEMPORARY TABLE admins_supprimes AS SELECT utilisateur_id AS id FROM administrateur;

UPDATE validation_compte SET administrateur_id = NULL WHERE administrateur_id IN (SELECT id FROM admins_supprimes);
UPDATE validation_groupe SET administrateur_id = NULL WHERE administrateur_id IN (SELECT id FROM admins_supprimes);

-- Données propres au compte (refresh_token et compte_externe partent en cascade, code_otp passe à NULL)
DELETE FROM notification WHERE utilisateur_id IN (SELECT id FROM admins_supprimes);
DELETE FROM session_utilisateur WHERE utilisateur_id IN (SELECT id FROM admins_supprimes);
DELETE FROM moyen_paiement_utilisateur WHERE utilisateur_id IN (SELECT id FROM admins_supprimes);
DELETE FROM code_otp WHERE utilisateur_id IN (SELECT id FROM admins_supprimes);
DELETE FROM portefeuille WHERE courtier_id IN (SELECT id FROM admins_supprimes)
  AND id NOT IN (SELECT portefeuille_id FROM mouvement_financier WHERE portefeuille_id IS NOT NULL);

DELETE FROM administrateur WHERE utilisateur_id IN (SELECT id FROM admins_supprimes);
DELETE FROM utilisateur WHERE id IN (SELECT id FROM admins_supprimes);

DROP TEMPORARY TABLE admins_supprimes;

-- Administrateur principal : mot de passe provisoire « 1234 » (BCrypt), téléphone vérifié, compte actif
INSERT INTO utilisateur (type_acteur, telephone, nom, email, mot_de_passe_hash, mot_de_passe_provisoire, langue,
                         statut_compte, telephone_verifie, tentatives_echecs, role_id, date_creation)
SELECT 'ADMINISTRATEUR', '+22375250430', 'Salif Modibo Keita', 'salifmodibok@gmail.com',
       '$2a$10$5nW.Ww/x3onqKpyOvc2Uwe4GAiX1TQ0pzlPlwBr03GSX.7GLNV9Xq', 1, 'fr', 'ACTIF', 1, 0, r.id, NOW(3)
FROM role r
WHERE r.nom = 'ADMINISTRATEUR';

INSERT INTO administrateur (utilisateur_id, matricule_agent, role_administratif)
SELECT u.id, 'ADM-0001', 'TECHNIQUE'
FROM utilisateur u
WHERE u.telephone = '+22375250430';
