# ROLE

Tu es un agent spécialisé en python, flutter et BDD.

## OBJECTIF

Spécifier et implémenter une évolution produit mesurable couvrant :

1. **Page day_off** : retirer l’action d’export PDF roadmap côté UI.
2. **Backend day_off** : bloquer explicitement l’endpoint roadmap pour une date `day_off`.
3. **Export complet day_off** : n’exporter que les éléments visibles dans la fiche date `day_off`.
4. **Export tournée** : produire un PDF compilé des exports complets de chaque date, dans l’ordre.
5. **Export tournée** : ajouter une page de garde avec nom de la tournée + liste des dates non `day_off` (`date`, `ville`, `lieu de concert`).
6. **Exports PDF** : retirer la section `Suivi / Tracking` de l’export PDF complet.

### Critères de succès (mesurables)

- En UI day_off : aucun bouton roadmap visible.
- En backend : appel roadmap sur `day_off` retourne une erreur métier explicite.
- PDF complet day_off contient uniquement :
  - infos de date visibles (`type`, `date`)
  - `hébergement`
  - `note`
- PDF complet (tous types de dates) : aucune section `Suivi / Tracking` affichée.
- Export tournée :
  - inclut toutes les dates (concert + day_off) au format export complet de chaque date,
  - ordonnées par date croissante,
  - commence par une page de garde,
  - liste de garde inclut uniquement les dates non `day_off`,
  - n’affiche aucun bloc `Suivi / Tracking` dans les pages compilées.
- Si ville/lieu manquant sur page de garde : afficher `-`.

## CONTEXTE

- Projet : TourApp (FastAPI + SQLModel + Flutter/Riverpod + ReportLab)
- Décisions utilisateur validées :
  - roadmap day_off bloqué backend + caché frontend,
  - export complet day_off limité aux éléments visibles,
  - export tournée = compilation des exports complets de chaque date,
  - page de garde avec tri croissant,
  - fallback affichage `-` pour ville/lieu manquants,
  - suppression du bloc `Suivi / Tracking` dans les exports PDF complets,
  - export tournée n’utilise jamais roadmap.

## PROCESS

## 1. ANALYSE

### Comprendre le besoin

- Le mode `day_off` doit appliquer des règles strictes sur les exports.
- Le comportement UI et API doit être cohérent (pas de bouton + endpoint bloqué).
- L’export tournée devient un document consolidé multi-pages :
  - couverture,
  - puis une section/ensemble de pages par date,
  - en respectant les règles d’export complet de chaque type de date.

### Ambiguïtés résiduelles

Aucune ambiguïté bloquante (règles confirmées).

### Risques

- Risque de divergence entre rendu day_off UI et rendu PDF.
- Risque de pagination sur export tournée long.
- Risque de confusion si garde liste des concerts diffère de l’ordre réel des sections.

## 2. PLAN

### Décomposition

1. **Backend exports day**
   - Bloquer `/days/{id}/export/roadmap` si `type == day_off`.
   - Adapter `build_day_full_pdf` pour respecter la visibilité day_off.

2. **Frontend DayScreen**
   - Masquer bouton roadmap en `day_off`.
   - Conserver export complet disponible.

3. **Backend export tournée**
   - Refaire `build_tour_full_pdf` en mode compilation :
     - page de garde,
     - puis export complet par date, ordonné croissant.

4. **Backend export complet**
   - Retirer le bloc `Suivi / Tracking` de l’export PDF complet.

5. **Règles page de garde**
   - Nom tournée.
   - Liste des dates non `day_off` seulement.
   - Colonnes : date, ville, lieu.
   - fallback `-` si champ manquant.

6. **Validation**
   - tests manuels API day_off roadmap,
   - smoke export day_off/full,
   - smoke export tournée.

### Stratégie

- Prioriser la cohérence métier : mêmes règles de visibilité UI ↔ PDF ↔ API.
- Réutiliser la logique existante de rendu complet pour éviter les divergences.
- Garder des fallbacks robustes (`-`) pour les champs incomplets.

## 3. EXECUTION

### Étape A — Backend route roadmap day_off

- Dans `days.py`, endpoint roadmap :
  - récupérer la date,
  - si `day.type == day_off` => `409` (ou `422`) avec message explicite,
  - sinon comportement actuel.

### Étape B — Rendu PDF complet day_off

- Dans `pdf_export.py`, `build_day_full_pdf` :
  - si `day_off`, inclure uniquement :
    - `type`, `date`,
    - `hebergement`,
    - `day_note`.
  - exclure :
    - ville/lieu/adresse,
    - contact/deal,
    - tracking,
    - planning/schedule.

### Étape C — Frontend DayScreen

- Conditionner l’affichage des boutons export :
  - `day_off` : afficher uniquement export complet,
  - `concert` : export complet + roadmap.

