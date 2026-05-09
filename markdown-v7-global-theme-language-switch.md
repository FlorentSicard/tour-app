# ROLE

Tu es un agent spécialisé en python, flutter et BDD.

## OBJECTIF

Spécifier et implémenter une évolution produit mesurable couvrant :

1. Ajout d’un mode **nuit/jour** switchable via un bouton dans un **header global unique**.
2. Ajout d’un mode **français/anglais** switchable via un bouton à côté du switch thème dans ce même header.
3. Langue par défaut = **français**.
4. Thème par défaut = **nuit** (état visuel actuel).
5. Application des changements **immédiate sans rechargement de page** au clic sur chaque switch.
6. Traduction complète de l’application (UI, erreurs affichées, contenus liés aux exports visibles côté utilisateur).
7. Persistance des préférences en **local uniquement** (aucune synchro serveur).
8. Fallback de traduction = **anglais** si clé manquante.

### Critères de succès (mesurables)

- Deux contrôles visibles dans un header global unique : `Theme` + `Language`.
- Valeurs initiales au premier lancement : thème `dark`, langue `fr`.
- Au clic sur un switch, la page se recharge et le nouveau mode est appliqué.
- Les préférences sont conservées localement entre rechargements et redémarrages de l’app.
- Aucun endpoint backend supplémentaire n’est requis pour ce besoin.
- Tous les textes visibles utilisateur existent en FR et EN, avec fallback EN en cas d’absence FR.

## CONTEXTE

- Projet : TourApp (FastAPI + SQLModel + MariaDB + Flutter/Riverpod)
- Contraintes :
  - Pas de synchronisation serveur des préférences thème/langue.
  - Comportement uniforme sur toute l’application, y compris écran de login.
  - Header unique global (pas de duplication manuelle page par page si une architecture globale existe).
Décisions utilisateur validées :
- Defaults : FR + Dark.
- Portée : locale uniquement.
- Couverture : toute l’app.
- Changement : application immédiate sans rechargement de page.
- Traduction : tout traduire.
- Fallback : anglais.

## PROCESS

## 1. ANALYSE

### Comprendre le besoin

- **Thème global** : dark/light piloté par un switch unique en haut de l’app.
- **Langue globale** : FR/EN pilotée par un switch voisin.
- **UX attendue** : clic => sauvegarde locale => application immédiate dans le nouveau mode.
- **Portée produit** : toute l’application, sans exception fonctionnelle.
- **I18n complète** : inclure labels, boutons, messages d’erreur affichés, statuts, dialogues, exports visibles à l’utilisateur.

### Ambiguïtés résiduelles

Aucune ambiguïté bloquante (règles validées).

### Risques

- Risque UX : changement perçu comme abrupt si aucun feedback visuel.
- Risque i18n : oubli de clés sur certains écrans secondaires/dialogues.
- Risque cohérence : mélange FR/EN si fallback mal centralisé.
- Risque technique : header global contourné selon la structure de navigation existante.

## 2. PLAN

### Décomposition

1. **Gestion d’état global (frontend)**
   - Provider global `themeMode` + `locale`.
   - Source de vérité unique pour toute l’app.

2. **Persistance locale**
   - Sauvegarde dans storage local (ex: `SharedPreferences`).
   - Lecture au démarrage de l’app.

3. **Header global unique**
   - Intégrer un composant global contenant les deux switches.
   - Le rendre visible sur tous les écrans (login inclus).

4. **Internationalisation**
   - Mise en place ou extension du système ARB/localizations.
   - Couverture FR + EN pour tous les textes visibles.
   - Fallback EN centralisé.

5. **Comportement immédiat**
   - Après changement thème/langue : persister, puis mettre à jour l’UI immédiatement (rebuild global sans rechargement page).

6. **Validation qualité**
   - Vérifier persistance, fallback, couverture écrans, cohérence visuelle.

### Stratégie

Évolution principalement frontend, additive et sans impact API :

- Pas de migration BDD.
- Pas de modification backend obligatoire.
- Focus sur architecture globale de layout + i18n complète.

## 3. EXECUTION

### Étape A — Architecture globale UI

- Introduire un `AppShell` ou équivalent pour encapsuler le header global unique.
- S’assurer que toutes les routes passent par ce shell (y compris login).

### Étape B — Theme system

- Définir `ThemeMode.dark` comme valeur par défaut.
- Ajouter `ThemeData` light et dark cohérents.
- Switch dans le header : `dark <-> light`.

### Étape C — Locale system

- Définir locale par défaut `fr`.
- Ajouter/compléter les ressources `fr` et `en`.
- Fallback english si clé absente en FR.

### Étape D — Persistance locale

- Sauvegarder `theme_mode` et `locale_code` localement.
- Charger ces valeurs au bootstrap app.
- En absence de valeur locale : appliquer defaults (`dark`, `fr`).

### Étape E — Comportement au clic

Au clic switch thème/langue :
persister la nouvelle valeur,
appliquer immédiatement la nouvelle préférence dans l’UI,
réappliquer les providers globaux.

### Étape F — Traduction exhaustive

