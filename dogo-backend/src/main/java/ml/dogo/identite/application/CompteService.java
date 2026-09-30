package ml.dogo.identite.application;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import ml.dogo.audit.api.AuditApi;
import ml.dogo.identite.domain.OperateurMobileMoney;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.domain.StatutValidation;
import ml.dogo.identite.domain.Telephone;
import ml.dogo.identite.persistence.Administrateur;
import ml.dogo.identite.persistence.Commercant;
import ml.dogo.identite.persistence.Courtier;
import ml.dogo.identite.persistence.DossierKycRepository;
import ml.dogo.identite.persistence.Grossiste;
import ml.dogo.identite.persistence.MoyenPaiementRepository;
import ml.dogo.identite.persistence.MoyenPaiementUtilisateur;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.notification.api.NotificationApi;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Profil, moyens de paiement (RG-10) et suspension / réactivation des comptes (RG-09). */
@Service
public class CompteService {

    public record ProfilComplet(long id, String type, String nom, String telephone, String langue, String statut,
                                Map<String, Object> details) {
    }

    public record MoyenVue(long id, String numero, String operateur, boolean parDefaut) {
    }

    private final UtilisateurRepository utilisateurs;
    private final MoyenPaiementRepository moyens;
    private final DossierKycRepository dossiers;
    private final SessionService sessions;
    private final AuditApi audit;
    private final NotificationApi notifications;

    public CompteService(UtilisateurRepository utilisateurs, MoyenPaiementRepository moyens,
                         DossierKycRepository dossiers, SessionService sessions, AuditApi audit,
                         NotificationApi notifications) {
        this.utilisateurs = utilisateurs;
        this.moyens = moyens;
        this.dossiers = dossiers;
        this.sessions = sessions;
        this.audit = audit;
        this.notifications = notifications;
    }

    // ------------------------------------------------------------------ profil

    @Transactional(readOnly = true)
    public ProfilComplet profil(long utilisateurId) {
        return versProfil(charger(utilisateurId));
    }

