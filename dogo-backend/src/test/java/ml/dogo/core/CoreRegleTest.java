package ml.dogo.core;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import ml.dogo.groupeachat.domain.CalculPrix;
import ml.dogo.groupeachat.domain.StatutGroupe;
import ml.dogo.finance.domain.MotifRemboursement;
import ml.dogo.finance.domain.RegleFinance;
import ml.dogo.finance.domain.StatutPaiement;
import ml.dogo.finance.domain.StatutRemboursement;
import ml.dogo.finance.domain.StatutSequestre;
import ml.dogo.identite.domain.RegleAcces;
import ml.dogo.identite.domain.StatutCompte;
import ml.dogo.identite.domain.Telephone;
import ml.dogo.identite.domain.TypeActeur;
import ml.dogo.identite.domain.TypeDocument;
import ml.dogo.logistique.domain.RegleRetrait;
import ml.dogo.logistique.domain.StatutCommande;
import ml.dogo.participation.domain.StatutParticipation;
import ml.dogo.shared.errors.CodeErreur;
import ml.dogo.shared.errors.ErreurMetier;
import org.junit.jupiter.api.Test;

/** Tests des règles de gestion pures (sans Spring ni base). Chaque test porte le numéro de sa règle. */
class CoreRegleTest {

    private static final Instant T0 = Instant.parse("2026-10-01T10:00:00Z");

    // ---- RG-02 / RG-07 : accès

    @Test
    void rg02_otp_valide_est_accepte() {
        RegleAcces.verifierOtpUtilisable(false, T0.plusSeconds(60), 0, 3, T0);
    }

    @Test
    void rg02_otp_expire_est_refuse() {
        ErreurMetier e = assertThrows(ErreurMetier.class,
                () -> RegleAcces.verifierOtpUtilisable(false, T0.minusSeconds(1), 0, 3, T0));
        assertEquals(CodeErreur.OTP_INVALIDE, e.code());
    }

    @Test
    void rg02_otp_utilise_ou_epuise_est_refuse() {
        assertThrows(ErreurMetier.class, () -> RegleAcces.verifierOtpUtilisable(true, T0.plusSeconds(60), 0, 3, T0));
        assertThrows(ErreurMetier.class, () -> RegleAcces.verifierOtpUtilisable(false, T0.plusSeconds(60), 3, 3, T0));
    }

    @Test
    void rg07_verrouillage_apres_cinq_echecs() {
        assertNull(RegleAcces.verrouillageApres(4, 5, Duration.ofMinutes(15), T0));
        assertEquals(T0.plus(Duration.ofMinutes(15)), RegleAcces.verrouillageApres(5, 5, Duration.ofMinutes(15), T0));
        assertThrows(ErreurMetier.class, () -> RegleAcces.verifierNonVerrouille(T0.plusSeconds(10), T0));
        RegleAcces.verifierNonVerrouille(T0.minusSeconds(10), T0);
    }

    // ---- RG-19 : moteur d'états du groupe

    @Test
    void rg01_telephone_est_normalise_au_format_malien() {
        assertEquals("+22376123456", Telephone.normaliser("76 12 34 56"));
        assertEquals("+22376123456", Telephone.normaliser("+223 76-12-34-56"));
        assertEquals("+22376123456", Telephone.normaliser("0022376123456"));
        assertEquals("+22376123456", Telephone.normaliser("22376123456"));
        assertEquals("+22322312345", Telephone.normaliser("22312345"));
    }

    @Test
    void rg01_telephone_invalide_est_refuse() {
        for (String mauvais : new String[]{null, "", "7612345", "761234567", "abcdefgh", "+3311234567"}) {
            ErreurMetier e = assertThrows(ErreurMetier.class, () -> Telephone.normaliser(mauvais));
            assertEquals(CodeErreur.DONNEES_INVALIDES, e.code());
        }
    }

    @Test
    void rg03_seuls_grossiste_et_courtier_exigent_un_kyc() {
        assertFalse(TypeActeur.COMMERCANT.exigeKyc());
        assertTrue(TypeActeur.GROSSISTE.exigeKyc());
        assertTrue(TypeActeur.COURTIER.exigeKyc());
        assertFalse(TypeActeur.ADMINISTRATEUR.exigeKyc());
    }

