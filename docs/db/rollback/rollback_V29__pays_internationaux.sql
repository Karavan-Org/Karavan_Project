-- Rollback V29 : Rétablissement des pays internationaux
UPDATE groupe_achat g
JOIN produit p ON g.produit_id = p.id
SET g.pays_origine_code = 'ML'
WHERE g.pays_origine_code IN ('AU', 'JP', 'AZ');

DELETE FROM pays WHERE code_iso IN (
    'AU', 'JP', 'KR', 'CA', 'GB', 'CH', 'BE', 'NL', 'PT', 'ID',
    'MY', 'PK', 'BD', 'CM', 'MR', 'DZ', 'TN', 'GN', 'BF', 'NE',
    'AZ', 'GA', 'CG', 'CD', 'MG', 'MU'
);

