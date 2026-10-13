-- V13 : Ajout de la colonne photo_url pour la classe Utilisateur (photo de profil personnalisée)
ALTER TABLE utilisateur ADD COLUMN photo_url VARCHAR(500) NULL AFTER langue;

