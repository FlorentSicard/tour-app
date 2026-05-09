# ROLE

Tu es un agent spécialisé en python, flutter et BDD.

## OBJECTIF

Spécifier et implémenter une évolution produit mesurable couvrant :

1. Affichage du détail d’une date **sans sections repliables** (tout visible immédiatement dans la fiche date).
2. Édition de `city` et `venue` **dans la fiche date** après création.
3. Gestion des `day_off` dans les tournées avec données limitées (`date` + `note`) et masquage des autres informations.
4. Ajout d’un type de visibilité `public` / `private` sur chaque item de schedule (à la création + éditable).
5. Export PDF complet d’une date (incluant aussi les schedules `private`).
6. Export PDF “roadmap” (schedules `public` uniquement) depuis la fiche date, bloqué si aucun item public.
7. Export PDF global d’une tournée (toutes les dates de la tournée) depuis le menu de tournée.

### Critères de succès (mesurables)

- Fiche date sans UI de type `ExpansionTile` pour Contact/Finance/Schedule/Note.
- `city` et `venue` modifiables après création, persistés et visibles au refresh.
- `day_off` : seuls `date` + `note` visibles; autres champs masqués mais conservés en base.
- Chaque schedule possède `visibility in {public, private}` avec CRUD complet.
- Export date complet génère un PDF incluant tout (y compris schedule private).
- Export roadmap date génère un PDF avec uniquement schedule public et est bloqué si vide.
- Export tournée génère un PDF multi-dates.

## CONTEXTE

- Projet : TourApp (FastAPI + SQLModel + MariaDB + Flutter/Riverpod)
- Contraintes :
  - Conserver l’isolation multi-tenant via `group_id` JWT.
  - Ne pas modifier le menu qui liste toutes les dates (demande explicite).
  - Respecter les noms de fichiers export validés.
- Input utilisateur (validé) :
  - Détail date sans listes déroulantes.
  - Édition `city` + `venue` dans la fiche date.
  - `day_off` métier confirmé (masquage UI, conservation DB).
  - Schedule par item avec `public/private`, éditable après création.
  - Export complet inclut aussi private.
  - Export public bloqué si aucun item public.

## PROCESS

## 1. ANALYSE

### Comprendre le besoin

- **UI date toujours ouverte** : retirer les blocs repliables, afficher les sections directement.
- **Édition lieu** : `city` et `venue` éditables post-création depuis la même fiche.
- **Day off** : un type métier réduit (`date`, `note`) côté affichage.
- **Confidentialité planning** : visibilité par item schedule.
- **Exports PDF** :
  - complet date (tout)
  - roadmap public date (public only)
  - global tournée (toutes dates)

### Ambiguïtés résiduelles

Aucune ambiguïté bloquante (réponses utilisateur reçues).

### Risques

- Risque UX : densité visuelle plus forte sans sections repliables.
- Risque métier : confusion sur données masquées `day_off` mais non supprimées.
- Risque export : contenu incorrect si filtrage `public/private` mal appliqué.
- Risque perf : export tournée potentiellement volumineux.

## 2. PLAN

### Décomposition

1. **Data model**
   - Ajouter `visibility` sur `ScheduleItem` (`public`/`private`).

2. **Backend API**
   - Support create/update `visibility` schedule.
   - Endpoint export PDF date complet.
   - Endpoint export PDF date roadmap (public only, bloque si vide).
   - Endpoint export PDF tournée globale.

3. **Frontend DayScreen**
   - Suppression des sections déroulantes.
   - Edition inline/modal de `city` et `venue`.
   - Affichage conditionnel `day_off` (date + note uniquement).
   - CRUD schedule avec visibilité editable.

4. **Frontend Tour menu**
   - Ajouter action export global tournée.

5. **Nommage PDF**
   - Export général date : `YYYY-MM-DD_city_venue.pdf`
   - Export public roadmap : `YYYY-MM-DD_city_venue_roadmap.pdf`
   - Export général tournée : nom cohérent (ex: `tour_<tour_name>_YYYYMMDD.pdf`)

### Stratégie

Évolution additive et compatible :

- Masquage UI pour `day_off` sans purge DB.
- Migration simple sur schedule (`visibility` default `private` ou `public` selon règle à fixer en implémentation; recommandé `private` pour sécurité).

## 3. EXECUTION

### Étape A — Modèle & migration

