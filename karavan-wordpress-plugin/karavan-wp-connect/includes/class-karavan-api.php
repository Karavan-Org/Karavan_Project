<?php
if (!defined('ABSPATH')) {
    exit;
}

/**
 * Service API Karavan : Communication sécurisée avec Spring Boot
 */
class Karavan_API {

    private function get_base_url() {
        $url = get_option('karavan_api_url', 'http://localhost:8080/api');
        return rtrim($url, '/');
    }

    private function get_cache_ttl() {
        return (int) get_option('karavan_cache_ttl', 300); // 5 minutes par défaut
    }

    /**
     * Récupère la liste des groupes d'achats publics
     */
    public function recuperer_groupes($force_refresh = false) {
        $cache_key = 'karavan_groupes_publics';

        if (!$force_refresh) {
            $cached = get_transient($cache_key);
            if ($cached !== false) {
                return $cached;
            }
        }

        $endpoint = $this->get_base_url() . '/groupes';
        $response = wp_remote_get($endpoint, array(
            'timeout' => 8,
            'headers' => array(
                'Accept' => 'application/json',
                'User-Agent' => 'WordPress/KaravanConnect-' . KARAVAN_VERSION
            )
        ));

        if (is_wp_error($response)) {
            error_log('Erreur Karavan API: ' . $response->get_error_message());
            return array();
        }

        $code = wp_remote_retrieve_response_code($response);
        if ($code !== 200) {
            error_log('Erreur HTTP Karavan API: ' . $code);
            return array();
        }

        $body = wp_remote_retrieve_body($response);
        $donnees = json_decode($body, true);

        if (!is_array($donnees)) {
            return array();
        }

        // Mettre en cache pour préserver les ressources du serveur
        set_transient($cache_key, $donnees, $this->get_cache_ttl());

        return $donnees;
    }

    /**
     * Récupère les catégories du catalogue
     */
    public function recuperer_categories() {
        $cache_key = 'karavan_categories';
        $cached = get_transient($cache_key);
        if ($cached !== false) {
            return $cached;
        }

        $endpoint = $this->get_base_url() . '/catalogue/categories';
        $response = wp_remote_get($endpoint, array('timeout' => 5));

        if (is_wp_error($response) || wp_remote_retrieve_response_code($response) !== 200) {
            return array();
        }

        $donnees = json_decode(wp_remote_retrieve_body($response), true);
        if (is_array($donnees)) {
            set_transient($cache_key, $donnees, 3600); // 1 heure de cache
            return $donnees;
        }

        return array();
    }

    /**
     * Calcule ou extrait les métriques clés en temps réel
     */
    public function recuperer_statistiques() {
        $groupes = $this->recuperer_groupes();

        $groupes_actifs = 0;
        $volume_total_kg = 0;
        $total_commandes = 0;

        foreach ($groupes as $g) {
            if (isset($g['statut']) && in_array($g['statut'], array('OUVERT', 'VALIDATION_LOGISTIQUE', 'EN_TRANSIT', 'COMMANDE_GROSSISTE'))) {
                $groupes_actifs++;
            }
            if (isset($g['quantiteActuelle'])) {
                $volume_total_kg += (float) $g['quantiteActuelle'];
            }
            if (isset($g['nombreParticipants'])) {
                $total_commandes += (int) $g['nombreParticipants'];
            }
        }

        return array(
            'groupes_actifs'    => $groupes_actifs,
            'volume_kg'         => $volume_total_kg,
            'total_commandes'   => $total_commandes,
            'taux_remise_moyen' => '28%'
        );
    }
}
