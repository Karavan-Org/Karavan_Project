-- Migration V14 : Ajout du type de mouvement RECHARGE_PORTEFEUILLE pour la gestion dynamique du portefeuille commerçant
ALTER TABLE mouvement_financier DROP CHECK ck_mouvement_type;
ALTER TABLE mouvement_financier ADD CONSTRAINT ck_mouvement_type CHECK (type IN (
    'DEBIT_COMMERCANT', 'BLOCAGE_SEQUESTRE', 'LIBERATION_SEQUESTRE',
    'FRAIS_PLATEFORME', 'REMBOURSEMENT', 'RETRAIT_COURTIER', 'RECHARGE_PORTEFEUILLE'
));

