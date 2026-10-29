package ml.dogo.identite.persistence;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    List<RefreshToken> findAllByUtilisateurIdAndRevoqueFalse(Long utilisateurId);

    @Modifying
    @Query("update RefreshToken r set r.revoque = true, r.dateRevocation = :maintenant where r.utilisateurId = :uid and r.revoque = false")
    int revoquerTousPourUtilisateur(@Param("uid") Long utilisateurId, @Param("maintenant") Instant maintenant);

    @Modifying
    @Query("update RefreshToken r set r.revoque = true, r.dateRevocation = :maintenant where r.sessionId = :sessionId and r.revoque = false")
    int revoquerPourSession(@Param("sessionId") Long sessionId, @Param("maintenant") Instant maintenant);

    @Modifying
    @Query("delete from RefreshToken r where r.dateExpiration < :limite or (r.revoque = true and r.dateRevocation < :limite)")
    int purger(@Param("limite") Instant limite);
}

