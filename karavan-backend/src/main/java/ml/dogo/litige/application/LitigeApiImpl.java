package ml.dogo.litige.application;

import java.util.List;
import ml.dogo.litige.api.LitigeApi;
import ml.dogo.litige.persistence.LitigeRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class LitigeApiImpl implements LitigeApi {

    private final LitigeRepository litiges;

    public LitigeApiImpl(LitigeRepository litiges) {
        this.litiges = litiges;
    }

    @Override
    public List<LitigeInfo> lister() {
        return litiges.findAll().stream()
                .map(litige -> new LitigeInfo(
                        litige.getId(),
                        litige.getCommandeId(),
                        litige.getMotif(),
                        litige.getStatut().name(),
                        litige.getDateOuverture(),
                        litige.getDateResolution()))
                .toList();
    }
}