    @Test
    void rg04_documents_obligatoires_selon_le_role() {
        assertTrue(TypeDocument.obligatoiresPour(TypeActeur.GROSSISTE).contains(TypeDocument.REGISTRE_COMMERCE));
        assertTrue(TypeDocument.obligatoiresPour(TypeActeur.COURTIER).contains(TypeDocument.LICENCE_TRANSIT));
        assertTrue(TypeDocument.obligatoiresPour(TypeActeur.COURTIER).contains(TypeDocument.PIECE_IDENTITE));
        assertTrue(TypeDocument.obligatoiresPour(TypeActeur.COMMERCANT).isEmpty());
    }

    @Test
    void rg09_compte_suspendu_ou_desactive_ne_s_authentifie_pas() {
        assertTrue(StatutCompte.ACTIF.peutSAuthentifier());
        assertTrue(StatutCompte.EN_ATTENTE.peutSAuthentifier());
        assertFalse(StatutCompte.SUSPENDU.peutSAuthentifier());
        assertFalse(StatutCompte.DESACTIVE.peutSAuthentifier());
        assertTrue(StatutCompte.DESACTIVE.estTerminal());
    }

    @Test
    void rg07_format_du_pin() {
        RegleAcces.verifierFormatPin("4821");
        RegleAcces.verifierFormatPin("9283");
        for (String mauvais : new String[]{null, "123", "482193", "1234567", "abcd", "1111"}) {
            assertThrows(ErreurMetier.class, () -> RegleAcces.verifierFormatPin(mauvais));
        }
    }

    @Test
    void rg07_format_du_mot_de_passe() {
        RegleAcces.verifierFormatMotDePasse("Dogo2026!");
        RegleAcces.verifierFormatMotDePasse("Pass1234");
        for (String mauvais : new String[]{null, "court", "toutenminuscule1", "TOUTENMAJUSCULE1", "SansChiffre", "12345678"}) {
            assertThrows(ErreurMetier.class, () -> RegleAcces.verifierFormatMotDePasse(mauvais));
        }
    }

    @Test
    void rg19_transitions_valides_du_groupe() {
        assertTrue(StatutGroupe.BROUILLON.peutAllerVers(StatutGroupe.EN_VALIDATION));
        assertTrue(StatutGroupe.EN_VALIDATION.peutAllerVers(StatutGroupe.OUVERT));
        assertTrue(StatutGroupe.OUVERT.peutAllerVers(StatutGroupe.OBJECTIF_ATTEINT));
        assertTrue(StatutGroupe.OBJECTIF_ATTEINT.peutAllerVers(StatutGroupe.EN_EXPEDITION));
    }

    @Test
    void rg19_transition_interdite_est_refusee() {
        ErreurMetier e = assertThrows(ErreurMetier.class,
                () -> StatutGroupe.BROUILLON.verifierTransition(StatutGroupe.OUVERT, "RG-19"));
        assertEquals(CodeErreur.TRANSITION_INTERDITE, e.code());
        assertEquals("RG-19", e.regle());
        assertFalse(StatutGroupe.OUVERT.peutAllerVers(StatutGroupe.LIVRE));
    }

    @Test
    void rg19_statuts_terminaux_ne_bougent_plus() {
        assertTrue(StatutGroupe.ANNULE.estTerminal());
        assertTrue(StatutGroupe.ECHOUE.estTerminal());
        assertTrue(StatutGroupe.TERMINE.estTerminal());
        assertFalse(StatutGroupe.OUVERT.estTerminal());
    }

    // ---- RG-20 / RG-37 / RG-42 : prix

    @Test
    void rg20_prix_unitaire_est_la_somme_des_composantes() {
        CalculPrix.Composantes c = new CalculPrix.Composantes(new BigDecimal("10000"), new BigDecimal("1500"),
                new BigDecimal("500"), new BigDecimal("800"), new BigDecimal("200"));
        assertEquals(new BigDecimal("13000"), CalculPrix.totalUnitaire(c));
        assertEquals(new BigDecimal("39000"), CalculPrix.montant(CalculPrix.totalUnitaire(c), 3));
    }

    @Test
    void rg17_composante_manquante_ou_negative_est_refusee() {
        assertThrows(ErreurMetier.class, () -> new CalculPrix.Composantes(new BigDecimal("100"), null,
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO));
        assertThrows(ErreurMetier.class, () -> new CalculPrix.Composantes(new BigDecimal("100"),
                new BigDecimal("-1"), BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO));
        assertThrows(ErreurMetier.class, () -> new CalculPrix.Composantes(BigDecimal.ZERO, BigDecimal.ZERO,
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO));
    }

