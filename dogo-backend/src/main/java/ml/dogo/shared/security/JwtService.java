package ml.dogo.shared.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Collection;
import java.util.Date;
import java.util.List;
import java.util.Optional;
import javax.crypto.SecretKey;
import ml.dogo.shared.config.DogoProperties;
import org.springframework.stereotype.Component;

@Component
public class JwtService {

    public record JetonInfo(long utilisateurId, long sessionId, String type, List<String> permissions) {
    }

    private final SecretKey cle;

    public JwtService(DogoProperties proprietes) {
        byte[] secret = proprietes.jwt().secret().getBytes(StandardCharsets.UTF_8);
        if (secret.length < 32) {
            throw new IllegalStateException("dogo.jwt.secret doit faire au moins 32 caractères");
        }
        this.cle = Keys.hmacShaKeyFor(secret);
    }

    public String generer(long utilisateurId, long sessionId, String type, Collection<String> permissions,
                          Instant maintenant, Instant expiration) {
        return Jwts.builder()
                .subject(String.valueOf(utilisateurId))
                .id(String.valueOf(sessionId))
                .claim("type", type)
                .claim("perm", List.copyOf(permissions))
                .issuedAt(Date.from(maintenant))
                .expiration(Date.from(expiration))
                .signWith(cle)
                .compact();
    }

    @SuppressWarnings("unchecked")
    public Optional<JetonInfo> lire(String jeton) {
        try {
            Claims claims = Jwts.parser().verifyWith(cle).build().parseSignedClaims(jeton).getPayload();
            List<String> permissions = claims.get("perm", List.class);
            return Optional.of(new JetonInfo(Long.parseLong(claims.getSubject()), Long.parseLong(claims.getId()),
                    claims.get("type", String.class), permissions == null ? List.of() : permissions));
        } catch (JwtException | IllegalArgumentException e) {
            return Optional.empty();
        }
    }
}
