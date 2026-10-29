package ml.dogo.notification.application;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.List;

/**
 * Implémentation réelle de {@link PasserelleSms} connectée à l'application Android SMSGate.
 * Émet les SMS physiques (codes OTP de vérification, alertes de commandes) directement
 * depuis le smartphone de l'administrateur via sa carte SIM locale.
 */
@Component
@Primary
public class PasserelleSmsGate implements PasserelleSms {

    private static final Logger LOG = LoggerFactory.getLogger(PasserelleSmsGate.class);

    private final SmsGateProperties properties;
    private final PasserelleSmsSimulee fallback;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;

    public PasserelleSmsGate(SmsGateProperties properties, PasserelleSmsSimulee fallback, ObjectMapper objectMapper) {
        this.properties = properties;
        this.fallback = fallback;
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(properties.timeoutMs()))
                .build();
    }

    @Override
    public boolean envoyer(String telephoneBrut, String message) {
        if (!properties.actif()) {
            LOG.info("📱 [SMSGate DÉSACTIVÉ] Utilisation de la simulation locale pour {}", telephoneBrut);
            return fallback.envoyer(telephoneBrut, message);
        }

        String telephone = formaterTelephone(telephoneBrut);

        // 1. Essai sur l'adresse locale Wi-Fi (ex: http://192.168.11.15:8080)
        boolean envoye = tenterEnvoiSurUrl(properties.localUrl(), telephone, message, "Local Wi-Fi");

        // 2. Si échec ou hors réseau local, essai sur l'adresse publique (ex: http://154.118.156.78:8080)
        if (!envoye && properties.publicUrl() != null && !properties.publicUrl().isBlank()
                && !properties.publicUrl().equalsIgnoreCase(properties.localUrl())) {
            LOG.info("🔄 [SMSGate] Tentative sur l'adresse publique SMSGate : {}", properties.publicUrl());
            envoye = tenterEnvoiSurUrl(properties.publicUrl(), telephone, message, "Public");
        }

        // 3. Repli automatique en journalisation si le téléphone est déconnecté ou éteint
        if (!envoye) {
            LOG.warn("⚠️ [SMSGate INDISPONIBLE] Impossible de joindre le téléphone Android sur {} ou {}. " +
                     "Repli sur les logs pour ne pas bloquer l'OTP.", properties.localUrl(), properties.publicUrl());
            fallback.envoyer(telephoneBrut, message);
        }

        return true;
    }

    private boolean tenterEnvoiSurUrl(String baseUrl, String telephone, String message, String contexte) {
        if (baseUrl == null || baseUrl.isBlank()) {
            return false;
        }

        try {
            String url = baseUrl.replaceAll("/+$", "") + "/message";

            SmsGatePayload payload = new SmsGatePayload(
                    List.of(telephone),
                    new SmsGatePayload.TextMessage(message),
                    properties.simNumber()
            );

            String corpsJson = objectMapper.writeValueAsString(payload);

            String authIdentifiants = properties.username() + ":" + properties.password();
            String authHeader = "Basic " + Base64.getEncoder().encodeToString(authIdentifiants.getBytes(StandardCharsets.UTF_8));

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofMillis(properties.timeoutMs()))
                    .header("Content-Type", "application/json")
                    .header("Authorization", authHeader)
                    .POST(HttpRequest.BodyPublishers.ofString(corpsJson, StandardCharsets.UTF_8))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));

            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                LOG.info("✅ [SMSGate SUCCÈS - {}] SMS envoyé avec succès à {} ! Réponse : {}",
                        contexte, telephone, response.body());
                return true;
            } else {
                LOG.warn("❌ [SMSGate ERREUR - {}] Code HTTP {} reçu de {} : {}",
                        contexte, response.statusCode(), url, response.body());
                return false;
            }
        } catch (Exception e) {
            LOG.warn("⚠️ [SMSGate TIMEOUT/ERREUR - {}] Impossible de contacter {} : {}",
                    contexte, baseUrl, e.getMessage());
            return false;
        }
    }

    private String formaterTelephone(String telephoneBrut) {
        if (telephoneBrut == null) return "";
        String s = telephoneBrut.replaceAll("[\\s.\\-()]", "");
        if (s.startsWith("+")) {
            return s;
        }
        if (s.startsWith("00")) {
            return "+" + s.substring(2);
        }
        if (s.length() == 8) {
            return "+223" + s;
        }
        if (s.startsWith("223") && s.length() == 11) {
            return "+" + s;
        }
        return "+" + s;
    }

    public record SmsGatePayload(
            List<String> phoneNumbers,
            TextMessage textMessage,
            int simNumber
    ) {
        public record TextMessage(String text) {}
    }
}
