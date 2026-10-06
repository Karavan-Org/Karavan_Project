package ml.dogo.demo;

import java.time.Clock;
import java.util.List;
import java.util.function.Function;
import ml.dogo.catalogue.application.CatalogueService;
import ml.dogo.identite.application.AdministrateurService;
import ml.dogo.identite.application.CompteService;
import ml.dogo.identite.domain.OperateurMobileMoney;
import ml.dogo.identite.domain.RoleAdministratif;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.persistence.Commercant;
import ml.dogo.identite.persistence.Courtier;
import ml.dogo.identite.persistence.Grossiste;
import ml.dogo.identite.persistence.Role;
import ml.dogo.identite.persistence.RoleRepository;
import ml.dogo.identite.persistence.Utilisateur;
import ml.dogo.identite.persistence.UtilisateurRepository;
import ml.dogo.logistique.application.PointRetraitService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.annotation.Profile;
import org.springframework.context.event.EventListener;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Données de démonstration (profil « demo » uniquement) : un administrateur par rôle, un grossiste avec un produit
 * en stock, un courtier, trois commerçants avec leur moyen de paiement et deux points de retrait. Ne fait rien si la
 * base contient déjà un administrateur. Ce paquet est un outil d'amorçage : aucun module ne dépend de lui.
 */
@Profile("demo")
@Component
public class ChargeurDemo {

    static final String PIN = "2580";

    private static final Logger LOG = LoggerFactory.getLogger(ChargeurDemo.class);

    private final UtilisateurRepository utilisateurs;
    private final RoleRepository roles;
    private final PasswordEncoder encodeur;
    private final AdministrateurService administrateurs;
    private final CompteService comptes;
    private final CatalogueService catalogue;
    private final PointRetraitService points;
    private final Clock horloge;
    private final TransactionTemplate transaction;

    public ChargeurDemo(UtilisateurRepository utilisateurs, RoleRepository roles, PasswordEncoder encodeur,
                        AdministrateurService administrateurs, CompteService comptes, CatalogueService catalogue,
                        PointRetraitService points, Clock horloge, PlatformTransactionManager gestionnaire) {
        this.utilisateurs = utilisateurs;
        this.roles = roles;
        this.encodeur = encodeur;
        this.administrateurs = administrateurs;
        this.comptes = comptes;
        this.catalogue = catalogue;
        this.points = points;
        this.horloge = horloge;
        this.transaction = new TransactionTemplate(gestionnaire);
    }

    @EventListener(ApplicationReadyEvent.class)
    public void charger() {
        if (utilisateurs.nombreAdministrateurs() > 0) {
            LOG.info("Données de démo : la base contient déjà des administrateurs, rien à charger");
            return;
        }
        long technique = administrateurs.creerInitial("+22370000001", "Admin Technique", PIN, "ADM-0001", RoleAdministratif.TECHNIQUE);
        administrateurs.creerInitial("+22370000002", "Admin Validation", PIN, "ADM-0002", RoleAdministratif.VALIDATION);
        administrateurs.creerInitial("+22370000003", "Admin Finance", PIN, "ADM-0003", RoleAdministratif.FINANCE);
        administrateurs.creerInitial("+22370000004", "Admin Support", PIN, "ADM-0004", RoleAdministratif.SUPPORT);

        long grossisteId = creerCompte(role -> new Grossiste("+22371000001", "Grossiste Demo", encodeur.encode(PIN), role,
                horloge.instant(), "Grand Marché de Guangzhou", "NIF-DEMO-001", "RC-DEMO-001"), "GROSSISTE");
        long courtierId = creerCompte(role -> new Courtier("+22372000001", "Courtier Demo", encodeur.encode(PIN), role, horloge.instant(),
                "Sahel Import", "LT-DEMO-001", "Dépôt de Badalabougou"), "COURTIER");
        comptes.ajouterMoyen(courtierId, "+22372000001", OperateurMobileMoney.ORANGE_MONEY, true);
        String[] noms = {"Aminata Traoré", "Moussa Keïta", "Fatoumata Diallo"};
        OperateurMobileMoney[] operateurs = {OperateurMobileMoney.ORANGE_MONEY, OperateurMobileMoney.MOOV_MONEY,
                OperateurMobileMoney.ORANGE_MONEY};
        for (int i = 0; i < noms.length; i++) {
            String telephone = "+2237300000" + (i + 1);
            String nomBoutique = "Boutique " + noms[i].split(" ")[0];
            long id = creerCompte(role -> new Commercant(telephone, nomDe(noms, telephone), encodeur.encode(PIN),
                    role, horloge.instant(), nomBoutique, "Bamako", "Hamdallaye", "BOUTIQUE"), "COMMERCANT");
            comptes.ajouterMoyen(id, telephone, operateurs[i], true);
        }

        var categorie = catalogue.categories().get(0);
        catalogue.creer(grossisteId, new CatalogueService.ProduitDemande(categorie.id(), "Baskets Sport Homme",
                "Baskets légères, semelle antidérapante", "Chine", null, List.of(
                new CatalogueService.VarianteDemande("BASK-40-NOIR", "40", "Noir", 500),
                new CatalogueService.VarianteDemande("BASK-42-NOIR", "42", "Noir", 500),
                new CatalogueService.VarianteDemande("BASK-42-BLANC", "42", "Blanc", 300))));

        points.creer(technique, "Dépôt de Badalabougou", "Rue 120, Badalabougou", "Badalabougou");
        points.creer(technique, "Point Marché de Dibida", "Marché de Dibida", "Dibida");

        LOG.info("""
                Données de démo chargées (PIN de tous les comptes : {})
                  admins       : +22370000001 (TECHNIQUE) / 002 (VALIDATION) / 003 (FINANCE) / 004 (SUPPORT)
                  grossiste    : +22371000001
                  courtier     : +22372000001
                  commerçants  : +22373000001 / 002 / 003""", PIN);
    }

    private static String nomDe(String[] noms, String telephone) {
        int index = Integer.parseInt(telephone.substring(telephone.length() - 1)) - 1;
        return noms[index];
    }

    /** Crée un compte déjà vérifié et actif (les comptes de démo n'ont ni OTP ni dossier KYC). */
    private long creerCompte(Function<Role, Utilisateur> fabrique, String nomRole) {
        Long id = transaction.execute(statut -> {
            var role = roles.findByNom(nomRole).orElseThrow(() -> new IllegalStateException("Rôle absent : " + nomRole));
            Utilisateur u = fabrique.apply(role);
            u.marquerTelephoneVerifie();
            u.changerStatut(StatutCompte.ACTIF);
            return utilisateurs.save(u).getId();
        });
        return id;
    }
}
