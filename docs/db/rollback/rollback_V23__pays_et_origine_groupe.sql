-- Rollback V23 : suppression de pays_origine_code et de la table pays

ALTER TABLE groupe_achat DROP FOREIGN KEY fk_groupe_pays_origine;
DROP INDEX idx_groupe_statut_pays ON groupe_achat;
DROP INDEX idx_groupe_pays_origine ON groupe_achat;
ALTER TABLE groupe_achat DROP COLUMN pays_origine_code;

DROP TABLE pays;

