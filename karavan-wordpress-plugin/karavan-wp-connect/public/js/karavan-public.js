/**
 * Script dynamique Karavan Connect pour WordPress
 * Gère l'actualisation dynamique par AJAX et la validation par Nonce
 */
(function($) {
    'use strict';

    $(document).ready(function() {
        var $btnRefresh = $('#karavan-btn-actualiser');
        var $container = $('#karavan-groupes-container');

        if (!$btnRefresh.length) {
            return;
        }

        $btnRefresh.on('click', function(e) {
            e.preventDefault();

            if ($btnRefresh.hasClass('en-chargement')) {
                return;
            }

            $btnRefresh.addClass('en-chargement');

            // Appel AJAX sécurisé vers l'endpoint REST WordPress avec jeton Nonce anti-CSRF
            $.ajax({
                url: KaravanConfig.restUrl + 'rafraichir',
                method: 'POST',
                beforeSend: function(xhr) {
                    xhr.setRequestHeader('X-WP-Nonce', KaravanConfig.nonce);
                },
                success: function(response) {
                    if (response && response.succes) {
                        // Recharger les données des groupes en direct
                        chargerDonneesEnDirect();
                    } else {
                        alert(KaravanConfig.i18n.erreur);
                        $btnRefresh.removeClass('en-chargement');
                    }
                },
                error: function(xhr, status, error) {
                    console.error('Erreur Karavan Connect:', error);
                    alert(KaravanConfig.i18n.erreur);
                    $btnRefresh.removeClass('en-chargement');
                }
            });
        });

        function chargerDonneesEnDirect() {
            $.ajax({
                url: KaravanConfig.restUrl + 'groupes',
                method: 'GET',
                success: function(res) {
                    if (res && res.donnees) {
                        mettreAJourGrille(res.donnees);
                    }
                },
                complete: function() {
                    $btnRefresh.removeClass('en-chargement');
                }
            });
        }

        function mettreAJourGrille(groupes) {
            var $grille = $container.find('.karavan-grid');
            if (!$grille.length) {
                location.reload();
                return;
            }

            $grille.empty();

            if (!groupes || groupes.length === 0) {
                $grille.html('<div class="karavan-empty-state"><p>Aucun groupe d\'achat actif en ce moment.</p></div>');
                return;
            }

            groupes.forEach(function(g) {
                var nom = g.nom || 'Groupe Karavan';
                var cat = g.categorie || 'Import';
                var pays = g.paysDestination || 'Mali';
                var actuel = parseFloat(g.quantiteActuelle || 0);
                var cible = parseFloat(g.quantiteObjectif || 100);
                var pct = Math.min(100, Math.round((actuel / (cible > 0 ? cible : 1)) * 100));
                var prix = g.prixUnitaire ? (Number(g.prixUnitaire).toLocaleString('fr-FR') + ' FCFA') : 'Tarif groupé';
                var statut = (g.statut || 'OUVERT').toUpperCase();

                var html = '' +
                '<div class="karavan-card">' +
                    '<div class="karavan-card-badge">' +
                        '<span class="karavan-tag-pays">' + echapperHTML(pays) + '</span>' +
                        '<span class="karavan-tag-statut karavan-statut-' + echapperHTML(statut.toLowerCase()) + '">' + echapperHTML(statut) + '</span>' +
                    '</div>' +
                    '<div class="karavan-card-body">' +
                        '<span class="karavan-card-cat">' + echapperHTML(cat) + '</span>' +
                        '<h4 class="karavan-card-title">' + echapperHTML(nom) + '</h4>' +
                        '<div class="karavan-jauge-block">' +
                            '<div class="karavan-jauge-info">' +
                                '<span>Remplissage</span>' +
                                '<strong class="karavan-jauge-val">' + pct + '%</strong>' +
                            '</div>' +
                            '<div class="karavan-progress-bar-bg">' +
                                '<div class="karavan-progress-bar-fill" style="width: ' + pct + '%;"></div>' +
                            '</div>' +
                            '<div class="karavan-jauge-sub">' +
                                '<span>' + actuel + ' commandés</span>' +
                                '<span>Objectif : ' + cible + '</span>' +
                            '</div>' +
                        '</div>' +
                        '<div class="karavan-card-footer">' +
                            '<div class="karavan-prix-box">' +
                                '<span class="karavan-prix-label">Tarif groupé</span>' +
                                '<span class="karavan-prix-val">' + echapperHTML(prix) + '</span>' +
                            '</div>' +
                            '<a href="#participer" class="karavan-btn-participer" data-id="' + (g.id || '') + '">Rejoindre</a>' +
                        '</div>' +
                    '</div>' +
                '</div>';

                $grille.append(html);
            });
        }

        function echapperHTML(str) {
            return String(str)
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#039;');
        }
    });
})(jQuery);