    @Test
    void rg37_frais_plateforme_arrondis_au_franc() {
        assertEquals(new BigDecimal("500"), CalculPrix.fraisPlateforme(new BigDecimal("10000"), new BigDecimal("0.05")));
        assertEquals(new BigDecimal("83"), CalculPrix.fraisPlateforme(new BigDecimal("1650"), new BigDecimal("0.05")));
    }

    @Test
    void rg27_quantite_nulle_ou_negative_est_refusee() {
        assertThrows(ErreurMetier.class, () -> CalculPrix.montant(new BigDecimal("100"), 0));
        assertThrows(ErreurMetier.class, () -> CalculPrix.montant(new BigDecimal("100"), -2));
    }

    @Test
    void rg42_conversion_en_xof_avec_taux_fige() {
        assertEquals(new BigDecimal("6560"), CalculPrix.convertirEnXof(new BigDecimal("10"), new BigDecimal("655.957")));
    }

    // ---- RG-24 / RG-26 : groupe et participation

    @Test
    void rg24_annulation_possible_seulement_avant_objectif() {
        assertTrue(StatutGroupe.OUVERT.annulable());
        assertTrue(StatutGroupe.BROUILLON.annulable());
        assertFalse(StatutGroupe.OBJECTIF_ATTEINT.annulable());
        assertFalse(StatutGroupe.EN_EXPEDITION.annulable());
    }

    @Test
    void rg26_seul_un_groupe_ouvert_accepte_des_participations() {
        assertTrue(StatutGroupe.OUVERT.accepteParticipations());
        assertFalse(StatutGroupe.BROUILLON.accepteParticipations());
        assertFalse(StatutGroupe.OBJECTIF_ATTEINT.accepteParticipations());
    }

    @Test
    void rg28_participation_expiree_ou_annulee_ne_revient_pas() {
        assertTrue(StatutParticipation.RESERVEE.peutAllerVers(StatutParticipation.EXPIREE));
        assertFalse(StatutParticipation.EXPIREE.peutAllerVers(StatutParticipation.RESERVEE));
        assertFalse(StatutParticipation.ANNULEE.peutAllerVers(StatutParticipation.CONFIRMEE));
        assertFalse(StatutParticipation.EXPIREE.active());
        assertTrue(StatutParticipation.CONFIRMEE.active());
    }

    @Test
    void rg30_confirmation_seulement_depuis_reservee() {
        assertTrue(StatutParticipation.RESERVEE.peutAllerVers(StatutParticipation.CONFIRMEE));
        assertFalse(StatutParticipation.DEMANDEE.peutAllerVers(StatutParticipation.CONFIRMEE));
    }

    // ---- RG-34..36 / RG-38 : paiement et séquestre

    @Test
    void rg35_paye_seulement_depuis_en_attente() {
        assertTrue(StatutPaiement.EN_ATTENTE.peutAllerVers(StatutPaiement.PAYE));
        assertTrue(StatutPaiement.INITIE.peutAllerVers(StatutPaiement.PAYE)); // paiement direct portefeuille
        assertFalse(StatutPaiement.ECHOUE.peutAllerVers(StatutPaiement.PAYE));
    }

    @Test
    void rg36_sequestre_libere_ou_restitue_une_seule_fois() {
        assertTrue(StatutSequestre.BLOQUE.peutAllerVers(StatutSequestre.LIBERE));
        assertTrue(StatutSequestre.BLOQUE.peutAllerVers(StatutSequestre.RESTITUE));
        assertTrue(StatutSequestre.LIBERE.estTerminal());
        assertTrue(StatutSequestre.RESTITUE.estTerminal());
    }

    @Test
    void rg38_part_courtier_est_montant_moins_frais() {
        assertEquals(new BigDecimal("37500"), RegleFinance.partCourtier(new BigDecimal("39000"), new BigDecimal("1500")));
        assertThrows(ErreurMetier.class, () -> RegleFinance.partCourtier(new BigDecimal("100"), new BigDecimal("200")));
    }

    @Test
    void rg41_retrait_limite_au_solde_disponible() {
        RegleFinance.verifierRetrait(new BigDecimal("5000"), new BigDecimal("5000"));
        assertThrows(ErreurMetier.class, () -> RegleFinance.verifierRetrait(new BigDecimal("5000"), new BigDecimal("5001")));
        assertThrows(ErreurMetier.class, () -> RegleFinance.verifierRetrait(new BigDecimal("5000"), BigDecimal.ZERO));
    }

