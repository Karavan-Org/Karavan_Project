package ml.dogo.identite.application;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collections;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/**
 * Formats acceptés pour une pièce KYC : images, PDF et documents électroniques (Word, Excel,
 * OpenDocument, RTF, texte). Le contenu fait foi : la signature binaire (ou, pour un texte, l'absence
 * d'octets de contrôle) doit correspondre à l'extension annoncée.
 */
final class FormatPiece {

    static final String FORMATS_LISIBLES = "PDF, JPEG, PNG, Word, Excel, OpenDocument, RTF, TXT, CSV";

    private FormatPiece() {
    }

    /** Extension sûre (« .pdf », « .docx »…) sous laquelle stocker la pièce, ou null si elle est refusée. */
    static String extensionValidee(String nom, byte[] c) {
        if (c == null || c.length < 4) {
            return null;
        }
        // Formats reconnus à leur seule signature, quel que soit le nom
        if (c[0] == '%' && c[1] == 'P' && c[2] == 'D' && c[3] == 'F') {
            return ".pdf";
        }
        if ((c[0] & 0xFF) == 0xFF && (c[1] & 0xFF) == 0xD8 && (c[2] & 0xFF) == 0xFF) {
            return ".jpg";
        }
        if ((c[0] & 0xFF) == 0x89 && c[1] == 'P' && c[2] == 'N' && c[3] == 'G') {
            return ".png";
        }

        String ext = extension(nom);
        return switch (ext) {
            case ".docx", ".xlsx", ".odt", ".ods" -> estZip(c) && bureautiqueSansMacro(c) ? ext : null;
            case ".doc", ".xls" -> estOle2(c) ? ext : null;
            case ".rtf" -> c.length >= 5 && new String(c, 0, 5, java.nio.charset.StandardCharsets.US_ASCII)
                    .equals("{\\rtf") ? ext : null;
            case ".txt", ".csv" -> estTexte(c) ? ext : null;
            default -> null;
        };
    }

    private static String extension(String nom) {
        if (nom == null) {
            return "";
        }
        String bas = nom.toLowerCase(Locale.ROOT).strip();
        int point = bas.lastIndexOf('.');
        return point < 0 ? "" : bas.substring(point);
    }

    private static boolean estZip(byte[] c) {
        return c[0] == 'P' && c[1] == 'K' && c[2] == 3 && c[3] == 4;
    }

    /** Ancien format binaire Office (Compound File Binary). */
    private static boolean estOle2(byte[] c) {
        int[] sig = {0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1};
        if (c.length < sig.length) {
            return false;
        }
        for (int i = 0; i < sig.length; i++) {
            if ((c[i] & 0xFF) != sig[i]) {
                return false;
            }
        }
        return true;
    }

    /**
     * Archive Office Open XML ou OpenDocument, sans projet de macros. Seul le répertoire central
     * est lu (rien n'est décompressé), donc une archive piégée ne coûte rien.
     */
    private static boolean bureautiqueSansMacro(byte[] c) {
        Set<String> entrees = entreesZip(c);
        boolean ooxml = entrees.contains("[Content_Types].xml");
        boolean odf = entrees.contains("mimetype");
        boolean macros = entrees.stream().anyMatch(e -> e.toLowerCase(Locale.ROOT).contains("vbaproject")
                || e.toLowerCase(Locale.ROOT).startsWith("basic/"));
        return (ooxml || odf) && !macros;
    }

    private static Set<String> entreesZip(byte[] c) {
        Path temp = null;
        try {
            temp = Files.createTempFile("piece-kyc", ".zip");
            Files.write(temp, c);
            try (ZipFile zip = new ZipFile(temp.toFile())) {
                return zip.stream().map(ZipEntry::getName).collect(Collectors.toSet());
            }
        } catch (IOException e) {
            return Collections.emptySet();
        } finally {
            if (temp != null) {
                try {
                    Files.deleteIfExists(temp);
                } catch (IOException ignore) {
                    // fichier temporaire : le système le nettoiera
                }
            }
        }
    }

    /** Texte brut : aucun octet de contrôle hors tabulation, retours à la ligne et saut de page. */
    private static boolean estTexte(byte[] c) {
        for (byte b : c) {
            int v = b & 0xFF;
            if (v < 0x20 && v != '\t' && v != '\n' && v != '\r' && v != '\f') {
                return false;
            }
            if (v == 0x7F) {
                return false;
            }
        }
        return true;
    }
}
