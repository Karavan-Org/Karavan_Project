package ml.dogo.catalogue.application;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Set;
import java.util.UUID;

/**
 * Service de stockage de fichiers sécurisé pour les photos produits et documents.
 * Valide le type MIME, l'extension, la taille, et prévient les attaques Path Traversal.
 */
@Service
public class StockageService {

    private final Path repertoireUpload;
    private static final Set<String> TYPES_MIME_AUTORISES = Set.of("image/jpeg", "image/png", "image/webp");
    private static final long TAILLE_MAX_OCTETS = 5 * 1024 * 1024; // 5 Mo

    public StockageService(@Value("${dogo.stockage.repertoire:uploads/produits}") String chemin) {
        this.repertoireUpload = Paths.get(chemin).toAbsolutePath().normalize();
        try {
            Files.createDirectories(this.repertoireUpload);
        } catch (IOException e) {
            throw new RuntimeException("Impossible d'initialiser le répertoire d'upload : " + this.repertoireUpload, e);
        }
    }

    /**
     * Stocke une photo de produit avec renommage aléatoire sécurisé (UUID).
     * @return L'URL relative servie par le backend (ex: /api/public/images/produits/prod_1_uuid.jpg)
     */
    public String stockerPhotoProduit(MultipartFile fichier, long grossisteId) {
        if (fichier == null || fichier.isEmpty()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "FICHIER_VIDE", "Le fichier envoyé est vide.");
        }

        if (fichier.getSize() > TAILLE_MAX_OCTETS) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "TAILLE_MAX", "La taille du fichier dépasse la limite de 5 Mo.");
        }

        // Le type est déduit de la signature du fichier : le Content-Type déclaré par le client
        // (souvent application/octet-stream depuis mobile) n'est ni fiable ni sûr.
        byte[] contenu;
        try {
            contenu = fichier.getBytes();
        } catch (IOException e) {
            throw new RuntimeException("Erreur lors de la lecture de l'image.", e);
        }
        String typeMime = typeImage(contenu);
        if (typeMime == null || !TYPES_MIME_AUTORISES.contains(typeMime)) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "TYPE_FICHIER", "Formats acceptés : JPEG, PNG, WEBP.");
        }

        String extension = switch (typeMime) {
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            default -> ".jpg";
        };

        String nomSecurise = "prod_" + grossisteId + "_" + UUID.randomUUID() + extension;
        Path cible = this.repertoireUpload.resolve(nomSecurise).normalize();

        // Sécurité Path Traversal
        if (!cible.startsWith(this.repertoireUpload)) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "SECURITE", "Chemin de fichier interdit.");
        }

        try {
            Files.write(cible, contenu);
        } catch (IOException e) {
            throw new RuntimeException("Erreur lors de l'enregistrement de l'image.", e);
        }

        return "/api/public/images/produits/" + nomSecurise;
    }

    /** Signature binaire : JPEG, PNG ou WEBP ; {@code null} sinon. */
    static String typeImage(byte[] c) {
        if (c.length >= 3 && (c[0] & 0xFF) == 0xFF && (c[1] & 0xFF) == 0xD8 && (c[2] & 0xFF) == 0xFF) {
            return "image/jpeg";
        }
        if (c.length >= 4 && (c[0] & 0xFF) == 0x89 && c[1] == 'P' && c[2] == 'N' && c[3] == 'G') {
            return "image/png";
        }
        if (c.length >= 12 && c[0] == 'R' && c[1] == 'I' && c[2] == 'F' && c[3] == 'F'
                && c[8] == 'W' && c[9] == 'E' && c[10] == 'B' && c[11] == 'P') {
            return "image/webp";
        }
        return null;
    }
}

