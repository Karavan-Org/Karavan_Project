-- V8 : pièces facultatives du dossier KYC (relevé bancaire, autres justificatifs), en plus des pièces exigées par RG-04.
ALTER TABLE document_legal DROP CHECK ck_document_type;
ALTER TABLE document_legal ADD CONSTRAINT ck_document_type
    CHECK (type IN ('NIF', 'REGISTRE_COMMERCE', 'LICENCE_TRANSIT', 'PIECE_IDENTITE', 'RELEVE_BANCAIRE', 'AUTRE'));
