# ROLE

Tu es un agent spécialisé en python, flutter et BDD.

## OBJECTIF

Spécifier et implémenter une évolution produit mesurable couvrant :

1. Ajout d’un champ **adresse** en plus de `city` pour les dates `concert`.
2. Suppression **complète** de la checklist (UI + API + modèle + BDD/migration).
3. Positionnement de la section **Note** en bas de la fiche date.
4. Ajout d’un booléen à cocher **Promo envoyé / Promo sent** (concert uniquement).
5. Ajout d’un booléen à cocher **Coplateau / Co-headline** (concert uniquement).
6. Si `coplateau == true`, affichage de 2 cases supplémentaires :
   - **Feuille de route envoyée / Roadmap sent**
   - **Conversation backline / Backline conversation**
7. Si `coplateau` repasse à `false`, les 2 booléens dépendants sont automatiquement remis à `false`.
8. Ajout d’une nouvelle zone texte libre **Hébergement / Accommodation**, visible pour `concert` **et** `day_off`.
9. Renommer la zone **Finance** en **Deal** (FR/EN).

### Critères de succès (mesurables)

- `address` est obligatoire à la création/mise à jour d’un `concert`.
- `address` est masqué en UI pour `day_off`.
- Aucun écran ni endpoint checklist n’est disponible après migration.
- `promo_sent` et `coplateau` sont visibles uniquement pour `concert` et par défaut à `false`.
- `roadmap_sent` et `backline_conversation` apparaissent seulement si `coplateau == true`.
- Quand `coplateau` devient `false`, `roadmap_sent = false` et `backline_conversation = false`.
- La section `note` est rendue en dernière position dans la fiche date.
- `hebergement` est éditable pour tous les types de dates (`concert`, `day_off`) avec limite de 3000 caractères.
- La section affichée dans la fiche date s’intitule `Deal` (et non `Finance`).

## CONTEXTE

- Projet : TourApp (FastAPI + SQLModel + MariaDB + Flutter/Riverpod)
- Contraintes :
  - Conserver l’isolation multi-tenant via `group_id` JWT.
  - Garder la logique métier existante sur les `day_off` (masquage de champs non pertinents).
  - Respecter les traductions FR/EN validées.
- Décisions utilisateur validées :
  - `address` obligatoire en `concert`, masqué en `day_off`.
  - Checklist : suppression complète.
  - `note` en bas.
  - Cases à cocher concert-only, défaut `false`.
  - Dépendance `coplateau` avec reset automatique des sous-cases.
  - `hebergement` visible concert et day_off, limite 3000.
  - Traductions validées :
    - `Promo envoyé / Promo sent`
    - `Coplateau / Co-headline`
    - `Feuille de route envoyée / Roadmap sent`
    - `Conversation backline / Backline conversation`
    - `Hébergement / Accommodation`

## PROCESS

## 1. ANALYSE

### Comprendre le besoin

- **Adresse concert** : enrichir le modèle date avec un champ obligatoire pour les concerts.
- **Suppression checklist** : retirer totalement la fonctionnalité, y compris dette technique backend.
- **Réorganisation UI** : déplacer `Note` en bas pour la hiérarchie demandée.
- **Nouveaux booléens métier** : formaliser le suivi promo/coplateau et ses dépendances.
- **Texte Hébergement** : nouveau bloc libre transversal à tous types de dates.

### Ambiguïtés résiduelles

Aucune ambiguïté bloquante (réponses utilisateur reçues).

### Risques

- Risque migration : suppression checklist impacte références legacy (providers/routes/tests).
- Risque données : records existants sans `address` sur `concert`.
- Risque UX : confusion si sous-cases coplateau visibles/invisibles sans animation claire.
- Risque validation : comportement incohérent entre create/update/backfill.

## 2. PLAN

### Décomposition

1. **Data model & DB migration**
   - Ajouter `address` (concert obligatoire), `promo_sent`, `coplateau`, `roadmap_sent`, `backline_conversation`, `hebergement`.
   - Supprimer structure checklist (tables/modèles liés).

2. **Backend API**
   - Validation stricte : `address` requis pour `concert`, masqué/ignoré pour `day_off`.
   - Validation booléens dépendants : reset auto des sous-cases quand `coplateau=false`.
   - Validation `hebergement` max 3000 chars.
   - Supprimer endpoints checklist.

