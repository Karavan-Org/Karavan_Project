package ml.dogo.identite.application;

import java.math.BigDecimal;
import java.time.Instant;
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
                                String photoUrl, Map<String, Object> details) {
    }

    public record MoyenVue(long id, String numero, String operateur, boolean parDefaut) {
    }

    public record CommercantVue(long id, String telephone, String nom, String statut, String photoUrl, String nomBoutique,
                                String adresseLivraison, String quartierBamako, String canalVente,
                                Instant dateCreation) {
    }

    public record GrossisteVue(long id, String telephone, String nom, String statut, String photoUrl, String nomBoutiqueMarche,
                               String numeroNif, String registreCommerce, BigDecimal noteFiabilite,
                               Instant dateCreation) {
    }

    public record CourtierVue(long id, String telephone, String nom, String statut, String photoUrl, String nomSocieteImport,
                              String licenceTransit, String adresseDepot, BigDecimal noteFiabilite,
                              Instant dateCreation) {
    }

    public record AdministrateurVue(long id, String telephone, String nom, String statut, String photoUrl, String matricule,
                                    String roleAdministratif, Instant dateCreation) {
    }

    public record SupervisionStatsVue(long totalCommercants, long totalGrossistes, long totalCourtiers,
                                      long totalAdministrateurs) {
    }

    private final UtilisateurRepository utilisateurs;
    private final MoyenPaiementRepository moyens;
    private final DossierKycRepository dossiers;
    private final SessionService sessions;
    private final RefreshTokenService refreshTokenService;
    private final StockageAvatarService avatarService;
    private final org.springframework.security.crypto.password.PasswordEncoder encodeur;
    private final AuditApi audit;
    private final NotificationApi notifications;

    public CompteService(UtilisateurRepository utilisateurs, MoyenPaiementRepository moyens,
                         DossierKycRepository dossiers, SessionService sessions,
                         RefreshTokenService refreshTokenService,
                         StockageAvatarService avatarService,
                         org.springframework.security.crypto.password.PasswordEncoder encodeur,
                         AuditApi audit, NotificationApi notifications) {
        this.utilisateurs = utilisateurs;
        this.moyens = moyens;
        this.dossiers = dossiers;
        this.sessions = sessions;
        this.refreshTokenService = refreshTokenService;
        this.avatarService = avatarService;
        this.encodeur = encodeur;
        this.audit = audit;
        this.notifications = notifications;
    }

    // ------------------------------------------------------------------ profil

    @Transactional
    public ProfilComplet profil(long utilisateurId) {
        Utilisateur u = charger(utilisateurId);
        if (!u.typeActeur().exigeKyc() && u.isTelephoneVerifie() && u.getStatutCompte() == StatutCompte.EN_ATTENTE) {
            u.changerStatut(StatutCompte.ACTIF);
            utilisateurs.save(u);
        }
        return versProfil(u);
    }

    public record CommandeModificationProfil(
            String nom,
            String langue,
            String photoUrl,
            String nomBoutique,
            String nomBoutiqueMarche,
            String nomSocieteImport,
            String quartierBamako,
            String adresseLivraison,
            String adresseDepot,
            Double latitude,
            Double longitude
    ) {
    }

    @Transactional
    public ProfilComplet modifierProfil(long utilisateurId, String nom, String langue) {
        return modifierProfil(utilisateurId, nom, langue, null);
    }

    @Transactional
    public ProfilComplet modifierProfil(long utilisateurId, String nom, String langue, String photoUrl) {
        return modifierProfil(utilisateurId, new CommandeModificationProfil(
                nom, langue, photoUrl, null, null, null, null, null, null, null, null));
    }

    @Transactional
    public ProfilComplet modifierProfil(long utilisateurId, CommandeModificationProfil r) {
        Utilisateur u = charger(utilisateurId);
        if (r.langue() != null && !r.langue().isBlank() && !List.of("fr", "bm", "en").contains(r.langue())) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, null, "Langue acceptée : fr, bm, en");
        }
        if (r.nom() != null && !r.nom().isBlank()) {
            u.modifierIdentite(r.nom().strip(), r.langue() != null && !r.langue().isBlank() ? r.langue().strip() : u.getLangue());
        } else if (r.langue() != null && !r.langue().isBlank()) {
            u.modifierIdentite(u.getNom(), r.langue().strip());
        }
        if (r.photoUrl() != null) {
            u.modifierPhoto(r.photoUrl().isBlank() ? null : r.photoUrl().strip());
        }

        String boutiqueOuStructure = r.nomBoutique() != null ? r.nomBoutique()
                : (r.nomBoutiqueMarche() != null ? r.nomBoutiqueMarche() : r.nomSocieteImport());

        if (u instanceof Commercant c) {
            if (boutiqueOuStructure != null && !boutiqueOuStructure.isBlank()) {
                c.setNomBoutique(boutiqueOuStructure.strip());
            }
            if (r.quartierBamako() != null) {
                c.setQuartierBamako(r.quartierBamako().strip());
            }
            if (r.adresseLivraison() != null) {
                c.setAdresseLivraison(r.adresseLivraison().strip());
            }
            if (r.latitude() != null) {
                c.setLatitude(r.latitude());
            }
            if (r.longitude() != null) {
                c.setLongitude(r.longitude());
            }
        } else if (u instanceof Grossiste g) {
            if (boutiqueOuStructure != null && !boutiqueOuStructure.isBlank()) {
                g.setNomBoutiqueMarche(boutiqueOuStructure.strip());
            }
            if (r.quartierBamako() != null) {
                g.setQuartierMarche(r.quartierBamako().strip());
            }
            if (r.latitude() != null) {
                g.setLatitude(r.latitude());
            }
            if (r.longitude() != null) {
                g.setLongitude(r.longitude());
            }
        } else if (u instanceof Courtier courtier) {
            if (boutiqueOuStructure != null && !boutiqueOuStructure.isBlank()) {
                courtier.setNomSocieteImport(boutiqueOuStructure.strip());
            }
            if (r.adresseDepot() != null) {
                courtier.setAdresseDepot(r.adresseDepot().strip());
            } else if (r.quartierBamako() != null) {
                courtier.setAdresseDepot(r.quartierBamako().strip());
            }
            if (r.latitude() != null) {
                courtier.setLatitude(r.latitude());
            }
            if (r.longitude() != null) {
                courtier.setLongitude(r.longitude());
            }
        }

        utilisateurs.save(u);
        return versProfil(u);
    }

    @Transactional
    public String enregistrerPhotoProfil(long utilisateurId, org.springframework.web.multipart.MultipartFile fichier) {
        Utilisateur u = charger(utilisateurId);
        String url = avatarService.stockerPhotoProfil(fichier, utilisateurId);
        u.modifierPhoto(url);
        utilisateurs.save(u);
        audit.tracer(utilisateurId, "PHOTO_PROFIL_MODIFIEE", "url=" + url, null);
        return url;
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
        refreshTokenService.revoquerPourUtilisateur(cibleId);
        audit.tracer(administrateurId, "COMPTE_SUSPENDU", "utilisateur=" + cibleId, "motif=" + motif);
        notifications.notifier(cibleId, "Votre compte Karavan a été suspendu. Contactez le support.");
    }

    @Transactional
    public void changerMotDePasse(long utilisateurId, String ancienMdp, String nouveauMdp) {
        Utilisateur u = charger(utilisateurId);
        boolean motDePasseValide = !u.hasMotDePasse() || (ancienMdp != null && encodeur.matches(ancienMdp, u.getMotDePasseHash()));
        if (!motDePasseValide) {
            throw new ErreurMetier(CodeErreur.NON_AUTHENTIFIE, "RG-07", "Ancien mot de passe incorrect");
        }
        if (nouveauMdp == null || nouveauMdp.isBlank() || nouveauMdp.length() < 4) {
            throw new ErreurMetier(CodeErreur.DONNEES_INVALIDES, "RG-07", "Le nouveau code doit comporter au moins 4 caractères");
        }
        u.changerMotDePasse(encodeur.encode(nouveauMdp));
        utilisateurs.save(u);
        sessions.invaliderToutes(utilisateurId);
        refreshTokenService.revoquerPourUtilisateur(utilisateurId);
        audit.tracer(utilisateurId, "MOT_DE_PASSE_MODIFIE", "utilisateur=" + utilisateurId, null);
        notifications.notifier(utilisateurId, "Votre mot de passe a été modifié avec succès.");
    }

    /** Un compte qui exige un KYC ne redevient actif que si un dossier a été approuvé (RG-03). */
    @Transactional
    public void reactiver(long administrateurId, long cibleId) {
        Utilisateur u = charger(cibleId);
        if (u.typeActeur().exigeKyc()
                && !dossiers.existsByUtilisateurIdAndStatut(cibleId, StatutValidation.APPROUVE)) {
            throw new ErreurMetier(CodeErreur.CONFLIT, "RG-03", "Aucun dossier KYC approuvé pour ce compte : validez d'abord son dossier (Valider le compte)");
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

    @Transactional(readOnly = true)
    public List<CommercantVue> listerCommercants() {
        return utilisateurs.tousLesCommercants().stream()
                .map(c -> new CommercantVue(c.getId(), c.getTelephone(), c.getNom(), c.getStatutCompte().name(),
                        c.getPhotoUrl(), c.getNomBoutique(), c.getAdresseLivraison(), c.getQuartierBamako(), c.getCanalVente(),
                        c.getDateCreation()))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<GrossisteVue> listerGrossistes() {
        return utilisateurs.tousLesGrossistes().stream()
                .map(g -> new GrossisteVue(g.getId(), g.getTelephone(), g.getNom(), g.getStatutCompte().name(),
                        g.getPhotoUrl(), g.getNomBoutiqueMarche(), g.getNumeroNif(), g.getRegistreCommerce(), g.getNoteFiabilite(),
                        g.getDateCreation()))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<CourtierVue> listerCourtiers() {
        return utilisateurs.tousLesCourtiers().stream()
                .map(c -> new CourtierVue(c.getId(), c.getTelephone(), c.getNom(), c.getStatutCompte().name(),
                        c.getPhotoUrl(), c.getNomSocieteImport(), c.getLicenceTransit(), c.getAdresseDepot(), c.getNoteFiabilite(),
                        c.getDateCreation()))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<AdministrateurVue> listerAdministrateurs() {
        return utilisateurs.tousLesAdministrateurs().stream()
                .map(a -> new AdministrateurVue(a.getId(), a.getTelephone(), a.getNom(), a.getStatutCompte().name(),
                        a.getPhotoUrl(), a.getMatriculeAgent(), a.getRoleAdministratif().name(), a.getDateCreation()))
                .toList();
    }

    @Transactional(readOnly = true)
    public SupervisionStatsVue statistiques() {
        return new SupervisionStatsVue(
                utilisateurs.nombreCommercants(),
                utilisateurs.nombreGrossistes(),
                utilisateurs.nombreCourtiers(),
                utilisateurs.nombreAdministrateurs()
        );
    }

    private static ProfilComplet versProfil(Utilisateur u) {
        Map<String, Object> d = new LinkedHashMap<>();
        if (u instanceof Commercant c) {
            d.put("nomBoutique", c.getNomBoutique());
            d.put("adresseLivraison", c.getAdresseLivraison());
            d.put("quartierBamako", c.getQuartierBamako());
            d.put("canalVente", c.getCanalVente());
            d.put("latitude", c.getLatitude());
            d.put("longitude", c.getLongitude());
        } else if (u instanceof Grossiste g) {
            d.put("nomBoutiqueMarche", g.getNomBoutiqueMarche());
            d.put("numeroNif", g.getNumeroNif());
            d.put("registreCommerce", g.getRegistreCommerce());
            d.put("noteFiabilite", g.getNoteFiabilite());
            d.put("quartierMarche", g.getQuartierMarche());
            d.put("latitude", g.getLatitude());
            d.put("longitude", g.getLongitude());
        } else if (u instanceof Courtier c) {
            d.put("nomSocieteImport", c.getNomSocieteImport());
            d.put("licenceTransit", c.getLicenceTransit());
            d.put("adresseDepot", c.getAdresseDepot());
            d.put("noteFiabilite", c.getNoteFiabilite());
            d.put("latitude", c.getLatitude());
            d.put("longitude", c.getLongitude());
        } else if (u instanceof Administrateur a) {
            d.put("matriculeAgent", a.getMatriculeAgent());
            d.put("roleAdministratif", a.getRoleAdministratif().name());
        }
        return new ProfilComplet(u.getId(), u.typeActeur().name(), u.getNom(), u.getTelephone(), u.getLangue(),
                u.getStatutCompte().name(), u.getPhotoUrl(), d);
    }
}
