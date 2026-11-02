-- Permettre à un commerçant de commander plusieurs fois dans le même groupe
-- Tout en interdisant les doubles réservations concurrentes en attente de paiement (DEMANDEE, RESERVEE)
ALTER TABLE participation DROP KEY uq_participation_active;
ALTER TABLE participation DROP COLUMN cle_active;
ALTER TABLE participation ADD COLUMN cle_active VARCHAR(70) GENERATED ALWAYS AS (
    IF(statut IN ('DEMANDEE', 'RESERVEE'), CONCAT(groupe_id, '-', commercant_id, '-', variante_id), NULL)
) STORED;
ALTER TABLE participation ADD CONSTRAINT uq_participation_active UNIQUE (cle_active);