3. **Frontend DayScreen**
   - Ajouter champ `address` pour concert.
   - Ajouter cases FR/EN : promo/coplateau + dépendances conditionnelles.
   - Ajouter section `Hébergement`.
   - Retirer bloc checklist.
   - Positionner `Note` en bas.

4. **I18n FR/EN**
   - Ajouter toutes les clés validées, fallback EN déjà en place.

5. **Nettoyage technique**
   - Retirer providers/checklist calls/routes/tests obsolètes.

### Stratégie

Évolution contrôlée avec migrations rétrocompatibles de données :

- Backfill initial : valeurs booléennes à `false`.
- Pour concerts legacy sans adresse : stratégie de fallback temporaire puis enforcement UI/API.
- Suppression checklist en une passe complète pour éviter code mort.

## 3. EXECUTION

### Étape A — Modèle & migration

- Étendre `Day` avec :
  - `address: Optional[str]` (métier obligatoire en concert)
  - `promo_sent: bool = False`
  - `coplateau: bool = False`
  - `roadmap_sent: bool = False`
  - `backline_conversation: bool = False`
  - `hebergement: Optional[str]`
- Migration données :
  - Ajouter colonnes avec defaults booléens `false`.
  - Vérifier cohérence des concerts sans adresse (fallback technique temporaire en migration si nécessaire).
- Supprimer les artefacts checklist (table + modèles + références).

### Étape B — Règles métier API

- Create/Update Day :
  - si `type == concert` : `address` non vide obligatoire.
  - si `type == day_off` : masquer côté UI, ne pas exiger `address`.
- Dépendance coplateau :
  - si `coplateau == false` alors forcer
    - `roadmap_sent = false`
    - `backline_conversation = false`
- `hebergement` : trim + max 3000, autorisé pour tous types.

### Étape C — Frontend (fiche date)

- Section Date Info : ajouter `address` (concert uniquement).
- Ajouter cases :
  - `Promo envoyé / Promo sent`
  - `Coplateau / Co-headline`
- Si `coplateau` coché : afficher
  - `Feuille de route envoyée / Roadmap sent`
  - `Conversation backline / Backline conversation`
- Si `coplateau` décoché : reset visuel + envoi reset backend.
- Retirer complètement la section checklist.
- Ajouter section `Hébergement / Accommodation`.
- Déplacer section `Note` tout en bas de la liste.

### Étape D — Traductions

- Ajouter clés FR/EN correspondantes dans la couche i18n.
- Renommer les clés techniques de section pour cohérence sémantique :
  - `day.finance` -> `day.deal`
  - `day.editFinance` -> `day.editDeal`
- Vérifier fallback EN pour clés manquantes.

### Étape E — Nettoyage suppression checklist

- Backend : supprimer routes/services/modèles checklist.
- Frontend : supprimer provider checklist + appels API + widgets.
- Tests : adapter/supprimer tests checklist obsolètes.

### Justification des choix

- L’obligation `address` sur concert améliore l’opérationnel terrain.
- Le reset automatique des sous-cases empêche les états incohérents.
- La suppression complète checklist simplifie maintenance et UX.
- `hebergement` transversal répond au besoin logistique concert + day_off.

## 4. REVIEW

### Vérifier

- Cohérence métier :
  - concert sans adresse refusé.
  - day_off sans adresse accepté et champ masqué en UI.
  - sous-cases coplateau visibles uniquement si `coplateau=true`.
  - reset effectif des sous-cases au décochage.

- Suppression checklist :
  - aucune trace UI/API/modèle résiduelle.

- UX :
  - `note` bien en dernière section.
  - `hebergement` présent et éditable pour tous types.

- i18n :
  - labels FR/EN exacts validés.

## 5. AMELIORATION

### Version améliorée

- Historiser date d’envoi promo/roadmap (timestamp) au lieu de bool simple.
- Ajouter un indicateur visuel de complétude des infos concert.
- Pré-remplissage d’adresse via historique de salle.

### Optimisations

