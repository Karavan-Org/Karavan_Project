const fs = require('fs');
const path = require('path');

function replaceInFile(relPath, fn) {
  const fullPath = path.join(__dirname, '..', relPath);
  const orig = fs.readFileSync(fullPath, 'utf8');
  const updated = fn(orig);
  if (orig !== updated) {
    fs.writeFileSync(fullPath, updated, 'utf8');
    console.log(`Updated: ${relPath}`);
  } else {
    console.log(`No change: ${relPath}`);
  }
}

// 1. courtier_main_nav.dart: wrap Stack with TabNavigationScope
replaceInFile('dogo-flutter/lib/courtier/courtier_main_nav.dart', s => {
  if (!s.includes("import '../widgets/tab_navigation_scope.dart';")) {
    s = "import '../widgets/tab_navigation_scope.dart';\n" + s;
  }
  // Wrap build return Stack
  const target = `  @override\n  Widget build(BuildContext context) {\n    return Stack(`;
  const targetCRLF = `  @override\r\n  Widget build(BuildContext context) {\r\n    return Stack(`;
  if (s.includes(target)) {
    s = s.replace(target, `  @override\n  Widget build(BuildContext context) {\n    return TabNavigationScope(\n      onSwitchTab: setTabIndex,\n      child: Stack(`);
    s = s.replace(`    if (_afficherGuide)\n      Positioned.fill(\n        child: DidacticielGuideOverlay(\n          role: RoleActeur.courtier,\n          onTermine: () {\n            if (mounted) setState(() => _afficherGuide = false);\n          },\n        ),\n      ),\n  ],\n);`,
                  `    if (_afficherGuide)\n      Positioned.fill(\n        child: DidacticielGuideOverlay(\n          role: RoleActeur.courtier,\n          onTermine: () {\n            if (mounted) setState(() => _afficherGuide = false);\n          },\n        ),\n      ),\n  ],\n),\n);`);
  } else if (s.includes(targetCRLF)) {
    s = s.replace(targetCRLF, `  @override\r\n  Widget build(BuildContext context) {\r\n    return TabNavigationScope(\r\n      onSwitchTab: setTabIndex,\r\n      child: Stack(`);
    s = s.replace(`    if (_afficherGuide)\r\n      Positioned.fill(\r\n        child: DidacticielGuideOverlay(\r\n          role: RoleActeur.courtier,\r\n          onTermine: () {\r\n            if (mounted) setState(() => _afficherGuide = false);\r\n          },\r\n        ),\r\n      ),\r\n  ],\r\n);`,
                  `    if (_afficherGuide)\r\n      Positioned.fill(\r\n        child: DidacticielGuideOverlay(\r\n          role: RoleActeur.courtier,\r\n          onTermine: () {\r\n            if (mounted) setState(() => _afficherGuide = false);\r\n          },\r\n        ),\r\n      ),\r\n  ],\r\n),\r\n);`);
  }
  return s;
});

// 2. courtier_profil_screen.dart
replaceInFile('dogo-flutter/lib/courtier/courtier_profil_screen.dart', s => {
  if (!s.includes("import '../widgets/tab_navigation_scope.dart';")) {
    s = "import '../widgets/tab_navigation_scope.dart';\n" + s;
  }
  // Replace conditional back button
  const regex = /if\s*\(Navigator\.of\(context\)\.canPop\(\)\)\s*IconButton\([\s\S]*?\)\s*else\s*const\s*SizedBox\.shrink\(\),/;
  const replacement = `IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
                    tooltip: "Retour",
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        TabNavigationScope.switchToTab(context, 0);
                      }
                    },
                  ),`;
  return s.replace(regex, replacement);
});

// 3. portefeuille_courtier_screen.dart
replaceInFile('dogo-flutter/lib/courtier/portefeuille_courtier_screen.dart', s => {
  if (!s.includes("import '../widgets/tab_navigation_scope.dart';")) {
    s = "import '../widgets/tab_navigation_scope.dart';\n" + s;
  }
  const regex = /leading:\s*Navigator\.of\(context\)\.canPop\(\)\s*\?\s*IconButton\([\s\S]*?\)\s*:\s*null,/;
  const replacement = `leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          tooltip: "Retour",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              TabNavigationScope.switchToTab(context, 0);
            }
          },
        ),`;
  return s.replace(regex, replacement);
});

