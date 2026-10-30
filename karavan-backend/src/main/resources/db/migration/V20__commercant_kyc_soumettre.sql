-- Attribution de la permission KYC_SOUMETTRE au rôle COMMERCANT pour le dépôt des pièces justificatives (RG-04)
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.code = 'KYC_SOUMETTRE'
WHERE r.nom = 'COMMERCANT'
  AND NOT EXISTS (SELECT 1 FROM role_permission rp WHERE rp.role_id = r.id AND rp.permission_id = p.id);