    // ---- RG-44 / RG-51 : commande

    @Test
    void rg44_chaine_de_statuts_de_la_commande() {
        assertTrue(StatutCommande.CREEE.peutAllerVers(StatutCommande.PREPAREE));
        assertTrue(StatutCommande.EXPEDIEE.peutAllerVers(StatutCommande.ARRIVEE));
        assertTrue(StatutCommande.ARRIVEE.peutAllerVers(StatutCommande.EN_ATTENTE_RETRAIT));
        assertTrue(StatutCommande.EN_ATTENTE_RETRAIT.peutAllerVers(StatutCommande.COLLECTEE));
        assertFalse(StatutCommande.EXPEDIEE.peutAllerVers(StatutCommande.EN_ATTENTE_RETRAIT));
    }

    @Test
    void rg50_aucune_commande_n_arrive_sans_passer_par_expediee() {
        assertFalse(StatutCommande.PREPAREE.peutAllerVers(StatutCommande.ARRIVEE));
    }

    @Test
    void rg51_grossiste_modifie_avant_expedition_seulement() {
        assertTrue(StatutCommande.CREEE.modifiableParGrossiste());
        assertTrue(StatutCommande.PREPAREE.modifiableParGrossiste());
        assertFalse(StatutCommande.EXPEDIEE.modifiableParGrossiste());
    }

    // ---- RG-54 : code de retrait

    @Test
    void rg54_code_valide_est_utilisable() {
        RegleRetrait.verifierUtilisable(false, false, T0.plusSeconds(60), T0);
    }

    @Test
    void rg54_code_expire_utilise_ou_bloque_est_refuse() {
        ErreurMetier expire = assertThrows(ErreurMetier.class,
                () -> RegleRetrait.verifierUtilisable(false, false, T0, T0));
        assertEquals(CodeErreur.CODE_RETRAIT_INVALIDE, expire.code());
        ErreurMetier utilise = assertThrows(ErreurMetier.class,
                () -> RegleRetrait.verifierUtilisable(true, false, T0.plusSeconds(60), T0));
        assertEquals(CodeErreur.CODE_RETRAIT_INVALIDE, utilise.code());
        ErreurMetier bloque = assertThrows(ErreurMetier.class,
                () -> RegleRetrait.verifierUtilisable(false, true, T0.plusSeconds(60), T0));
        assertEquals(CodeErreur.CODE_RETRAIT_BLOQUE, bloque.code());
    }

    @Test
    void rg54_blocage_apres_trois_tentatives() {
        assertFalse(RegleRetrait.doitBloquer(2, 3));
        assertTrue(RegleRetrait.doitBloquer(3, 3));
    }

    // ---- RG-57 / RG-58 / RG-60 : remboursement

    @Test
    void rg58_total_rembourse_ne_depasse_pas_le_paye() {
        RegleFinance.verifierMontantRemboursable(new BigDecimal("10000"), new BigDecimal("4000"), new BigDecimal("6000"));
        ErreurMetier e = assertThrows(ErreurMetier.class, () -> RegleFinance.verifierMontantRemboursable(
                new BigDecimal("10000"), new BigDecimal("4000"), new BigDecimal("6001")));
        assertEquals(CodeErreur.REMBOURSEMENT_INVALIDE, e.code());
    }

    @Test
    void rg60_motifs_automatiques_et_manuels() {
        assertTrue(MotifRemboursement.ECHEC_GROUPE.automatique());
        assertTrue(MotifRemboursement.ECHEC_FOURNISSEUR.automatique());
        assertFalse(MotifRemboursement.ANNULATION_CLIENT.automatique());
        assertFalse(MotifRemboursement.COLIS_PERDU.automatique());
        assertFalse(MotifRemboursement.LITIGE_RESOLU.automatique());
    }

    @Test
    void rg57_remboursement_suit_demande_approbation_execution() {
        assertTrue(StatutRemboursement.DEMANDE.peutAllerVers(StatutRemboursement.APPROUVE));
        assertTrue(StatutRemboursement.APPROUVE.peutAllerVers(StatutRemboursement.EXECUTE));
        assertFalse(StatutRemboursement.DEMANDE.peutAllerVers(StatutRemboursement.EXECUTE));
    }
}