- Traduire et brancher :
  - navigation, titres, boutons, formulaires,
  - messages d’erreur affichés,
  - labels d’exports et notifications,
  - textes contextuels (empty states, confirmations, dialogs).

### Justification des choix

- Local-only répond à la règle métier « pas de synchro ».
- Header global unique garantit une UX homogène et découvrable.
- Fallback EN réduit le risque de régression en cas de clé manquante.
- Application immédiate améliore la fluidité UX et évite une rupture de navigation.

## 4. REVIEW

### Vérifier

- Cohérence :
  - Header unique présent partout.
  - Deux switches côte à côte et fonctionnels.
  - Defaults respectés au premier lancement.

Fonctionnel :
Changement thème => application immédiate => mode visuel conforme.
Changement langue => application immédiate => textes conformes.
Persistance locale effective après fermeture/réouverture.

- i18n :
  - Couverture FR/EN exhaustive sur écrans principaux + secondaires.
  - Fallback EN activé pour clés manquantes.

### Oublis fréquents à contrôler

- Écran login oublié dans le shell global.
- Snackbar/dialogs non localisés.
- Messages d’erreurs issus d’API non passés dans une couche de traduction UI.
- Textes d’export/PDF visibles utilisateur non localisés.

## 5. AMELIORATION

### Version améliorée

- Détection langue système au premier lancement (si aucun choix local) puis fallback FR.
- Animation douce lors du changement de thème immédiat.
- Indication visuelle du mode actif (icônes `sun/moon`, `FR/EN`).

### Optimisations

- Outil de contrôle de couverture i18n (clé présente FR+EN).
- Convention stricte de nommage des clés pour éviter les doublons.
- Tests widget ciblés sur changements de thème/langue.

## USER STORIES

1. En tant qu’utilisateur, je veux un switch thème dans le header global pour passer de nuit à jour.
2. En tant qu’utilisateur, je veux un switch langue à côté pour passer de français à anglais.
3. En tant qu’utilisateur, je veux que le français soit appliqué par défaut.
4. En tant qu’utilisateur, je veux que le mode nuit soit appliqué par défaut.
5. En tant qu’utilisateur, je veux que le changement soit visible immédiatement quand je clique.
6. En tant qu’utilisateur, je veux retrouver mon choix thème/langue après redémarrage de l’app.
7. En tant qu’utilisateur, je veux que toute l’app soit traduite, y compris erreurs et textes d’export visibles.

## CRITÈRES D’ACCEPTATION

1. **Header global unique**
   - Sur chaque écran, je vois un header unique avec deux contrôles : thème et langue.

2. **Defaults**
   - Au premier lancement sans préférence locale, l’app est en thème nuit et langue française.

3. **Switch thème**
   - Quand je bascule le switch thème, la préférence est sauvegardée localement.
   - Le thème est appliqué immédiatement sans rechargement de page.
   - Le thème affiché correspond au nouveau choix.

4. **Switch langue**
   - Quand je bascule FR/EN, la préférence est sauvegardée localement.
   - La langue est appliquée immédiatement sans rechargement de page.
   - Tous les textes visibles suivent la langue choisie.

5. **Persistance locale uniquement**
   - Aucun appel backend n’est nécessaire pour stocker ces préférences.
   - Le choix est conservé uniquement sur l’appareil/navigateur local.

6. **Fallback i18n**
   - Si une clé FR est absente, le texte anglais correspondant est affiché.

7. **Couverture traduction complète**
   - UI, messages d’erreur affichés, libellés export/PDF et dialogs sont disponibles en FR/EN.

## EDGE CASES

- Première ouverture en navigation privée : storage indisponible ou volatile => defaults appliqués sans crash.
- Données locales corrompues (`locale_code` invalide, thème inconnu) => reset vers defaults (`fr`, `dark`).
- Changement de langue sur un écran avec requête en cours => mise à jour propre sans état incohérent.
- Clé absente en FR **et** EN => afficher clé technique + log d’alerte (debug) pour correction.
- Écran sans AppBar natif => le header global reste visible via shell commun.
- Rechargements multiples rapides (double clic switch) => dernier choix persistant gagne.

## PSEUDO LOGIQUE

```text
bootstrapApp():
  theme = local.get('theme_mode') ?? 'dark'
  locale = local.get('locale_code') ?? 'fr'
  if !isValidTheme(theme): theme = 'dark'
  if !isValidLocale(locale): locale = 'fr'
  runApp(App(theme, locale, fallback='en'))

onThemeToggle(newTheme):
  local.set('theme_mode', newTheme)
   appState.theme = newTheme
   notifyListeners()

onLocaleToggle(newLocale):
  local.set('locale_code', newLocale)
   appState.locale = newLocale
   notifyListeners()

translate(key, activeLocale):
  if exists(key, activeLocale): return value(key, activeLocale)
  if exists(key, 'en'): return value(key, 'en')
  return key

renderGlobalHeader():
  show ThemeSwitch (dark/light)
  show LocaleSwitch (fr/en)
  place both at top of app (global shell)
```

## FORMAT DE SORTIE

Markdown structuré prêt implémentation (backend + frontend + BDD), incluant user stories, critères d’acceptation, edge cases et pseudo-logique.
