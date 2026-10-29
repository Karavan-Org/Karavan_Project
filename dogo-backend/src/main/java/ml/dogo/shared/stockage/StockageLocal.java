package ml.dogo.shared.stockage;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.UUID;
import ml.dogo.shared.config.DogoProperties;
import org.springframework.stereotype.Component;

@Component
public class StockageLocal implements StockageFichiers {

    private final Path racine;

    public StockageLocal(DogoProperties proprietes) {
        this.racine = Path.of(proprietes.stockage().dossier()).toAbsolutePath().normalize();
    }

    @Override
    public String enregistrer(String nomOriginal, byte[] contenu) {
        String extension = extensionSure(nomOriginal);
        String cle = UUID.randomUUID() + extension;
        try {
            Files.createDirectories(racine);
            Files.write(racine.resolve(cle), contenu);
            return cle;
        } catch (IOException e) {
            throw new UncheckedIOException("Impossible d'enregistrer le fichier", e);
        }
    }

    @Override
    public byte[] lire(String cle) {
        Path fichier = racine.resolve(cle).normalize();
        if (!fichier.startsWith(racine) || !Files.isRegularFile(fichier)) {
            throw ml.dogo.shared.errors.ErreurMetier.nonTrouve("Fichier", cle);
        }
        try {
            return Files.readAllBytes(fichier);
        } catch (IOException e) {
            throw new UncheckedIOException("Impossible de lire le fichier", e);
        }
    }

    /** Seules quelques extensions sont conservées : jamais de chemin ni de nom venant du client. */
    static String extensionSure(String nom) {
        if (nom == null) {
            return "";
        }
        String bas = nom.toLowerCase(Locale.ROOT);
        for (String ext : new String[]{".pdf", ".jpg", ".jpeg", ".png",
                ".docx", ".doc", ".xlsx", ".xls", ".odt", ".ods", ".rtf", ".txt", ".csv"}) {
            if (bas.endsWith(ext)) {
                return ext;
            }
        }
        return "";
    }
}
