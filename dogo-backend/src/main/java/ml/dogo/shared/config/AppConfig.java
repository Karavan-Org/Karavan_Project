package ml.dogo.shared.config;

import java.time.Clock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
@EnableScheduling
public class AppConfig {

    /** Horloge unique, en UTC : remplaçable dans les tests pour figer le temps. */
    @Bean
    public Clock horloge() {
        return Clock.systemUTC();
    }

    /** RG-71 : PIN, OTP et codes de retrait ne sont jamais stockés en clair. */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