- Ajouter enum ou string contrainte pour `ScheduleItem.visibility`.
- Migration DB : colonne non nulle avec valeur par défaut.

### Étape B — API schedule

- Create schedule : `visibility` obligatoire (`public`|`private`).
- Update schedule : autoriser modification de `time`, `label`, `notes`, `visibility`.
- List schedule : renvoyer `visibility`.

### Étape C — UI fiche date

- Remplacer les sections repliables par sections statiques visibles.
- Boutons d’édition sur `city`/`venue` dans la fiche.
- Si `type == day_off` :
  - afficher uniquement `date` + `day_note`
  - masquer contact/finance/schedule (données conservées en base).

### Étape D — Exports PDF

- **Export date complet** : inclut toutes les sections + schedules `public` et `private`.
- **Export date roadmap** : inclut uniquement schedules `public` + date/ville/lieu.
  - titre centré obligatoire : `Feuille de route / Roadmap`.
  - labels obligatoires : `Ville / City` et `Lieu de concert / Venue`.
  - si `city` ou `venue` absent : afficher `❌` (croix rouge) dans le PDF roadmap.
  - présentation roadmap améliorée : en-tête visuel, bloc infos, tableau planning, pagination propre.
  - si aucun schedule public : renvoyer erreur métier (ex 400/409) avec message explicite.
- **Export tournée** : agrège toutes les dates de la tournée dans un seul PDF.

### Étape E — Intégration frontend

- Boutons dans fiche date :
  - “Exporter PDF complet”
  - “Exporter roadmap public”
- Bouton dans menu tournée :
  - “Exporter PDF de la tournée”

### Étape F — UX export et téléchargement

- Emplacement des actions export :
  - **Fiche date (`DayScreen`)** : 2 boutons visibles en haut de page
    - `Export Full PDF`
    - `Export Roadmap PDF`
  - **Fiche tournée (`TourScreen`)** : icône PDF dans l’`AppBar` (en haut à droite)
- Comportement au clic :
  - L’application appelle l’endpoint export correspondant.
  - Récupère le binaire PDF (`responseType: bytes`).
  - Lit `Content-Disposition` pour récupérer le nom de fichier serveur.
  - Déclenche le téléchargement navigateur (Flutter Web) avec ce nom.
  - Affiche un feedback utilisateur (snackbar succès/erreur).
- Compatibilité :
  - **Web** : téléchargement automatique activé.
  - **Mobile/Desktop** : à prévoir via sauvegarde locale dédiée si besoin produit.

### Justification des choix

- Visibilité `public/private` par item répond précisément au besoin éditorial.
- Masquage `day_off` préserve l’historique et évite pertes de données.
- Exports séparés (complet vs roadmap) couvrent usage interne et diffusion externe.

## 4. REVIEW

### Vérifier

- Cohérence :
  - UI date non repliable.
  - règles `day_off` respectées.
  - visibilité schedule persistée et modifiable.
  - noms de fichiers export conformes.

- Erreurs :
  - blocage roadmap sans item public.
  - gestion caractères spéciaux dans `city/venue` pour nom de fichier.
  - roadmap : affichage `❌` rouge si `city/venue` absents.
  - vérifier que le titre roadmap est centré et exact (`Feuille de route / Roadmap`).
  - vérifier les labels roadmap (`Ville / City`, `Lieu de concert / Venue`).

- Oublis :
  - contrôle tenant sur endpoints export.
  - timezone/format date dans PDF.
  - feedback utilisateur lors de génération/téléchargement.

## 5. AMELIORATION

### Version améliorée

- Prévisualisation PDF avant téléchargement.
- Templates PDF personnalisables par groupe.
- Tri manuel des schedules dans roadmap.

### Optimisations

- Génération PDF asynchrone pour gros exports tournée.
- Cache court terme des exports identiques.
- Journalisation des exports (audit).

## USER STORIES

1. En tant qu’utilisateur, je veux voir toutes les informations d’une date sans cliquer sur des flèches de dépliage.
2. En tant qu’utilisateur, je veux modifier la ville et le lieu d’une date après création.
3. En tant qu’utilisateur, je veux créer des `day_off` dans une tournée et n’afficher que date + note.
4. En tant qu’utilisateur, je veux définir un schedule en `public` ou `private` à la création.
5. En tant qu’utilisateur, je veux pouvoir modifier la visibilité d’un schedule ensuite.
6. En tant qu’utilisateur, je veux exporter une date complète en PDF (incluant private).
7. En tant qu’utilisateur, je veux exporter une roadmap publique d’une date en PDF.
8. En tant qu’utilisateur, je veux exporter toutes les dates d’une tournée en un PDF.

