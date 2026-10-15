-- Paiement direct par portefeuille : moyen_paiement_id devient optionnel
ALTER TABLE paiement MODIFY moyen_paiement_id BIGINT NULL;