    @Transactional
    public ProfilComplet modifierProfil(long utilisateurId, String nom, String langue) {
        Utilisateur u = charger(utilisateurId);
        if (langue != null && !langue.isBlank() && !List.of("fr", "bm", "en").contains(langue)) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, null, "Langue acceptée : fr, bm, en");
        }
        u.modifierIdentite(nom, langue);
        return versProfil(u);
    }

    // ------------------------------------------------------- moyens de paiement

    @Transactional(readOnly = true)
    public List<MoyenVue> moyens(long utilisateurId) {
        return moyens.findByUtilisateurIdOrderByIdAsc(utilisateurId).stream().map(CompteService::vue).toList();
    }

    /** RG-10 : le premier moyen devient le moyen par défaut ; en désigner un nouveau retire l'ancien. */
    @Transactional
    public MoyenVue ajouterMoyen(long utilisateurId, String numeroBrut, OperateurMobileMoney operateur,
                                 boolean parDefaut) {
        if (operateur == null) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-10", "Opérateur obligatoire");
        }
        String numero = Telephone.normaliser(numeroBrut);
        if (moyens.existsByUtilisateurIdAndNumeroMobileMoney(utilisateurId, numero)) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-10", "Ce numéro est déjà enregistré");
        }
        boolean premier = moyens.findByUtilisateurIdOrderByIdAsc(utilisateurId).isEmpty();
        boolean defaut = premier || parDefaut;
        if (defaut && !premier) {
            moyens.retirerDefaut(utilisateurId);
        }
        return vue(moyens.save(new MoyenPaiementUtilisateur(utilisateurId, numero, operateur, defaut)));
    }

    @Transactional
    public MoyenVue definirParDefaut(long utilisateurId, long moyenId) {
        moyens.findByIdAndUtilisateurId(moyenId, utilisateurId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Moyen de paiement", moyenId));
        // retirerDefaut vide le contexte de persistance : on recharge le moyen après.
        moyens.retirerDefaut(utilisateurId);
        MoyenPaiementUtilisateur choisi = moyens.findByIdAndUtilisateurId(moyenId, utilisateurId).orElseThrow();
        choisi.definirParDefaut(true);
        return vue(choisi);
    }

    /** Supprime un moyen ; si c'était le défaut, le plus ancien restant le devient (RG-10). */
    @Transactional
    public void supprimerMoyen(long utilisateurId, long moyenId) {
        MoyenPaiementUtilisateur m = moyens.findByIdAndUtilisateurId(moyenId, utilisateurId)
                .orElseThrow(() -> ErreurMetier.nonTrouve("Moyen de paiement", moyenId));
        boolean etaitDefaut = m.isParDefaut();
        moyens.delete(m);
        moyens.flush();
        if (etaitDefaut) {
            moyens.findByUtilisateurIdOrderByIdAsc(utilisateurId).stream().findFirst()
                    .ifPresent(x -> x.definirParDefaut(true));
        }
    }

    // ------------------------------------------------------------- suspension

    @Transactional
    public void suspendre(long administrateurId, long cibleId, String motif) {
        if (administrateurId == cibleId) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-09", "Un administrateur ne peut pas se suspendre lui-même");
        }
        if (motif == null || motif.isBlank()) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-09", "Un motif est obligatoire");
        }
        Utilisateur u = charger(cibleId);
        u.changerStatut(StatutCompte.SUSPENDU);
        sessions.invaliderToutes(cibleId);
        audit.tracer(administrateurId, "COMPTE_SUSPENDU", "utilisateur=" + cibleId, "motif=" + motif);
        notifications.notifier(cibleId, "Votre compte DoGo a été suspendu. Contactez le support.");
    }

    /** Un compte qui exige un KYC ne redevient actif que si un dossier a été approuvé (RG-03). */
    @Transactional
    public void reactiver(long administrateurId, long cibleId) {
        Utilisateur u = charger(cibleId);
        if (u.typeActeur().exigeKyc()
                && !dossiers.existsByUtilisateurIdAndStatut(cibleId, StatutValidation.APPROUVE)) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-03", "Aucun dossier KYC approuvé pour ce compte");
        }
        u.changerStatut(StatutCompte.ACTIF);
        audit.tracer(administrateurId, "COMPTE_REACTIVE", "utilisateur=" + cibleId, null);
        notifications.notifier(cibleId, "Votre compte DoGo est de nouveau actif.");
    }

    // ------------------------------------------------------------------ utilitaires

    private Utilisateur charger(long id) {
        return utilisateurs.findById(id).orElseThrow(() -> ErreurMetier.nonTrouve("Utilisateur", id));
    }

    private static MoyenVue vue(MoyenPaiementUtilisateur m) {
        return new MoyenVue(m.getId(), m.getNumeroMobileMoney(), m.getOperateur().name(), m.isParDefaut());
    }

    private static ProfilComplet versProfil(Utilisateur u) {
        Map<String, Object> d = new LinkedHashMap<>();
        if (u instanceof Commercant c) {
            d.put("nomBoutique", c.getNomBoutique());
            d.put("adresseLivraison", c.getAdresseLivraison());
            d.put("quartierBamako", c.getQuartierBamako());
            d.put("canalVente", c.getCanalVente());
        } else if (u instanceof Grossiste g) {
            d.put("nomBoutiqueMarche", g.getNomBoutiqueMarche());
            d.put("numeroNif", g.getNumeroNif());
            d.put("registreCommerce", g.getRegistreCommerce());
            d.put("noteFiabilite", g.getNoteFiabilite());
        } else if (u instanceof Courtier c) {
            d.put("nomSocieteImport", c.getNomSocieteImport());
            d.put("licenceTransit", c.getLicenceTransit());
            d.put("adresseDepot", c.getAdresseDepot());
            d.put("noteFiabilite", c.getNoteFiabilite());
        } else if (u instanceof Administrateur a) {
            d.put("matriculeAgent", a.getMatriculeAgent());
            d.put("roleAdministratif", a.getRoleAdministratif().name());
        }
        return new ProfilComplet(u.getId(), u.typeActeur().name(), u.getNom(), u.getTelephone(), u.getLangue(),
                u.getStatutCompte().name(), d);
    }
}
