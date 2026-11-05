<?php
if (!defined('ABSPATH')) {
    exit;
}

/**
 * Contrôleur REST : Proxy sécurisé WordPress vers Karavan
 * Évite d'exposer l'URL interne ou les clés privées du backend aux navigateurs.
 */
class Karavan_REST_Controller {

    private $api;

    public function __construct(Karavan_API $api) {
        $this->api = $api;
        add_action('rest_api_init', array($this, 'enregistrer_routes'));
    }

    public function enregistrer_routes() {
        register_rest_route('karavan/v1', '/groupes', array(
            'methods'             => 'GET',
            'callback'            => array($this, 'get_groupes'),
            'permission_callback' => '__return_true', // Consultation publique
        ));

        register_rest_route('karavan/v1', '/stats', array(
            'methods'             => 'GET',
            'callback'            => array($this, 'get_stats'),
            'permission_callback' => '__return_true',
        ));

        register_rest_route('karavan/v1', '/rafraichir', array(
            'methods'             => 'POST',
            'callback'            => array($this, 'rafraichir_cache'),
            'permission_callback' => array($this, 'verifier_securite_nonce'),
        ));
    }

    /**
     * Vérification de sécurité Anti-CSRF via Nonce WordPress
     */
    public function verifier_securite_nonce($request) {
        $nonce = $request->get_header('x_wp_nonce');
        if (!$nonce || !wp_verify_nonce($nonce, 'wp_rest')) {
            return new WP_Error('rest_forbidden', 'Échec de vérification du jeton de sécurité (Nonce invalide).', array('status' => 403));
        }
        return true;
    }

    public function get_groupes($request) {
        $categorie = $request->get_param('categorie');
        $donnees = $this->api->recuperer_groupes(false);

        if (!empty($categorie)) {
            $categorie_filtre = sanitize_text_field($categorie);
            $donnees = array_filter($donnees, function($g) use ($categorie_filtre) {
                return isset($g['categorie']) && strtolower($g['categorie']) === strtolower($categorie_filtre);
            });
            $donnees = array_values($donnees);
        }

        return rest_ensure_response(array(
            'succes' => true,
            'total'  => count($donnees),
            'donnees'=> $donnees
        ));
    }

    public function get_stats() {
        $stats = $this->api->recuperer_statistiques();
        return rest_ensure_response(array(
            'succes' => true,
            'stats'  => $stats
        ));
    }

    public function rafraichir_cache() {
        $donnees = $this->api->recuperer_groupes(true); // Force l'appel API
        return rest_ensure_response(array(
            'succes'  => true,
            'message' => 'Données réactualisées en direct depuis le serveur Karavan.',
            'total'   => count($donnees)
        ));
    }
}
