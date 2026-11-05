<?php
if (!defined('ABSPATH')) {
    exit;
}

/**
 * Administration : Configuration sécurisée de la connexion Karavan
 */
class Karavan_Admin {

    public function __construct() {
        add_action('admin_menu', array($this, 'ajouter_menu'));
        add_action('admin_init', array($this, 'enregistrer_parametres'));
    }

    public function ajouter_menu() {
        add_options_page(
            'Configuration Karavan Connect',
            'Karavan Connect',
            'manage_options',
            'karavan-connect',
            array($this, 'rendre_page_options')
        );
    }

    public function enregistrer_parametres() {
        register_setting('karavan_options_group', 'karavan_api_url', array(
            'type'              => 'string',
            'sanitize_callback' => 'esc_url_raw',
            'default'           => 'http://localhost:8080/api'
        ));

        register_setting('karavan_options_group', 'karavan_cache_ttl', array(
            'type'              => 'integer',
            'sanitize_callback' => 'absint',
            'default'           => 300
        ));

        register_setting('karavan_options_group', 'karavan_api_secret', array(
            'type'              => 'string',
            'sanitize_callback' => 'sanitize_text_field',
            'default'           => ''
        ));
    }

    public function rendre_page_options() {
        if (!current_user_can('manage_options')) {
            wp_die('Accès refusé.');
        }

        // Test rapide de connectivité vers Spring Boot
        $api_url = get_option('karavan_api_url', 'http://localhost:8080/api');
        $test_response = wp_remote_get(rtrim($api_url, '/') . '/groupes', array('timeout' => 3));
        $est_connecte = !is_wp_error($test_response) && wp_remote_retrieve_response_code($test_response) === 200;
        ?>
        <div class="wrap" style="max-width: 850px;">
            <h1 style="color: #2C241E; display: flex; align-items: center; gap: 10px;">
                <span style="display:inline-block; width:14px; height:14px; border-radius:50%; background: <?php echo $est_connecte ? '#34C759' : '#DC2626'; ?>;"></span>
                Karavan Connect — Passerelle Sécurisée
            </h1>
            <p>Ce module connecte votre site WordPress en temps réel au backend Spring Boot de <strong>Karavan</strong> pour synchroniser les groupes d'achats et les statistiques.</p>

            <div style="background: <?php echo $est_connecte ? '#EDFBF1' : '#FEF2F2'; ?>; border: 1px solid <?php echo $est_connecte ? '#B7E4C7' : '#FECACA'; ?>; border-radius: 12px; padding: 14px 20px; margin: 20px 0;">
                <strong style="color: <?php echo $est_connecte ? '#248A3D' : '#991B1B'; ?>;">
                    <?php if ($est_connecte): ?>
                        ✔ Backend Karavan opérationnel et connecté (<?php echo esc_html($api_url); ?>)
                    <?php else: ?>
                        ⚠ Impossible de joindre l'API Karavan à cette adresse. Vérifiez que le serveur Spring Boot est démarré.
                    <?php endif; ?>
                </strong>
            </div>

            <form method="post" action="options.php" style="background: #FFFFFF; padding: 25px; border-radius: 16px; border: 1px solid #EDE5DC; box-shadow: 0 4px 12px rgba(0,0,0,0.03);">
                <?php
                settings_fields('karavan_options_group');
                do_settings_sections('karavan_options_group');
                ?>
                <table class="form-table">
                    <tr>
                        <th scope="row"><label for="karavan_api_url">URL de l'API Karavan</label></th>
                        <td>
                            <input name="karavan_api_url" type="url" id="karavan_api_url" value="<?php echo esc_attr(get_option('karavan_api_url', 'http://localhost:8080/api')); ?>" class="regular-text" style="width: 100%; border-radius: 8px;" />
                            <p class="description">Exemple local : <code>http://localhost:8080/api</code> | Exemple Render : <code>https://karavan-api.onrender.com/api</code></p>
                        </td>
                    </tr>
                    <tr>
                        <th scope="row"><label for="karavan_cache_ttl">Durée du Cache (secondes)</label></th>
                        <td>
                            <input name="karavan_cache_ttl" type="number" id="karavan_cache_ttl" value="<?php echo esc_attr(get_option('karavan_cache_ttl', 300)); ?>" class="small-text" style="border-radius: 8px;" />
                            <p class="description">Recommandé : 300s (5 minutes) pour garantir une performance optimale sans saturer l'API.</p>
                        </td>
                    </tr>
                    <tr>
                        <th scope="row"><label for="karavan_api_secret">Clé secrète Machine-to-Machine (Optionnel)</label></th>
                        <td>
                            <input name="karavan_api_secret" type="password" id="karavan_api_secret" value="<?php echo esc_attr(get_option('karavan_api_secret', '')); ?>" class="regular-text" style="width: 100%; border-radius: 8px;" />
                            <p class="description">Pour les futures actions d'écriture (création de compte ou réservation directe).</p>
                        </td>
                    </tr>
                </table>

                <?php submit_button('Enregistrer les paramètres', 'primary', 'submit', true, array('style' => 'background: #AC7F5E; border-color: #8E6445; border-radius: 20px; padding: 6px 20px; font-weight: 600;')); ?>
            </form>

            <div style="margin-top: 30px; background: #FAF8F5; border: 1px solid #E8E2D9; border-radius: 12px; padding: 20px;">
                <h3 style="margin-top:0; color: #2C241E;">Shortcodes disponibles</h3>
                <ul>
                    <li><code>[karavan_groupes]</code> : Affiche la grille dynamique des conteneurs et groupes d'achats avec jauges en direct.</li>
                    <li><code>[karavan_stats]</code> : Affiche les métriques clés en temps réel (nombre de groupes, volume importé, économies).</li>
                </ul>
            </div>
        </div>
        <?php
    }
}