- Validation frontend immédiate sur `address` pour éviter round-trip API.
- Ajout de tests unitaires métier pour règle coplateau/reset.
- Script de migration dédié pour purge checklist et audit de données.

## USER STORIES

1. En tant qu’utilisateur, je veux renseigner une adresse de concert en plus de la ville.
2. En tant qu’utilisateur, je veux que l’adresse soit obligatoire pour un concert.
3. En tant qu’utilisateur, je ne veux plus voir de checklist dans l’app.
4. En tant qu’utilisateur, je veux que la note soit affichée en bas de la fiche date.
5. En tant qu’utilisateur, je veux cocher `Promo envoyé / Promo sent` sur les concerts.
6. En tant qu’utilisateur, je veux cocher `Coplateau / Co-headline` sur les concerts.
7. En tant qu’utilisateur, si coplateau est actif, je veux voir les cases `Roadmap sent` et `Backline conversation`.
8. En tant qu’utilisateur, si je décoche coplateau, je veux que les cases dépendantes reviennent à false.
9. En tant qu’utilisateur, je veux un champ `Hébergement / Accommodation` sur concert et day_off.

## CRITÈRES D’ACCEPTATION

1. **Adresse concert obligatoire**
   - Lors de la création/édition d’un `concert`, `address` vide est refusé.
   - Pour `day_off`, le champ adresse est masqué.

2. **Suppression checklist complète**
   - Aucun onglet/section checklist dans l’UI.
   - Aucun endpoint checklist accessible.
   - Aucun modèle/table checklist utilisé en runtime.

3. **Ordre d’affichage**
   - La section `Note` est rendue en bas de la fiche date.

4. **Cases concert only**
   - `Promo envoyé / Promo sent` et `Coplateau / Co-headline` visibles uniquement pour concert.
   - Valeur initiale par défaut : non coché (`false`).

5. **Dépendance coplateau**
   - Si `coplateau=true`, afficher les cases `Feuille de route envoyée / Roadmap sent` et `Conversation backline / Backline conversation`.
   - Si `coplateau=false`, ces deux valeurs sont forcées à `false` (UI + backend).

6. **Hébergement**
   - Le champ `Hébergement / Accommodation` est disponible pour concert et day_off.
   - Longueur max = 3000 caractères.

7. **Traductions**
  Les labels FR/EN validés sont présents et fonctionnels.
  Les clés i18n de la section Deal utilisent `day.deal` et `day.editDeal`.

## EDGE CASES

- Concert legacy sans adresse : comportement de migration défini (fallback technique puis correction utilisateur).
- Passage `concert -> day_off` : adresse/flags concert masqués; dépendances coplateau reset à false.
- Passage `day_off -> concert` : adresse redevient obligatoire avant sauvegarde.
- Coplateau coché/décoché rapidement : dernier état persistant gagne, sous-cases cohérentes.
- `hebergement` vide : accepté; `hebergement > 3000` refusé.
- Traduction manquante FR : fallback EN appliqué.

## PSEUDO LOGIQUE

```text
validateDayPayload(payload):
  payload.hebergement = normalizeText(payload.hebergement, max=3000)

  if payload.type == 'concert':
    if isEmpty(payload.address):
      raise ValidationError("address is required for concert")
  else if payload.type == 'day_off':
    hideField('address') in UI

  payload.promo_sent = payload.promo_sent ?? false
  payload.coplateau = payload.coplateau ?? false
  payload.roadmap_sent = payload.roadmap_sent ?? false
  payload.backline_conversation = payload.backline_conversation ?? false

  if payload.coplateau == false:
    payload.roadmap_sent = false
    payload.backline_conversation = false

  return payload

renderDayScreen(day):
  show Date Info
  if day.type == 'concert':
    show city
    show venue
    show address (required)
    show checkbox promo_sent
    show checkbox coplateau
    if coplateau checked:
      show checkbox roadmap_sent
      show checkbox backline_conversation

  show contact
  show deal
  show hebergement
  show schedule
  show note (last section)

removeChecklistFeature():
  remove checklist models/routes/providers/widgets/tests
  drop checklist table/relations in migration
```

## FORMAT DE SORTIE

Markdown structuré prêt implémentation (backend + frontend + BDD), incluant user stories, critères d’acceptation, edge cases et pseudo-logique.
