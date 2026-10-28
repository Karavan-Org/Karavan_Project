# Observations Hors Périmètre - Karavan

Ce document répertorie les points techniques ou éléments textuels relevés hors du périmètre strict des missions, préservés pour ne pas impacter les fonctionnalités existantes :

1. **Nomenclature & Ancien nom de produit** :
   - Certaines tables internes et préfixes de packages conservent la dénomination d'origine (`ml.dogo.*`, `dogo-flutter`, `dogo-angular`, `dogo-backend`, cookies `dogo_refresh_token`). L'ensemble des textes visibles utilisateurs affiche désormais le nom officiel « Karavan ».
2. **ArchUnit dans dogo-backend** :
   - La règle d'architecture ArchUnit interdit l'accès direct des classes du package `..web..` aux interfaces `..persistence..` ou se terminant par `Repository`. Tout nouveau contrôleur web doit impérativement transiter par une classe de service applicative du package `..application..`.
3. **Globe 3D en environnement de test jsdom** :
   - Dans l'environnement de test automatisé Vitest/JSDom (où WebGL n'est pas émulé nativement), `Globe3dComponent` intercepte l'absence de contexte WebGL et bascule en repli silencieux sans lever d'erreur bloquante.
