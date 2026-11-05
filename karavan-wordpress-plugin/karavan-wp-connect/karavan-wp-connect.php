<?php
/**
 * Plugin Name: Karavan WP Connect
 * Plugin URI: https://karavan.ml
 * Description: Connecteur dynamique et sécurisé entre WordPress et la plateforme Karavan (achats groupés & importations). Affiche les groupes d'achats en temps réel, les jauges de progression et les statistiques avec protection anti-CSRF (Nonces) et cache intelligent.
 * Version: 1.0.0
 * Author: Karavan Team
 * Author URI: https://karavan.ml
 * License: GPL-2.0+
 * Text Domain: karavan-connect
 */

// Sécurité : interdire l'accès direct aux fichiers PHP
if (!defined('ABSPATH')) {
    exit;
}

define('KARAVAN_VERSION', '1.0.0');
define('KARAVAN_PLUGIN_DIR', plugin_dir_path(__FILE__));
define('KARAVAN_PLUGIN_URL', plugin_dir_url(__FILE__));

// Chargement des classes du plugin
require_once KARAVAN_PLUGIN_DIR . 'includes/class-karavan-api.php';
require_once KARAVAN_PLUGIN_DIR . 'includes/class-karavan-admin.php';
require_once KARAVAN_PLUGIN_DIR . 'includes/class-karavan-rest.php';
require_once KARAVAN_PLUGIN_DIR . 'includes/class-karavan-shortcodes.php';

/**
 * Initialisation principale du plugin Karavan
 */
class KaravanConnect {

    private static $instance = null;
    public $api;

    public static function get_instance() {
        if (null === self::$instance) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    private function __construct() {
        $this->api = new Karavan_API();

        // Enregistrement des scripts et styles publics
        add_action('wp_enqueue_scripts', array($this, 'charger_scripts_publics'));

        // Initialisation de l'administration
        if (is_admin()) {
            new Karavan_Admin();
        }

        // Initialisation des routes REST internes (Proxy Sécurisé)
        new Karavan_REST_Controller($this->api);

        // Initialisation des shortcodes
        new Karavan_Shortcodes($this->api);
    }

    /**
     * Chargement des scripts JS et feuilles de styles du Design System
     */
    public function charger_scripts_publics() {
        wp_enqueue_style(
            'karavan-public-style',
            KARAVAN_PLUGIN_URL . 'public/css/karavan-public.css',
            array(),
            KARAVAN_VERSION
        );

        wp_enqueue_script(
            'karavan-public-script',
            KARAVAN_PLUGIN_URL . 'public/js/karavan-public.js',
            array('jquery'),
            KARAVAN_VERSION,
            true
        );

        // Transmission sécurisée de l'URL REST et du Nonce anti-CSRF au JavaScript
        wp_localize_script('karavan-public-script', 'KaravanConfig', array(
            'restUrl' => esc_url_raw(rest_url('karavan/v1/')),
            'nonce'   => wp_create_nonce('wp_rest'),
            'i18n'    => array(
                'chargement' => esc_html__('Chargement en cours...', 'karavan-connect'),
                'erreur'     => esc_html__('Impossible de joindre le service Karavan.', 'karavan-connect'),
                'complet'    => esc_html__('Groupe complet', 'karavan-connect')
            )
        ));
    }
}

// Démarrage du plugin
add_action('plugins_loaded', array('KaravanConnect', 'get_instance'));
