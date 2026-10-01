package ml.dogo.finance.persistence;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SequestreRepository extends JpaRepository<Sequestre, Long> {

    Optional<Sequestre> findByPaiementId(Long paiementId);

    @org.springframework.data.jpa.repository.Query("select s from Sequestre s order by s.id desc")
    java.util.List<Sequestre> tousLesSequestres();

    @org.springframework.data.jpa.repository.Query("select coalesce(sum(s.montantBloque), 0) from Sequestre s where s.statut = ml.dogo.finance.domain.StatutSequestre.BLOQUE")
    java.math.BigDecimal montantTotalBloque();
}