// 4. gestion_convoi_screen.dart
replaceInFile('dogo-flutter/lib/courtier/gestion_convoi_screen.dart', s => {
  if (!s.includes("import '../widgets/tab_navigation_scope.dart';")) {
    s = "import '../widgets/tab_navigation_scope.dart';\n" + s;
  }
  const regex = /leading:\s*IconButton\(\s*icon:\s*Icon\(Icons\.arrow_back_rounded,\s*color:\s*AppTheme\.couleurTexte\(context\)\),\s*onPressed:\s*\(\)\s*=>\s*Navigator\.of\(context\)\.pop\(\),\s*\),/;
  const replacement = `leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          tooltip: "Retour",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              TabNavigationScope.switchToTab(context, 0);
            }
          },
        ),`;
  return s.replace(regex, replacement);
});

// 5. mes_groupes_courtier_screen.dart
replaceInFile('dogo-flutter/lib/courtier/mes_groupes_courtier_screen.dart', s => {
  if (!s.includes("import '../widgets/tab_navigation_scope.dart';")) {
    s = "import '../widgets/tab_navigation_scope.dart';\n" + s;
  }
  const regex = /leading:\s*Navigator\.of\(context\)\.canPop\(\)\s*\?\s*IconButton\([\s\S]*?\)\s*:\s*null,/;
  const replacement = `leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          tooltip: "Retour",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              TabNavigationScope.switchToTab(context, 0);
            }
          },
        ),`;
  return s.replace(regex, replacement);
});

// 6. mes_groupes_grossiste_screen.dart
replaceInFile('dogo-flutter/lib/grossiste/mes_groupes_grossiste_screen.dart', s => {
  if (!s.includes("import '../widgets/tab_navigation_scope.dart';")) {
    s = "import '../widgets/tab_navigation_scope.dart';\n" + s;
  }
  const regex = /leading:\s*Navigator\.of\(context\)\.canPop\(\)\s*\?\s*IconButton\([\s\S]*?\)\s*:\s*null,/;
  const replacement = `leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          tooltip: "Retour",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              TabNavigationScope.switchToTab(context, 0);
            }
          },
        ),`;
  return s.replace(regex, replacement);
});

// 7. explorer_screen.dart
replaceInFile('dogo-flutter/lib/commercant/explorer_screen.dart', s => {
  if (!s.includes("import '../widgets/tab_navigation_scope.dart';")) {
    s = "import '../widgets/tab_navigation_scope.dart';\n" + s;
  }
  const regex = /leading:\s*Navigator\.of\(context\)\.canPop\(\)\s*\?\s*IconButton\([\s\S]*?\)\s*:\s*null,/;
  const replacement = `leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context)),
          tooltip: "Retour",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              TabNavigationScope.switchToTab(context, 0);
            }
          },
        ),`;
  return s.replace(regex, replacement);
});

// 8. mes_commandes_screen.dart
replaceInFile('dogo-flutter/lib/commercant/mes_commandes_screen.dart', s => {
  if (!s.includes("import '../widgets/tab_navigation_scope.dart';")) {
    s = "import '../widgets/tab_navigation_scope.dart';\n" + s;
  }
  const regex = /leading:\s*Navigator\.of\(context\)\.canPop\(\)\s*\?\s*IconButton\([\s\S]*?\)\s*:\s*null,/;
  const replacement = `leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.couleurTexte(context), size: 22),
          tooltip: "Retour",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              TabNavigationScope.switchToTab(context, 0);
            }
          },
        ),`;
  s = s.replace(regex, replacement);
  s = s.replace('titleSpacing: Navigator.of(context).canPop() ? 0 : 20,', 'titleSpacing: 0,');
  return s;
});

// 9. profil_commercant_screen.dart
replaceInFile('dogo-flutter/lib/commercant/profil_commercant_screen.dart', s => {
  const regex = /icon:\s*Icon\(\s*Navigator\.of\(context\)\.canPop\(\)\s*\?\s*Icons\.arrow_back_rounded\s*:\s*Icons\.close_rounded,/;
  const replacement = `icon: const Icon(
                      Icons.arrow_back_rounded,`;
  return s.replace(regex, replacement);
});

