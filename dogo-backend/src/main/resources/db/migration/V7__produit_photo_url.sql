-- V7 : Ajout de la colonne photo_url pour la classe Produit (aligné avec diagramClass.xml)
ALTER TABLE produit ADD COLUMN photo_url VARCHAR(500) NULL AFTER description;

