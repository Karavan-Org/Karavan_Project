-- Retour arrière de V26 (structure uniquement) : les administrateurs supprimés ne sont pas recréés.
-- À n'exécuter qu'une fois toutes les décisions sans auteur (administrateur_id NULL) réattribuées ou purgées.
ALTER TABLE validation_groupe MODIFY administrateur_id BIGINT NOT NULL;
ALTER TABLE validation_compte MODIFY administrateur_id BIGINT NOT NULL;
ALTER TABLE utilisateur DROP COLUMN mot_de_passe_provisoire;
