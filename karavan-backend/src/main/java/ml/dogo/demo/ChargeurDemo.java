package ml.dogo.demo;

import java.time.Clock;
import java.util.List;
import java.util.function.Function;
import ml.dogo.catalogue.application.CatalogueService;
import ml.dogo.identite.application.CompteService;
import ml.dogo.identite.domain.OperateurMobileMoney;
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
 * Données de démonstration (profil « demo » uniquement) : un grossiste avec un produit en stock, un courtier, trois
 * commerçants avec leur moyen de paiement et deux points de retrait. Aucun administrateur : seul l'administrateur
 * principal (migration V26) existe. Ne fait rien si le grossiste de démo existe déjà. Ce paquet est un outil d'amorçage : aucun module ne dépend de lui.
 */
@Profile("demo")
@Component
public class ChargeurDemo {

    static final String MOT_DE_PASSE = "Dogo2026!";
    static final String ADMINISTRATEUR_PRINCIPAL = "+22375250430";

    private static final Logger LOG = LoggerFactory.getLogger(ChargeurDemo.class);

    private final UtilisateurRepository utilisateurs;
    private final RoleRepository roles;
    private final PasswordEncoder encodeur;
    private final CompteService comptes;
    private final CatalogueService catalogue;
    private final PointRetraitService points;
    private final Clock horloge;
    private final TransactionTemplate transaction;

    public ChargeurDemo(UtilisateurRepository utilisateurs, RoleRepository roles, PasswordEncoder encodeur,
                        CompteService comptes, CatalogueService catalogue,
                        PointRetraitService points, Clock horloge, PlatformTransactionManager gestionnaire) {
        this.utilisateurs = utilisateurs;
        this.roles = roles;
        this.encodeur = encodeur;
        this.comptes = comptes;
        this.catalogue = catalogue;
        this.points = points;
        this.horloge = horloge;
        this.transaction = new TransactionTemplate(gestionnaire);
    }

    @EventListener(ApplicationReadyEvent.class)
    public void charger() {
        if (utilisateurs.existsByTelephone("+22371000001")) {
            LOG.info("Données de démo : déjà chargées, rien à faire");
            return;
        }
        // Aucun administrateur de démo : seul l'administrateur principal (V26) existe, il crée les autres depuis la console
        long principal = utilisateurs.findByTelephone(ADMINISTRATEUR_PRINCIPAL)
                .orElseThrow(() -> new IllegalStateException("Administrateur principal absent : migration V26 non appliquée"))
                .getId();

        long grossisteId = creerCompte(role -> new Grossiste("+22371000001", "Grossiste Demo", encodeur.encode(MOT_DE_PASSE), role,
                horloge.instant(), "Grand Marché de Guangzhou", "NIF-DEMO-001", "RC-DEMO-001"), "GROSSISTE");
        long courtierId = creerCompte(role -> new Courtier("+22372000001", "Courtier Demo", encodeur.encode(MOT_DE_PASSE), role, horloge.instant(),
                "Sahel Import", "LT-DEMO-001", "Dépôt de Badalabougou"), "COURTIER");
        comptes.ajouterMoyen(courtierId, "+22372000001", OperateurMobileMoney.ORANGE_MONEY, true);
        String[] noms = {"Aminata Traoré", "Moussa Keïta", "Fatoumata Diallo"};
        OperateurMobileMoney[] operateurs = {OperateurMobileMoney.ORANGE_MONEY, OperateurMobileMoney.MOOV_MONEY,
                OperateurMobileMoney.ORANGE_MONEY};
        for (int i = 0; i < noms.length; i++) {
            String telephone = "+2237300000" + (i + 1);
            String nomBoutique = "Boutique " + noms[i].split(" ")[0];
            long id = creerCompte(role -> new Commercant(telephone, nomDe(noms, telephone), encodeur.encode(MOT_DE_PASSE),
                    role, horloge.instant(), nomBoutique, "Bamako", "Hamdallaye", "BOUTIQUE"), "COMMERCANT");
            comptes.ajouterMoyen(id, telephone, operateurs[i], true);
        }

        var categorie = catalogue.categories().get(0);
        catalogue.creer(grossisteId, new CatalogueService.ProduitDemande(categorie.id(), "Baskets Sport Homme",
                "Baskets légères, semelle antidérapante", "Chine", null, List.of(
                new CatalogueService.VarianteDemande("BASK-40-NOIR", "40", "Noir", 500),
                new CatalogueService.VarianteDemande("BASK-42-NOIR", "42", "Noir", 500),
                new CatalogueService.VarianteDemande("BASK-42-BLANC", "42", "Blanc", 300))));

        points.creer(principal, "Dépôt Central Dabanani", "JXJF+76R, Unnamed Road, Bamako", "Dabanani",
                "https://www.google.com/maps/search/?api=1&query=12.630738,-8.026984");
        points.creer(principal, "Point Marché de Dibida", "Marché de Dibida", "Dibida");

        LOG.info("""
                Données de démo chargées (Mot de passe de tous les comptes : {})
                  grossiste    : +22371000001
                  courtier     : +22372000001
                  commerçants  : +22373000001 / 002 / 003""", MOT_DE_PASSE);
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
