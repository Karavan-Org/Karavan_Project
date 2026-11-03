package ml.dogo.logistique.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.stereotype.Service;

/**
 * Service centralisé pour la génération et validation sécurisée des codes QR et codes courts.
 * - Préfixes stricts : KVR. (retrait) et KVC. (colis)
 * - Jeton 128 bits minimum SecureRandom, encodé en base64url sans padding
 * - Hash SHA-256 pour le stockage en base et la recherche
 * - Chiffrement AES-GCM pour l'étiquette colis (jamais en clair)
 * - Limitation des tentatives par agent et par IP (protection contre le brute-force)
 */
@Service
public class QrSecuriteService {

    public static final String PREFIXE_RETRAIT = "KVR.";
    public static final String PREFIXE_COLIS = "KVC.";

    private static final SecureRandom ALEA = new SecureRandom();
    private static final int MAX_TENTATIVES_PAR_FENETRE = 10;
    private static final long FENETRE_TENTATIVES_SECONDES = 60;

    private final DogoProperties proprietes;
    private final Map<String, ConcurrentLinkedQueue<Instant>> tentativesParCle = new ConcurrentHashMap<>();

    public QrSecuriteService(DogoProperties proprietes) {
        this.proprietes = proprietes;
    }

    /**
     * Génère un jeton cryptographique 128 bits encodé en base64url avec son préfixe.
     */
    public String genererJeton(String prefixe) {
        byte[] octets = new byte[16];
        ALEA.nextBytes(octets);
        String raw = Base64.getUrlEncoder().withoutPadding().encodeToString(octets);
        return prefixe + raw;
    }

    /**
     * Génère un code court de secours de 8 chiffres décimaux.
     */
    public String genererCodeCourt() {
        int code = ALEA.nextInt(100_000_000);
        return String.format("%08d", code);
    }

    /**
     * Calcule le hash SHA-256 en hexadécimal d'un jeton ou code court.
     */
    public String hasher(String texte) {
        if (texte == null || texte.isBlank()) {
            return null;
        }
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(texte.strip().getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("Algorithme SHA-256 indisponible", e);
        }
    }

    /**
     * Nettoie une chaîne de QR scanné (supprime les espaces, préfixes d'URL éventuels).
     */
    public String nettoyerJeton(String valeur) {
        if (valeur == null || valeur.isBlank()) {
            return null;
        }
        String nettoye = valeur.strip();
        if (nettoye.contains("/")) {
            nettoye = nettoye.substring(nettoye.lastIndexOf('/') + 1).strip();
        }
        if (nettoye.contains(":")) {
            nettoye = nettoye.substring(nettoye.lastIndexOf(':') + 1).strip();
        }
        return nettoye;
    }