### Étape D — Export tournée compilé

- `build_tour_full_pdf` :
  - Générer page de garde :
    - titre = nom tournée,
    - tableau des dates non `day_off` (date, ville, lieu), tri croissant.
  - Pour chaque date (tri croissant), injecter rendu export complet de la date dans le document final.
    - `concert` => rendu complet concert
    - `day_off` => rendu complet day_off restreint
    - aucun bloc `Suivi / Tracking` dans les pages exportées et compilées

### Étape E — Cas de données manquantes

- Pour garde concert :
  - ville vide => `-`
  - lieu vide => `-`

### Justification des choix

- Bloquer roadmap day_off en backend garantit l’intégrité métier même si l’UI change.
- Limiter le PDF day_off aux éléments visibles supprime les incohérences utilisateur.
- Compilation tournée par export complet unifie la logique et réduit les divergences futures.

## 4. REVIEW

### Vérifier

- UI day_off : bouton roadmap absent.
- API roadmap day_off : erreur explicite.
- PDF complet day_off : contient seulement type/date/hébergement/note.
- PDF complet (concert/day_off) : ne contient pas de section `Suivi / Tracking`.
- Export tournée :
  - page de garde présente,
  - liste garde sans day_off,
  - fallback `-` appliqué,
  - ordre par date croissante,
  - sections de dates cohérentes avec export complet individuel.

## 5. AMELIORATION

### Version améliorée

- Ajouter table des matières avec numéro de page par date.
- Ajouter badge visuel `concert` / `day off` sur chaque section date.
- Ajouter compteur en couverture (`X concerts`, `Y day off`).

### Optimisations

- Stream PDF pour très longues tournées.
- Mettre en cache les exports journaliers et recomposer la tournée à la volée.

## USER STORIES

1. En tant qu’utilisateur, je ne veux pas voir d’export roadmap sur une date day_off.
2. En tant qu’utilisateur, je veux que le backend refuse roadmap sur day_off même en appel direct API.
3. En tant qu’utilisateur, je veux que l’export complet d’un day_off reflète strictement ce que je vois dans la fiche.
4. En tant qu’utilisateur, je veux exporter toute la tournée dans un seul PDF.
5. En tant qu’utilisateur, je veux une page de garde claire avec nom de tournée et liste des concerts.
6. En tant qu’utilisateur, je veux que les dates soient ordonnées de la plus ancienne à la plus récente.

## CRITÈRES D’ACCEPTATION

1. **Roadmap day_off bloqué** : UI day_off sans bouton roadmap et API roadmap day_off en erreur métier explicite.
2. **Export complet day_off restreint** : le PDF day_off n’affiche que `type`, `date`, `hébergement`, `note`, sans élément non visible en fiche.
3. **Tracking retiré des exports complets** : aucun PDF complet n’affiche de bloc `Suivi / Tracking`.
4. **Export tournée compilé** : le PDF commence par une page de garde, liste uniquement les dates non `day_off` (`date`, `ville`, `lieu`) avec fallback `-`, conserve l’ordre croissant des dates, et chaque section date correspond au rendu “export complet date” sans bloc `Suivi / Tracking`.

## EDGE CASES

- Tournée sans date : erreur métier explicite.
- Tournée avec uniquement day_off :
  - page de garde sans lignes concert,
  - sections day_off présentes après la garde.
- Concert sans ville/lieu : affichage `-` sur garde.
- Day_off avec champs historiques remplis (city/venue/schedule) : non exportés dans PDF complet day_off.
- Tentative d’appel direct roadmap sur day_off : refus API systématique.

## PSEUDO LOGIQUE

```text
exportDayRoadmap(dayId):
  day = getDay(dayId)
  if day.type == 'day_off':
    raise BusinessError("Roadmap export unavailable for day_off")
  publicSchedules = getPublicSchedules(dayId)
  if publicSchedules.empty:
    raise BusinessError("No public schedule to export")
  return buildRoadmapPdf(day, publicSchedules)

buildDayFullPdf(day):
  if day.type == 'day_off':
    render date info (type/date)
    render hebergement
    render note
    return pdf
  else:
    render full concert layout
    return pdf

buildTourFullPdf(tourId):
  days = getDaysByTour(tourId).sortByDateAsc()
  if days.empty: raise BusinessError("Tour has no dates")

  renderCover(
    tourName,
    concertsOnly = days.filter(type != 'day_off').map(
      date,
      city or '-',
      venue or '-'
    )
  )

  for day in days:
    append(buildDayFullPdf(day))

  return mergedPdf
```

## FORMAT DE SORTIE

Markdown structuré prêt implémentation (backend + frontend + BDD), incluant user stories, critères d’acceptation, edge cases et pseudo-logique.