## CRITÈRES D’ACCEPTATION

1. **Fiche date sans déroulant**
   - Étant sur une date, je vois contact/finance/schedule/note sans interaction de dépliage.

2. **Édition lieu**
   - Quand je modifie `city` et `venue` depuis la fiche date, les valeurs sont sauvegardées et visibles après refresh.

3. **Day off affichage**
   - Quand une date est `day_off`, seules `date` et `day_note` sont visibles.
   - Les autres données historiques restent en base.

4. **Schedule visibility create/edit**
   - À la création d’un item schedule, je dois choisir `public` ou `private`.
   - Je peux modifier cette visibilité après création.

5. **Export date complet**
   - Le PDF généré contient toutes les informations de la date + schedules publics et privés.
   - Nom : `YYYY-MM-DD_city_venue.pdf`.

6. **Export roadmap public**
  Le PDF contient uniquement schedules `public` + date/ville/lieu.
  Le titre du document est centré et vaut exactement `Feuille de route / Roadmap`.
  Les champs sont libellés `Ville / City` et `Lieu de concert / Venue`.
  Si `city` ou `venue` est vide, le PDF affiche `❌` en rouge.
  Le rendu roadmap est structuré (en-tête, bloc infos, tableau planning, pagination).
  Nom : `YYYY-MM-DD_city_venue_roadmap.pdf`.
  Si aucun schedule public : export bloqué avec message explicite.

7. **Export tournée global**
   - Depuis le menu tournée, je peux générer un PDF contenant toutes les dates de la tournée.

8. **Téléchargement effectif côté UI**
  Depuis les actions d’export (date/tournée), le fichier PDF est réellement téléchargé dans le navigateur.
  Le nom de fichier provient de `Content-Disposition` (avec fallback si absent).

## EDGE CASES

- `city` ou `venue` vides : fallback nom fichier (`unknown`).
- `city` vide dans roadmap : afficher `❌` rouge dans le champ `Ville / City`.
- `venue` vide dans roadmap : afficher `❌` rouge dans le champ `Lieu de concert / Venue`.
- Caractères invalides pour nom fichier (`/\:*?"<>|`) : sanitization automatique.
- Passage `concert -> day_off` : contact/finance/schedule masqués mais non supprimés.
- Passage `day_off -> concert` : données historiques réapparaissent si présentes.
- Aucun schedule total : export complet autorisé, section schedule vide.
- Aucun schedule public : export roadmap refusé.
- Tournée sans date : export tournée refusé avec message métier.

## PSEUDO LOGIQUE

```text
renderDayScreen(day):
  show date header (always)
  if day.type == 'day_off':
    show day_note editor
    hide contact/finance/schedule sections
  else:
    show city/venue editable
    show contact section
    show finance section
    show schedule list with visibility badges

exportDayFull(dayId):
  payload = fetch day + all schedule + checklist + extra info
  pdf = render full template
  filename = `${date}_${city}_${venue}.pdf`
  return file

exportDayRoadmap(dayId):
  day, schedules = fetch
  publicSchedules = filter(schedules, visibility == 'public')
  if publicSchedules.empty:
    raise BusinessError("No public schedule to export")

  cityDisplay = day.city if day.city not empty else red("❌")
  venueDisplay = day.venue if day.venue not empty else red("❌")

  pdf = render roadmap template(
    title = "Feuille de route / Roadmap" (centered),
    cityLabel = "Ville / City",
    venueLabel = "Lieu de concert / Venue",
    city = cityDisplay,
    venue = venueDisplay,
    schedules = publicSchedules,
    layout = "styled header + info card + table + page breaks"
  )
  filename = `${date}_${city}_${venue}_roadmap.pdf`
  return file

exportTourFull(tourId):
  days = fetch days by tour
  if days.empty:
    raise BusinessError("Tour has no dates")
  pdf = render tour template(days)
  return file
```

## FORMAT DE SORTIE

Markdown structuré prêt implémentation (backend + frontend + BDD), incluant user stories, critères d’acceptation, edge cases et pseudo-logique.
