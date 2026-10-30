package ml.dogo.groupeachat.application;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import ml.dogo.groupeachat.persistence.GroupeAchatRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.annotation.Profile;
import org.springframework.context.event.EventListener;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Amorçage initial des groupes de démonstration et des grossistes internationaux
 * au démarrage si aucun groupe n'existe en base de données.
 * Aligne les données de la plateforme sur les corridors réels (CI, SN, MA, GH, CN, TR, BR).
 *
 * <p>Profil « demo » uniquement : ces comptes fictifs (mot de passe 1234) n'ont rien à faire en production. Leurs numéros
 * (+2237110000x, +22372100001) sont distincts de ceux de {@code ChargeurDemo} (+22371000001, +22372000001) : les deux
 * chargeurs s'exécutent au même événement, dans un ordre non garanti, et ne doivent jamais se disputer un compte.
 * Chaque produit reçoit une variante (RG-12), sans laquelle aucun commerçant ne pourrait rejoindre son groupe.
 */
@Profile("demo")
@Component
public class AmorcageGroupesDemo {

    private static final Logger LOG = LoggerFactory.getLogger(AmorcageGroupesDemo.class);

    private final GroupeAchatRepository groupes;
    private final JdbcTemplate jdbc;
    private final PasswordEncoder encodeur;

