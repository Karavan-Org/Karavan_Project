package ml.dogo.finance.persistence;

import org.springframework.data.jpa.repository.JpaRepository;

public interface TransactionMobileMoneyRepository extends JpaRepository<TransactionMobileMoney, Long> {

    boolean existsByTxId(String txId);
}
