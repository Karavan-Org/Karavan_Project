-- V17 : Support du rôle LOGISTIQUE et création du compte administrateur Logistique (+22370000005)
-- Mission : Gestion du suivi des colis, étapes de livraison, localisation des dépôts Google Maps et validation des retraits.

ALTER TABLE administrateur DROP CHECK ck_admin_role;
ALTER TABLE administrateur ADD CONSTRAINT ck_admin_role CHECK (role_administratif IN ('VALIDATION', 'FINANCE', 'SUPPORT', 'LOGISTIQUE', 'TECHNIQUE'));

INSERT INTO utilisateur (type_acteur, telephone, nom, mot_de_passe_hash, langue, photo_url, statut_compte, telephone_verifie, tentatives_echecs, verrouille_jusqua, role_id, date_creation)
SELECT 'ADMINISTRATEUR', '+22370000005', 'Admin Logistique', '$2a$10$VNiROclYlckAH4ERMjsfsePZ0DHctlkdy684DEdkFhEu8R4Lli.xq', 'fr', NULL, 'ACTIF', 1, 0, NULL, 4, NOW()
WHERE NOT EXISTS (SELECT 1 FROM utilisateur WHERE telephone = '+22370000005');

INSERT INTO administrateur (utilisateur_id, matricule_agent, role_administratif)
SELECT u.id, 'ADM-0005', 'LOGISTIQUE'
FROM utilisateur u
WHERE u.telephone = '+22370000005'
  AND NOT EXISTS (SELECT 1 FROM administrateur WHERE matricule_agent = 'ADM-0005');

