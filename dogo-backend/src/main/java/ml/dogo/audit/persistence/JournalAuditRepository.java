package ml.dogo.audit.persistence;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface JournalAuditRepository extends JpaRepository<JournalAudit, Long> {

    List<JournalAudit> findAllByOrderByIdAsc();

    @Query("select j from JournalAudit j order by j.id desc")
    List<JournalAudit> dernieres(Pageable page);

    /** Verrouille la ligne « tête » jusqu'à la fin de la transaction et renvoie le dernier hash (RG-67). */
    @Query(value = "SELECT dernier_hash FROM journal_audit_tete WHERE id = 1 FOR UPDATE", nativeQuery = true)
    String verrouillerTete();

    @Modifying
    @Query(value = "UPDATE journal_audit_tete SET dernier_hash = :hash WHERE id = 1", nativeQuery = true)
    void mettreAJourTete(@Param("hash") String hash);
}
