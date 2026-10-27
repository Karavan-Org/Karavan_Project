-- RG-02 : le nombre de codes envoyés est plafonné par numéro de téléphone. Le numéro est conservé sur chaque
-- code pour que ce plafond survive au remplacement d'une inscription abandonnée (compte jamais vérifié,
-- supprimé lors d'une nouvelle inscription sur le même numéro) : son historique d'envois reste compté.
ALTER TABLE code_otp ADD COLUMN telephone VARCHAR(20) NULL AFTER utilisateur_id;

UPDATE code_otp c JOIN utilisateur u ON u.id = c.utilisateur_id SET c.telephone = u.telephone;

ALTER TABLE code_otp DROP FOREIGN KEY fk_otp_utilisateur;
ALTER TABLE code_otp MODIFY utilisateur_id BIGINT NULL;
ALTER TABLE code_otp ADD CONSTRAINT fk_otp_utilisateur
    FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id) ON DELETE SET NULL;

CREATE INDEX idx_otp_telephone ON code_otp (telephone, date_creation);
