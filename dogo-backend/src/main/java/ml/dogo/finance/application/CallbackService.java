package ml.dogo.finance.application;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import ml.dogo.shared.config.DogoProperties;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

/**
 * Réception des callbacks de l'opérateur (RG-35) : la signature HMAC-SHA256 du corps brut est vérifiée avant tout,
 * puis le traitement transactionnel est délégué. Une contrainte d'unicité sur l'identifiant opérateur rend un callback
 * en double sans effet, même s'il arrive en parallèle du premier.
 */
@Service
public class CallbackService {

    private final DogoProperties proprietes;
    private final ObjectMapper json;
    private final TraitementPaiement traitement;

    public CallbackService(DogoProperties proprietes, ObjectMapper json, TraitementPaiement traitement) {
        this.proprietes = proprietes;
        this.json = json;
        this.traitement = traitement;
    }

    public TraitementPaiement.Resultat traiter(String corps, String signature) {
        if (corps == null || signature == null || !signatureValide(corps, signature)) {
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-35", "Signature du callback invalide");
        }
        TraitementPaiement.Callback callback = lire(corps);
        try {
            return traitement.appliquer(callback, corps);
        } catch (DataIntegrityViolationException e) {
            // Deux callbacks identiques en parallèle : l'autre a gagné, celui-ci est un doublon.
            return TraitementPaiement.Resultat.DOUBLON;
        }
    }

    /** Signature que l'opérateur (ou le simulateur de démonstration) joint au callback. */
    public String signer(String corps) {
        if (corps == null) {
            throw new IllegalArgumentException("Le corps du callback ne peut pas être null");
        }

        String secret = proprietes.mobileMoney().secretCallback();
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("Le secret du callback est absent ou vide");
        }

        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal(corps.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            throw new IllegalStateException(e);
        }
    }

    boolean signatureValide(String corps, String signature) {
        if (corps == null || signature == null) {
            return false;
        }

        String attendue = signer(corps);
        String recue = signature.strip();
        if (recue.isEmpty() || recue.length() != attendue.length()) {
            return false;
        }

        byte[] attenduBytes = attendue.getBytes(StandardCharsets.UTF_8);
        byte[] recuBytes = recue.toLowerCase(java.util.Locale.ROOT).getBytes(StandardCharsets.UTF_8);
        return MessageDigest.isEqual(attenduBytes, recuBytes);
    }

    private TraitementPaiement.Callback lire(String corps) {
        try {
            JsonNode n = json.readTree(corps);
            String montant = texte(n, "montant");
            return new TraitementPaiement.Callback(texte(n, "reference"), texte(n, "txId"), texte(n, "statut"),
                    montant == null ? null : new BigDecimal(montant), texte(n, "operateur"));
        } catch (java.io.IOException | NumberFormatException e) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-35", "Callback illisible");
        }
    }

    private static String texte(JsonNode n, String champ) {
        JsonNode v = n.get(champ);
        if (v == null || v.isNull()) {
            return null;
        }
        return v.asText();
    }
}
