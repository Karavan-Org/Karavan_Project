const fs = require('fs');
const path = require('path');

const targetFiles = [
  'dogo-flutter/lib/grossiste/portefeuille_grossiste_screen.dart',
  'dogo-flutter/lib/grossiste/historique_grossiste_screen.dart',
  'dogo-flutter/lib/grossiste/documents_grossiste_screen.dart',
  'dogo-flutter/lib/grossiste/assistance_grossiste_screen.dart',
  'dogo-flutter/lib/grossiste/parametres_grossiste_screen.dart',
  'dogo-flutter/lib/grossiste/notifications_grossiste_screen.dart',
  'dogo-flutter/lib/grossiste/ajouter_produit_screen.dart',
  'dogo-flutter/lib/grossiste/creer_groupe_grossiste_screen.dart',
  'dogo-flutter/lib/grossiste/expedier_lot_screen.dart',
  'dogo-flutter/lib/grossiste/suivi_colis_grossiste_screen.dart',
  'dogo-flutter/lib/courtier/historique_courtier_screen.dart',
  'dogo-flutter/lib/courtier/assistance_courtier_screen.dart',
  'dogo-flutter/lib/courtier/parametres_courtier_screen.dart',
  'dogo-flutter/lib/courtier/notifications_courtier_screen.dart',
  'dogo-flutter/lib/courtier/creer_groupe_courtier_screen.dart',
  'dogo-flutter/lib/courtier/scanner_retrait_screen.dart',
  'dogo-flutter/lib/courtier/etape_transit_screen.dart',
  'dogo-flutter/lib/courtier/lancer_convoi_screen.dart',
  'dogo-flutter/lib/commercant/groupes_grossiste_screen.dart',
  'dogo-flutter/lib/commercant/mes_favoris_screen.dart',
  'dogo-flutter/lib/commercant/portefeuille_commercant_screen.dart',
  'dogo-flutter/lib/commercant/parametres_commercant_screen.dart',
  'dogo-flutter/lib/commercant/notifications_commercant_screen.dart',
  'dogo-flutter/lib/commercant/aide_support_screen.dart',
  'dogo-flutter/lib/commercant/suivi_colis_screen.dart',
  'dogo-flutter/lib/commercant/code_retrait_commercant_screen.dart',
  'dogo-flutter/lib/commercant/fiche_campagne_screen.dart',
  'dogo-flutter/lib/commercant/ouvrir_groupe_screen.dart',
  'dogo-flutter/lib/commercant/rejoindre_groupe_screen.dart'
];

targetFiles.forEach(f => {
  const p = path.join(__dirname, '..', f);
  if (!fs.existsSync(p)) return;
  const content = fs.readFileSync(p, 'utf8');
  const hasLeading = content.includes('leading:');
  const hasArrowBack = content.includes('arrow_back') || content.includes('close_rounded');
  const hasAppBar = content.includes('appBar:');
  console.log(`${f}: hasAppBar=${hasAppBar}, hasLeading=${hasLeading}, hasArrowBack=${hasArrowBack}`);
});

