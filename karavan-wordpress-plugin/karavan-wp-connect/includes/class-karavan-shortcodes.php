<?php
if (!defined('ABSPATH')) {
    exit;
}

/**
 * Gestion des shortcodes publics pour l'affichage dynamique
 */
class Karavan_Shortcodes {

    private $api;

    public function __construct(Karavan_API $api) {
        $this->api = $api;
        add_shortcode('karavan_groupes', array($this, 'rendre_groupes'));
        add_shortcode('karavan_stats', array($this, 'rendre_stats'));
    }

    /**
     * Rendu du shortcode [karavan_groupes]
     */
    public function rendre_groupes($atts) {
        $atts = shortcode_atts(array(
            'limite'    => 6,
            'categorie' => '',
            'titre'     => 'Groupes d\'achats en cours'
        ), $atts, 'karavan_groupes');

        $groupes = $this->api->recuperer_groupes();

        if (!empty($atts['categorie'])) {
            $cat = strtolower(sanitize_text_field($atts['categorie']));
            $groupes = array_filter($groupes, function($g) use ($cat) {
                return isset($g['categorie']) && strtolower($g['categorie']) === $cat;
            });
        }

        $groupes = array_slice($groupes, 0, (int) $atts['limite']);

        ob_start();
        ?>
        <div class="karavan-widget-wrapper" id="karavan-groupes-container">
            <div class="karavan-widget-header">
                <h3 class="karavan-titre"><?php echo esc_html($atts['titre']); ?></h3>
                <button type="button" class="karavan-btn-refresh" id="karavan-btn-actualiser" title="Actualiser les données en direct">
                    <span class="karavan-refresh-icon">🔄</span> Actualiser
                </button>
            </div>

            <?php if (empty($groupes)): ?>
                <div class="karavan-empty-state">
                    <p>Aucun groupe d'achat ouvert pour le moment. Revenez très vite ou lancez une nouvelle commande !</p>
                </div>
            <?php else: ?>
                <div class="karavan-grid">
                    <?php foreach ($groupes as $g): 
                        $nom = isset($g['nom']) ? $g['nom'] : 'Groupe Karavan';
                        $categorie = isset($g['categorie']) ? $g['categorie'] : 'Import';
                        $pays = isset($g['paysDestination']) ? $g['paysDestination'] : 'Mali';
                        $actuel = isset($g['quantiteActuelle']) ? (float)$g['quantiteActuelle'] : 0;
                        $cible = isset($g['quantiteObjectif']) && $g['quantiteObjectif'] > 0 ? (float)$g['quantiteObjectif'] : 100;
                        $pourcentage = min(100, round(($actuel / $cible) * 100));
                        $prix = isset($g['prixUnitaire']) ? number_format((float)$g['prixUnitaire'], 0, ',', ' ') . ' FCFA' : 'Prix de groupe';
                        $statut = isset($g['statut']) ? $g['statut'] : 'OUVERT';
                    ?>
                        <div class="karavan-card">
                            <div class="karavan-card-badge">
                                <span class="karavan-tag-pays"><?php echo esc_html($pays); ?></span>
                                <span class="karavan-tag-statut karavan-statut-<?php echo esc_attr(strtolower($statut)); ?>">
                                    <?php echo esc_html($statut); ?>
                                </span>
                            </div>

                            <div class="karavan-card-body">
                                <span class="karavan-card-cat"><?php echo esc_html($categorie); ?></span>
                                <h4 class="karavan-card-title"><?php echo esc_html($nom); ?></h4>

                                <div class="karavan-jauge-block">
                                    <div class="karavan-jauge-info">
                                        <span>Remplissage</span>
                                        <strong class="karavan-jauge-val"><?php echo esc_html($pourcentage); ?>%</strong>
                                    </div>
                                    <div class="karavan-progress-bar-bg">
                                        <div class="karavan-progress-bar-fill" style="width: <?php echo esc_attr($pourcentage); ?>%;"></div>
                                    </div>
                                    <div class="karavan-jauge-sub">
                                        <span><?php echo esc_html($actuel); ?> commandés</span>
                                        <span>Objectif : <?php echo esc_html($cible); ?></span>
                                    </div>
                                </div>

                                <div class="karavan-card-footer">
                                    <div class="karavan-prix-box">
                                        <span class="karavan-prix-label">Tarif groupé</span>
                                        <span class="karavan-prix-val"><?php echo esc_html($prix); ?></span>
                                    </div>
                                    <a href="#participer" class="karavan-btn-participer" data-id="<?php echo esc_attr(isset($g['id']) ? $g['id'] : ''); ?>">
                                        Rejoindre
                                    </a>
                                </div>
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>
        </div>
        <?php
        return ob_get_clean();
    }

    /**
     * Rendu du shortcode [karavan_stats]
     */
    public function rendre_stats() {
        $stats = $this->api->recuperer_statistiques();

        ob_start();
        ?>
        <div class="karavan-stats-wrapper">
            <div class="karavan-stat-box">
                <span class="karavan-stat-num"><?php echo esc_html($stats['groupes_actifs']); ?></span>
                <span class="karavan-stat-label">Conteneurs en cours</span>
            </div>
            <div class="karavan-stat-box">
                <span class="karavan-stat-num"><?php echo esc_html(number_format($stats['volume_kg'], 0, ',', ' ')); ?> kg</span>
                <span class="karavan-stat-label">Marchandises groupées</span>
            </div>
            <div class="karavan-stat-box">
                <span class="karavan-stat-num"><?php echo esc_html($stats['total_commandes']); ?></span>
                <span class="karavan-stat-label">Commerçants réunis</span>
            </div>
            <div class="karavan-stat-box">
                <span class="karavan-stat-num"><?php echo esc_html($stats['taux_remise_moyen']); ?></span>
                <span class="karavan-stat-label">Économie moyenne constatée</span>
            </div>
        </div>
        <?php
        return ob_get_clean();
    }
}
