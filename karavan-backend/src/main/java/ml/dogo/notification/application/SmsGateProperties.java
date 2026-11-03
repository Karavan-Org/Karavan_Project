package ml.dogo.notification.application;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Configuration de la passerelle SMS physique Android (SMSGate / android-sms-gateway).
 * Permet d'envoyer les vrais codes OTP et notifications SMS par la carte SIM du téléphone.
 */
@ConfigurationProperties(prefix = "smsgate")
public record SmsGateProperties(
        boolean actif,
        String localUrl,
        String publicUrl,
        String username,
        String password,
        String deviceId,
        int simNumber,
        int timeoutMs
) {
    public SmsGateProperties {
        if (localUrl == null || localUrl.isBlank()) {
            localUrl = "http://192.168.10.90:8080";
        }
        if (publicUrl == null || publicUrl.isBlank()) {
            publicUrl = "http://154.118.156.78:8080";
        }
        if (username == null || username.isBlank()) {
            username = "sms";
        }
        if (password == null || password.isBlank()) {
            password = "MZKakNJa";
        }
        if (deviceId == null || deviceId.isBlank()) {
            deviceId = "ffffffffa25ede61000001a17e6";
        }
        if (simNumber <= 0) {
            simNumber = 1;
        }
        if (timeoutMs <= 0) {
            timeoutMs = 4000;
        }
    }
}