    public AmorcageGroupesDemo(GroupeAchatRepository groupes, JdbcTemplate jdbc, PasswordEncoder encodeur) {
        this.groupes = groupes;
        this.jdbc = jdbc;
        this.encodeur = encodeur;
    }

    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void amorcerSiVide() {
        if (groupes.count() > 0) {
            return;
        }

        LOG.info("Amorçage des groupes Karavan et des grossistes internationaux...");
        Instant maintenant = Instant.now();
        String hashPin = encodeur.encode("1234");

        // 1. Création des grossistes
        long gAliou = creerGrossiste("+22371100001", "Aliou Traoré", "Comptoir d'Abidjan", "CI-ABJ-001", hashPin, maintenant.minus(12, ChronoUnit.HOURS));
        long gFatou = creerGrossiste("+22371100002", "Fatou Sow", "Dakar Import-Export", "SN-DKR-002", hashPin, maintenant.minus(18, ChronoUnit.HOURS));
        long gAhmed = creerGrossiste("+22371100003", "Ahmed Diallo", "Atlas Marchandises Casablanca", "MA-CAS-003", hashPin, maintenant.minus(24, ChronoUnit.HOURS));
        long gKoffi = creerGrossiste("+22371100004", "Koffi Mensah", "Accra Trade Hub", "GH-ACC-004", hashPin, maintenant.minus(36, ChronoUnit.HOURS));
        long gLiWei = creerGrossiste("+22371100005", "Li Wei", "Guangzhou Sourcing Direct", "CN-CAN-005", hashPin, maintenant.minus(48, ChronoUnit.HOURS));
        long gMehmet = creerGrossiste("+22371100006", "Mehmet Yilmaz", "Istanbul Bosphore Textile", "TR-IST-006", hashPin, maintenant.minus(60, ChronoUnit.HOURS));
        long gCarlos = creerGrossiste("+22371100007", "Carlos Silva", "São Paulo Couros & Moda", "BR-SAO-007", hashPin, maintenant.minus(72, ChronoUnit.HOURS));

        // 2. Création d'un courtier
        long courtierId = creerCourtier("+22372100001", "Transit Express Mali", "LIC-TR-2026-01", hashPin, maintenant.minus(90, ChronoUnit.HOURS));

        // 3. Création de quelques commerçants pour l'activité récente
        creerCommercant("+22375000001", "Mamadou Keita", "Boutique Keita Grand Marché", hashPin, maintenant.minus(1, ChronoUnit.HOURS));
        creerCommercant("+22375000002", "Awa Diarra", "Awa Mode & Tissus Bamako", hashPin, maintenant.minus(2, ChronoUnit.HOURS));

        // 4. Catégories existantes : 1=Chaussures, 2=Vêtements, 3=Électronique, 4=Maison
        long catChaussures = 1;
        long catVetements = 2;
        long catMaison = 4;

        // 5. Création des produits avec photo et pays d'origine
        long pWax = creerProduit(gAliou, catVetements, "Wax Super Bazin Rich", "Véritable tissu Wax Bazin riche 100% coton teinté", "CI", "assets/images/wax.jpg", 15000);
        long pCajou = creerProduit(gFatou, catMaison, "Noix de Cajou & Épices Sahéliennes", "Noix de cajou de Casamance de premier choix", "SN", "assets/images/cajou.jpg", 6000);
        long pArgan = creerProduit(gAhmed, catMaison, "Huile d'Argan Cosmétique Bio", "Flacons 250ml d'huile d'argan pure pressée à froid", "MA", "assets/images/argan.jpg", 10000);
        long pKarite = creerProduit(gKoffi, catMaison, "Beurre de Karité & Cacao Pur", "Pots de karité brut naturel et poudre de cacao ghanéen", "GH", "assets/images/cacao.jpg", 7500);
        long pSneakers = creerProduit(gLiWei, catChaussures, "Sneakers Running Pro Sport", "Chaussures de sport respirantes semelle amortissante", "CN", "assets/images/sneakers.jpg", 18000);
        long pChemises = creerProduit(gMehmet, catVetements, "Chemises & Polos Coton Premium", "Chemises habillées et polos coton mercerisé d'Istanbul", "TR", "assets/images/chemises.jpg", 12000);
        long pCuir = creerProduit(gCarlos, catChaussures, "Chaussures Cuir Véritable Artisanal", "Mocassins et sandales cuir tanné artisanal brésilien", "BR", "assets/images/cuir.jpg", 25000);

        // 6. Création des groupes d'achats avec code pays ISO
        creerGroupe(8421L, gAliou, courtierId, pWax, "Wax Super Bazin Rich", "CI", 500, 380, 40, 18500, maintenant.minus(12, ChronoUnit.MINUTES), maintenant.plus(15, ChronoUnit.DAYS));
        creerGroupe(8419L, gFatou, courtierId, pCajou, "Noix de Cajou & Épices", "SN", 300, 210, 30, 7500, maintenant.minus(25, ChronoUnit.MINUTES), maintenant.plus(10, ChronoUnit.DAYS));
        creerGroupe(8418L, gAhmed, courtierId, pArgan, "Huile d'Argan Cosmétique Bio", "MA", 250, 190, 25, 12000, maintenant.minus(42, ChronoUnit.MINUTES), maintenant.plus(12, ChronoUnit.DAYS));
        creerGroupe(8417L, gKoffi, courtierId, pKarite, "Beurre de Karité & Cacao", "GH", 400, 290, 35, 9000, maintenant.minus(65, ChronoUnit.MINUTES), maintenant.plus(18, ChronoUnit.DAYS));
        creerGroupe(8422L, gLiWei, courtierId, pSneakers, "Sneakers Running Pro Sport", "CN", 600, 520, 50, 22000, maintenant.minus(2, ChronoUnit.HOURS), maintenant.plus(20, ChronoUnit.DAYS));
        creerGroupe(8423L, gMehmet, courtierId, pChemises, "Chemises & Polos Coton", "TR", 350, 240, 30, 14500, maintenant.minus(3, ChronoUnit.HOURS), maintenant.plus(14, ChronoUnit.DAYS));
        creerGroupe(8420L, gCarlos, courtierId, pCuir, "Chaussures Cuir Artisanal", "BR", 200, 140, 20, 32000, maintenant.minus(5, ChronoUnit.HOURS), maintenant.plus(22, ChronoUnit.DAYS));

        LOG.info("Amorçage des groupes Karavan terminé avec succès.");
    }

    private long creerGrossiste(String tel, String nom, String nomBoutique, String nif, String hashPin, Instant date) {
        Long idExistant = trouverIdParTel(tel);
        if (idExistant != null) return idExistant;

        jdbc.update(
            "INSERT INTO utilisateur (telephone, nom, mot_de_passe_hash, role_id, date_creation, statut_compte, telephone_verifie, type_acteur) " +
            "VALUES (?, ?, ?, 2, ?, 'ACTIF', 1, 'GROSSISTE')",
            tel, nom, hashPin, Timestamp.from(date)
        );
        long uid = jdbc.queryForObject("SELECT id FROM utilisateur WHERE telephone = ?", Long.class, tel);
        jdbc.update(
            "INSERT INTO grossiste (utilisateur_id, nom_boutique_marche, numero_nif, registre_commerce, note_fiabilite) " +
            "VALUES (?, ?, ?, ?, 4.8)",
            uid, nomBoutique, nif, "RC-" + nif
        );
        return uid;
    }

