package ml.dogo.identite.application;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Set;
import java.util.UUID;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

/**
 * Service de stockage sécurisé des photos de profil des acteurs (commerçants, grossistes, courtiers).
 * Valide la signature binaire, la taille et protège contre le Path Traversal.
 */
@Service
public class StockageAvatarService {

    private final Path repertoireAvatars;
    private static final Set<String> TYPES_MIME_AUTORISES = Set.of("image/jpeg", "image/png", "image/webp");
    private static final long TAILLE_MAX_OCTETS = 5 * 1024 * 1024; // 5 Mo

    public StockageAvatarService(@Value("${dogo.stockage.repertoire-avatars:uploads/avatars}") String chemin) {
        this.repertoireAvatars = Paths.get(chemin).toAbsolutePath().normalize();
        try {
            Files.createDirectories(this.repertoireAvatars);
        } catch (IOException e) {
            throw new RuntimeException("Impossible d'initialiser le répertoire des avatars : " + this.repertoireAvatars, e);
        }
    }

    /**
     * Stocke une photo de profil et renvoie l'URL publique relative.
     */
    public String stockerPhotoProfil(MultipartFile fichier, long utilisateurId) {
        if (fichier == null || fichier.isEmpty()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "FICHIER_VIDE", "Le fichier envoyé est vide.");
        }

        if (fichier.getSize() > TAILLE_MAX_OCTETS) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "TAILLE_MAX", "La taille du fichier dépasse la limite de 5 Mo.");
        }

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

        String nomSecurise = "avatar_" + utilisateurId + "_" + UUID.randomUUID() + extension;
        Path cible = this.repertoireAvatars.resolve(nomSecurise).normalize();

        if (!cible.startsWith(this.repertoireAvatars)) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "SECURITE", "Chemin de fichier interdit.");
        }

        try {
            Files.write(cible, contenu);
        } catch (IOException e) {
            throw new RuntimeException("Erreur lors de l'enregistrement de l'image de profil.", e);
        }

        return "/api/public/images/avatars/" + nomSecurise;
    }

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

