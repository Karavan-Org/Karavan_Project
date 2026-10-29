package ml.dogo.notification;

import com.fasterxml.jackson.databind.ObjectMapper;
import ml.dogo.notification.application.PasserelleSmsGate;
import ml.dogo.notification.application.PasserelleSmsSimulee;
import ml.dogo.notification.application.SmsGateProperties;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class PasserelleSmsGateTest {

    @Test
    @DisplayName("Quand SMSGate est désactivé, le repli vers la simulation s'exécute")
    void repliVersSimulationQuandDesactive() {
        SmsGateProperties props = new SmsGateProperties(
                false,
                "http://127.0.0.1:9999",
                null,
                "sms",
                "secret",
                "device123",
                1,
                500
        );
        PasserelleSmsSimulee simulee = new PasserelleSmsSimulee();
        PasserelleSmsGate gate = new PasserelleSmsGate(props, simulee, new ObjectMapper());

        boolean resultat = gate.envoyer("+22370123456", "Test OTP 1234");
        assertThat(resultat).isTrue();
    }

    @Test
    @DisplayName("Formatage de numéro malien standard sans préfixe vers +223")
    void formatageNumeroMalien() {
        SmsGateProperties props = new SmsGateProperties(
                false,
                "http://127.0.0.1:9999",
                null,
                "sms",
                "secret",
                "device123",
                1,
                500
        );
        PasserelleSmsGate gate = new PasserelleSmsGate(props, new PasserelleSmsSimulee(), new ObjectMapper());

        // Doit accepter 8 chiffres, avec ou sans +223
        assertThat(gate.envoyer("70123456", "Code 9876")).isTrue();
        assertThat(gate.envoyer("+22370123456", "Code 9876")).isTrue();
    }
}
