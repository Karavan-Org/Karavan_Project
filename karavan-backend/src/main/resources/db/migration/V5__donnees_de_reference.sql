-- Permissions, rôles et catégories de départ (RG-06).

INSERT INTO permission (code, description) VALUES
 ('PROFIL_GERER', 'Gérer son profil et ses moyens de paiement'),
 ('KYC_SOUMETTRE', 'Soumettre un dossier KYC'),
 ('NOTIFICATION_LIRE', 'Lire ses notifications'),
 ('CAMPAGNE_EXPLORER', 'Explorer et consulter les campagnes'),
 ('PARTICIPATION_GERER', 'Rejoindre, suivre et annuler une participation'),
 ('PAIEMENT_EFFECTUER', 'Payer sa participation'),
 ('COMMANDE_LIRE', 'Consulter ses commandes'),
 ('RETRAIT_EFFECTUER', 'Présenter son code de retrait (QR / PIN)'),
 ('RETRAIT_VALIDER', 'Valider un retrait en scannant le code du commerçant'),
 ('CATALOGUE_GERER', 'Gérer son catalogue'),
 ('GROUPE_DISPONIBILITE_VALIDER', 'Valider la disponibilité des marchandises'),
 ('GROUPE_CREER', 'Créer un groupe d''achat'),
 ('GROUPE_SUIVRE', 'Suivre l''évolution des groupes'),
 ('GROUPE_ANNULER', 'Annuler un groupe d''achat'),
 ('COMMANDE_AVANCER', 'Faire avancer les commandes (préparation, expédition, retrait)'),
 ('PORTEFEUILLE_RETIRER', 'Retirer les fonds disponibles du portefeuille'),
 ('KYC_VALIDER', 'Valider ou rejeter un dossier KYC'),
 ('GROUPE_PUBLICATION_VALIDER', 'Autoriser la publication d''un groupe'),
 ('COMPTE_SUSPENDRE', 'Suspendre ou réactiver un compte'),
 ('RECEPTION_VALIDER', 'Valider la réception des colis au dépôt'),
 ('POINT_RETRAIT_GERER', 'Gérer les points de retrait'),
 ('AUDIT_LIRE', 'Consulter le journal d''audit'),
 ('REMBOURSEMENT_APPROUVER', 'Approuver un remboursement'),
 ('ADMIN_CREER', 'Créer un compte administrateur');

INSERT INTO role (nom, description) VALUES
 ('COMMERCANT', 'Commerçant acheteur'),
 ('GROSSISTE', 'Grossiste fournisseur'),
 ('COURTIER', 'Courtier importateur'),
 ('ADMINISTRATEUR', 'Administrateur de la plateforme');

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON (
    (r.nom = 'COMMERCANT' AND p.code IN ('PROFIL_GERER', 'NOTIFICATION_LIRE', 'CAMPAGNE_EXPLORER', 'PARTICIPATION_GERER',
        'PAIEMENT_EFFECTUER', 'COMMANDE_LIRE', 'RETRAIT_EFFECTUER', 'GROUPE_SUIVRE'))
 OR (r.nom = 'GROSSISTE' AND p.code IN ('PROFIL_GERER', 'KYC_SOUMETTRE', 'NOTIFICATION_LIRE', 'CATALOGUE_GERER',
        'GROUPE_DISPONIBILITE_VALIDER', 'COMMANDE_LIRE'))
 OR (r.nom = 'COURTIER' AND p.code IN ('PROFIL_GERER', 'KYC_SOUMETTRE', 'NOTIFICATION_LIRE', 'CAMPAGNE_EXPLORER',
        'GROUPE_CREER', 'GROUPE_SUIVRE', 'GROUPE_ANNULER', 'COMMANDE_LIRE', 'COMMANDE_AVANCER', 'RETRAIT_VALIDER', 'PORTEFEUILLE_RETIRER'))
 OR (r.nom = 'ADMINISTRATEUR' AND p.code IN ('PROFIL_GERER', 'NOTIFICATION_LIRE', 'CAMPAGNE_EXPLORER', 'KYC_VALIDER',
        'GROUPE_PUBLICATION_VALIDER', 'GROUPE_ANNULER', 'GROUPE_SUIVRE', 'COMPTE_SUSPENDRE', 'RECEPTION_VALIDER',
        'POINT_RETRAIT_GERER', 'AUDIT_LIRE', 'REMBOURSEMENT_APPROUVER', 'COMMANDE_LIRE', 'RETRAIT_VALIDER', 'ADMIN_CREER'))
);

INSERT INTO categorie (nom_categorie, description) VALUES
 ('Chaussures', 'Baskets, sandales, chaussures de ville'),
 ('Vêtements', 'Prêt-à-porter homme, femme, enfant'),
 ('Électronique', 'Téléphones, accessoires, petit électroménager'),
 ('Maison', 'Ustensiles, décoration, linge de maison');
