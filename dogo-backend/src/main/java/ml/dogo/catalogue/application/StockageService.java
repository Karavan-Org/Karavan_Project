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
import java.nio.file.StandardCopyOption;
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

        String typeMime = fichier.getContentType();
        if (typeMime == null || !TYPES_MIME_AUTORISES.contains(typeMime.toLowerCase())) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "TYPE_FICHIER", "Formats acceptés : JPEG, PNG, WEBP.");
        }

        String extension = switch (typeMime.toLowerCase()) {
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
            Files.copy(fichier.getInputStream(), cible, StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            throw new RuntimeException("Erreur lors de l'enregistrement de l'image.", e);
        }

        return "/api/public/images/produits/" + nomSecurise;
    }
}