    /**
     * Vérifie qu'un jeton présenté pour un retrait n'est pas un QR colis.
     */
    public void verifierTypeRetrait(String jeton) {
        if (jeton != null && jeton.startsWith(PREFIXE_COLIS)) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-QR",
                    "Mauvais type de QR code (QR colis présenté pour un retrait)");
        }
    }

    /**
     * Vérifie qu'un jeton présenté pour une arrivée colis n'est pas un QR retrait.
     */
    public void verifierTypeColis(String jeton) {
        if (jeton != null && jeton.startsWith(PREFIXE_RETRAIT)) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-QR",
                    "Mauvais type de QR code (QR retrait présenté pour un colis)");
        }
    }

    /**
     * Contrôle de limitation des tentatives (rate limiting) pour un acteur ou une IP.
     */
    public void controlerTentatives(String identifiant) {
        if (identifiant == null || identifiant.isBlank()) {
            return;
        }
        Instant maintenant = Instant.now();
        Instant seuil = maintenant.minusSeconds(FENETRE_TENTATIVES_SECONDES);
        ConcurrentLinkedQueue<Instant> historique = tentativesParCle.computeIfAbsent(identifiant, k -> new ConcurrentLinkedQueue<>());
        
        // Nettoyer les tentatives anciennes
        while (!historique.isEmpty() && historique.peek().isBefore(seuil)) {
            historique.poll();
        }

        if (historique.size() >= MAX_TENTATIVES_PAR_FENETRE) {
            throw new ErreurMetier(CodeErreur.ACCES_REFUSE, "RG-SEC-RATELIMIT",
                    "Trop de tentatives de validation. Veuillez patienter une minute avant de réessayer.");
        }
    }

    public void enregistrerTentative(String identifiant) {
        if (identifiant == null || identifiant.isBlank()) {
            return;
        }
        ConcurrentLinkedQueue<Instant> historique = tentativesParCle.computeIfAbsent(identifiant, k -> new ConcurrentLinkedQueue<>());
        historique.offer(Instant.now());
    }

    /**
     * Génère une image PNG du QR code en noir sur blanc avec marge blanche et correction d'erreur niveau M.
     */
    public byte[] genererImageQrPng(String contenu, int largeur, int hauteur) {
        try {
            java.util.Map<com.google.zxing.EncodeHintType, Object> hints = new java.util.EnumMap<>(com.google.zxing.EncodeHintType.class);
            hints.put(com.google.zxing.EncodeHintType.ERROR_CORRECTION, com.google.zxing.qrcode.decoder.ErrorCorrectionLevel.M);
            hints.put(com.google.zxing.EncodeHintType.CHARACTER_SET, StandardCharsets.UTF_8.name());
            hints.put(com.google.zxing.EncodeHintType.MARGIN, 2);

            com.google.zxing.qrcode.QRCodeWriter writer = new com.google.zxing.qrcode.QRCodeWriter();
            com.google.zxing.common.BitMatrix bitMatrix = writer.encode(
                    contenu != null ? contenu : "",
                    com.google.zxing.BarcodeFormat.QR_CODE,
                    largeur > 0 ? largeur : 300,
                    hauteur > 0 ? hauteur : 300,
                    hints
            );
            java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
            com.google.zxing.client.j2se.MatrixToImageWriter.writeToStream(bitMatrix, "PNG", out);
            return out.toByteArray();
        } catch (Exception e) {
            throw new RuntimeException("Erreur de génération de l'image QR", e);
        }
    }

    // ---------------- Chiffrement réversible pour l'étiquette colis (AES-GCM) ----------------

    public String chiffrer(String valeurClair) {
        if (valeurClair == null) return null;
        try {
            byte[] iv = new byte[12];
            ALEA.nextBytes(iv);
            byte[] cleBytes = cleDerivee();
            SecretKeySpec cle = new SecretKeySpec(cleBytes, "AES");
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, cle, new GCMParameterSpec(128, iv));
            byte[] chiffre = cipher.doFinal(valeurClair.getBytes(StandardCharsets.UTF_8));
            byte[] total = new byte[iv.length + chiffre.length];
            System.arraycopy(iv, 0, total, 0, iv.length);
            System.arraycopy(chiffre, 0, total, iv.length, chiffre.length);
            return Base64.getEncoder().encodeToString(total);
        } catch (Exception e) {
            throw new RuntimeException("Erreur de chiffrement du jeton", e);
        }
    }

    public String dechiffrer(String valeurChiffree) {
        if (valeurChiffree == null) return null;
        try {
            byte[] total = Base64.getDecoder().decode(valeurChiffree);
            byte[] iv = new byte[12];
            System.arraycopy(total, 0, iv, 0, 12);
            byte[] chiffre = new byte[total.length - 12];
            System.arraycopy(total, 12, chiffre, 0, chiffre.length);
            byte[] cleBytes = cleDerivee();
            SecretKeySpec cle = new SecretKeySpec(cleBytes, "AES");
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, cle, new GCMParameterSpec(128, iv));
            byte[] clair = cipher.doFinal(chiffre);
            return new String(clair, StandardCharsets.UTF_8);
        } catch (Exception e) {
            return null;
        }
    }

    private byte[] cleDerivee() {
        String secret = (proprietes != null && proprietes.jwt() != null && proprietes.jwt().secret() != null)
                ? proprietes.jwt().secret()
                : "KaravanDefaultSecretKeyForQrProtection2026";
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return md.digest(secret.getBytes(StandardCharsets.UTF_8));
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException(e);
        }
    }
}
