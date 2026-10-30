package ml.dogo.identite.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDate;
import ml.dogo.identite.domain.TypeDocument;

@Entity
@Table(name = "document_legal")
public class DocumentLegal {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TypeDocument type;

    @Column(nullable = false)
    private String fichier;

    @Column(name = "empreinte_sha256", nullable = false, length = 64)
    private String empreinteSha256;

    @Column(name = "date_expiration")
    private LocalDate dateExpiration;

    protected DocumentLegal() {
    }

    public DocumentLegal(TypeDocument type, String fichier, String empreinteSha256, LocalDate dateExpiration) {
        this.type = type;
        this.fichier = fichier;
        this.empreinteSha256 = empreinteSha256;
        this.dateExpiration = dateExpiration;
    }

    public Long getId() { return id; }
    public TypeDocument getType() { return type; }
    public String getFichier() { return fichier; }
    public String getEmpreinteSha256() { return empreinteSha256; }
    public LocalDate getDateExpiration() { return dateExpiration; }
}