    private long creerCourtier(String tel, String nom, String licence, String hashPin, Instant date) {
        Long idExistant = trouverIdParTel(tel);
        if (idExistant != null) return idExistant;

        jdbc.update(
            "INSERT INTO utilisateur (telephone, nom, mot_de_passe_hash, role_id, date_creation, statut_compte, telephone_verifie, type_acteur) " +
            "VALUES (?, ?, ?, 3, ?, 'ACTIF', 1, 'COURTIER')",
            tel, nom, hashPin, Timestamp.from(date)
        );
        long uid = jdbc.queryForObject("SELECT id FROM utilisateur WHERE telephone = ?", Long.class, tel);
        jdbc.update(
            "INSERT INTO courtier (utilisateur_id, nom_societe_import, licence_transit, note_fiabilite) " +
            "VALUES (?, ?, ?, 4.9)",
            uid, nom, licence
        );
        return uid;
    }

    private long creerCommercant(String tel, String nom, String boutique, String hashPin, Instant date) {
        Long idExistant = trouverIdParTel(tel);
        if (idExistant != null) return idExistant;

        jdbc.update(
            "INSERT INTO utilisateur (telephone, nom, mot_de_passe_hash, role_id, date_creation, statut_compte, telephone_verifie, type_acteur) " +
            "VALUES (?, ?, ?, 1, ?, 'ACTIF', 1, 'COMMERCANT')",
            tel, nom, hashPin, Timestamp.from(date)
        );
        long uid = jdbc.queryForObject("SELECT id FROM utilisateur WHERE telephone = ?", Long.class, tel);
        jdbc.update(
            "INSERT INTO commercant (utilisateur_id, nom_boutique, quartier_bamako, canal_vente) " +
            "VALUES (?, ?, 'Grand Marché', 'BOUTIQUE_PHYSIQUE')",
            uid, boutique
        );
        return uid;
    }

    private Long trouverIdParTel(String tel) {
        try {
            return jdbc.queryForObject("SELECT id FROM utilisateur WHERE telephone = ?", Long.class, tel);
        } catch (Exception e) {
            return null;
        }
    }

    private long creerProduit(long grossisteId, long categorieId, String nom, String description, String pays, String photo, double prixGros) {
        jdbc.update(
            "INSERT INTO produit (grossiste_id, categorie_id, nom_produit, description, pays_origine, photo_url, prix_gros) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            grossisteId, categorieId, nom, description, pays, photo, BigDecimal.valueOf(prixGros)
        );
        long produitId = jdbc.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        // RG-12 : un produit a au moins une variante (une participation désigne toujours une variante)
        jdbc.update("INSERT INTO variante_produit (produit_id, sku, taille, couleur, qte_disponible) VALUES (?, ?, NULL, NULL, 1000)",
                produitId, "DEMO-" + pays + "-" + produitId);
        return produitId;
    }

    private void creerGroupe(long idSpecifique, long grossisteId, long courtierId, long produitId, String titre, String paysCode,
                             int cible, int confirme, int reserve, double prix, Instant debut, Instant fin) {
        jdbc.update(
            "INSERT INTO groupe_achat (id, grossiste_id, courtier_id, produit_id, titre, pays_origine_code, " +
            "quantite_cible, quantite_confirmee, quantite_reservee, prix_unitaire, date_ouverture, date_limite, statut, disponibilite_validee, version) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'OUVERT', 1, 0)",
            idSpecifique, grossisteId, courtierId, produitId, titre, paysCode,
            cible, confirme, reserve, BigDecimal.valueOf(prix), Timestamp.from(debut), Timestamp.from(fin)
        );

        jdbc.update(
            "INSERT INTO grille_tarifaire (groupe_id, prix_marchandise, transport, frais_plateforme, douane, autres, devise, taux_commission) " +
            "VALUES (?, ?, 1500, 1000, 1000, 500, 'XOF', 0.05)",
            idSpecifique, BigDecimal.valueOf(prix - 4000)
        );

        jdbc.update(
            "INSERT INTO condition_commerciale (groupe_id, delai_livraison_jours, politique_annulation, quantite_min_par_commercant) " +
            "VALUES (?, 21, 'Remboursement intégral sous séquestre garanti', 1)",
            idSpecifique
        );

        jdbc.update(
            "INSERT INTO etape_acheminement (groupe_id, etape, date_signalee, auteur_id, commentaire) " +
            "VALUES (?, 'OUVERT', ?, ?, 'Campagne ouverte aux commerçants de Bamako')",
            idSpecifique, Timestamp.from(debut), grossisteId
        );
    }
}
