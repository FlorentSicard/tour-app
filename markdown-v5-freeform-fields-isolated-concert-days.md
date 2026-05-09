# Spécification Produit v5 — Freeform Fields & Dates Isolées

## 1) Analyse finale (avec décisions figées)

### Décisions confirmées

- **Contact texte libre** : **A** → remplacement des champs structurés (`contact_name`, `contact_phone`, `contact_email`).
- **Finance texte libre** : **A** → remplacement des champs structurés (`deal_amount`, `deal_currency`).
- **Note de date** : **B** → création d’un nouveau champ dédié `day_note`.
- **Édition Schedule** : **B** → édition via pattern **delete + create** (pas d’endpoint PATCH dédié).
- **Date isolée** : **Oui** → type forcé à `concert`.
- **Liste mixte** : **A** → une seule liste chronologique (tournées + dates isolées).
- **Action au clic date isolée** : **A** → ouverture directe de `DayScreen`.
- **Longueur max texte libre** : **3000 caractères**.

### Zones floues restantes

Aucune ambiguïté bloquante restante.

### Incohérences résolues

- Suppression de la coexistence ambiguë entre champs structurés et champs libres pour Contact/Finance.
- Clarification explicite du comportement d’édition Schedule sans endpoint PATCH.

### Informations manquantes non bloquantes

- Plan de migration des anciennes données Contact/Finance (stratégie retenue ci-dessous).
- Message UX exact en cas de dépassement 3000 caractères (défini ci-dessous en critères).

### Structure cible (prête implémentation)

1. Scope
2. User stories
3. Règles métier
4. Modèle de données
5. API contract
6. Comportement frontend
7. Critères d’acceptation
8. Edge cases
9. Pseudo-logique
10. Plan de migration

---

## 2) Questions de clarification nécessaires

Aucune question supplémentaire.

Toutes les décisions métier nécessaires ont été fournies.

---

## 3) Spécification claire et prête pour implémentation

## Scope

Implémenter les fonctionnalités suivantes :

1. Contact devient un **champ texte libre unique** (max 3000 caractères).
2. Finance devient un **champ texte libre unique** (max 3000 caractères).
3. Ajouter une **note de date** dédiée `day_note` (max 3000 caractères).
4. Permettre édition/suppression d’un item Schedule via **delete + create**.
5. Permettre la création d’une **date de concert isolée** depuis l’écran de création tournée.
6. Afficher dates isolées et tournées dans **une seule liste chronologique**.
7. Au clic sur une date isolée : ouverture directe de `DayScreen`.

---

## User stories

1. En tant qu’utilisateur, je veux saisir un contact libre pour une date afin d’écrire les infos utiles sans contrainte de format.
2. En tant qu’utilisateur, je veux saisir une information finance libre pour une date afin de noter les accords financiers complexes.
3. En tant qu’utilisateur, je veux saisir une note de date dédiée (`day_note`) distincte des autres champs.
4. En tant qu’utilisateur, je veux modifier un item schedule déjà créé.
5. En tant qu’utilisateur, je veux supprimer un item schedule.
6. En tant qu’utilisateur, je veux créer une date de concert isolée depuis la zone de création tournée.
7. En tant qu’utilisateur, je veux voir tournées et dates isolées dans une même liste triée par date.
8. En tant qu’utilisateur, je veux ouvrir une date isolée directement dans `DayScreen`.

---

## Règles métier

1. **Contact libre**
  - Nouveau champ canonique : `contact_text`.
  - Limite : 3000 caractères.
  - Les anciens champs structurés contact sont dépréciés (non utilisés par l’UI).

2. **Finance libre**
  - Nouveau champ canonique : `finance_text`.
  - Limite : 3000 caractères.
  - Les anciens champs structurés finance sont dépréciés (non utilisés par l’UI).

3. **Note de date**
  - Nouveau champ canonique : `day_note`.
  - Limite : 3000 caractères.

4. **Schedule edit/delete**
  - Édition = suppression de l’item existant puis création d’un nouvel item.
  - L’édition conserve l’ordre logique par horaire après rechargement.

5. **Date isolée**
  - Une date isolée est un `Day` avec `tour_id = null`.
  - `type` est forcé à `concert` lors de la création isolée.

6. **Liste mixte**
  - Une seule liste fusionnée, triée chronologiquement par date.
  - Les éléments doivent afficher un badge/type visuel (`TOUR` / `DATE ISOLÉE`).

7. **Sécurité / tenant**
  - Toutes les opérations restent scoppées au `group_id` porté par JWT.

---

## Modèle de données

### Évolution `days`

Ajouter :
- `contact_text` TEXT NULL
- `finance_text` TEXT NULL
- `day_note` TEXT NULL

Conserver temporairement (legacy, déprécié) :
- `contact_name`, `contact_phone`, `contact_email`
- `deal_amount`, `deal_currency`

### Validation

- Backend : rejeter avec 422 tout texte > 3000 caractères.
- Frontend : afficher compteur/validation avant envoi.

---

## API Contract

## Day create/update

### `POST /days/` (date isolée)

```json
{
  "tour_id": null,
  "date": "2026-07-15",
  "type": "concert",
  "city": "Paris",
  "venue": "Le Trianon",
  "contact_text": "Régie: ...",
  "finance_text": "Cachet net ...",
  "day_note": "Load-in 14h"
}
```

Règle : si création depuis mode “date isolée”, backend force `type = "concert"`.

### `PATCH /days/{day_id}`

Payload partiel autorisé :

```json
{
  "contact_text": "...",
  "finance_text": "...",
  "day_note": "..."
}
```

## Schedule

- `POST /days/{day_id}/schedule/` (create)
- `DELETE /days/{day_id}/schedule/{item_id}` (delete)

### Édition (logique applicative)

1. DELETE item existant
2. POST nouvel item avec nouvelles valeurs

---

## Comportement Frontend

## DayScreen

1. Section Contact
  - textarea multi-ligne (`contact_text`)
  - bouton Save

2. Section Finance
  - textarea multi-ligne (`finance_text`)
  - bouton Save

3. Section Note
  - textarea multi-ligne (`day_note`)
  - bouton Save

4. Section Schedule
  - item affiche actions `Edit` et `Delete`
  - `Edit` ouvre modal préremplie
  - `Save` exécute delete+create

## Écran création tournée

- Ajouter action explicite “Créer une date isolée”.
- En mode date isolée :
  - pas de `tour_id`
  - `type` imposé `concert`

## Liste principale (home)

- Fusion des tournées et dates isolées dans une liste unique triée par date.
- Affichage d’un marqueur de type.
- Clic date isolée → `DayScreen(dayId)`.

---

## Critères d’acceptation

1. **Contact libre**
  - Étant sur `DayScreen`, quand je saisis `contact_text` <= 3000 et sauvegarde, alors la donnée est persistée et visible après refresh.

2. **Finance libre**
  - Étant sur `DayScreen`, quand je saisis `finance_text` <= 3000 et sauvegarde, alors la donnée est persistée et visible après refresh.

3. **Note dédiée**
  - Étant sur `DayScreen`, quand je saisis `day_note` <= 3000 et sauvegarde, alors la donnée est persistée et visible après refresh.

4. **Validation longueur**
  - Si un champ libre dépasse 3000 caractères, alors la sauvegarde est bloquée (frontend) et rejetée (backend 422).

5. **Schedule édition**
  - Quand j’édite un item schedule et valide, alors l’ancien item n’est plus présent et le nouvel item apparaît avec les nouvelles valeurs.

6. **Schedule suppression**
  - Quand je supprime un item schedule, alors il disparaît de la liste après succès API.

7. **Création date isolée**
  - Quand je crée une date isolée depuis l’écran tournée, alors un `Day` est créé avec `tour_id = null` et `type = concert`.

8. **Liste mixte**
  - Quand je consulte la liste principale, alors je vois tournées + dates isolées dans une liste unique triée chronologiquement.

9. **Navigation date isolée**
  - Quand je clique une date isolée, alors l’app ouvre directement `DayScreen` sur cette date.

---

## Edge cases

1. Champ libre vide/whitespace → stocké en `null`.
2. Texte exactement 3000 caractères → accepté.
3. Texte 3001+ caractères → erreur de validation.
4. Édition schedule si DELETE réussit mais POST échoue → message d’erreur + proposition de réessai.
5. Liste mixte sans tournée mais avec dates isolées → affichage correct.
6. Liste mixte sans dates isolées mais avec tournées → affichage correct.
7. Dates identiques entre éléments → tri secondaire stable par type puis id.
8. Réseau lent/erreur API → loading + message utilisateur explicite.

---

## Pseudo-logique

```text
saveFreeText(dayId, contactText, financeText, dayNote):
  validate length <= 3000 for each non-null field
  payload = normalize(trim -> null if empty)
  PATCH /days/{dayId} payload
  invalidate(dayDetailProvider(dayId))

editSchedule(dayId, oldItemId, newItem):
  DELETE /days/{dayId}/schedule/{oldItemId}
  POST /days/{dayId}/schedule/ newItem
  invalidate(scheduleProvider(dayId))

createIsolatedConcertDay(input):
  payload = input + {tour_id: null, type: "concert"}
  POST /days/ payload
  refresh mixed list

buildMixedList(tours, days):
  isolatedDays = filter(days, tour_id == null)
  items = map(tours -> TOUR_ITEM) + map(isolatedDays -> ISOLATED_DAY_ITEM)
  sort by date asc, then kind, then id
  return items
```

---

## Plan de migration (recommandé)

1. Ajouter colonnes `contact_text`, `finance_text`, `day_note`.
2. Backfill optionnel :
  - `contact_text` depuis concat des champs contact legacy.
  - `finance_text` depuis `deal_amount + deal_currency` si présents.
3. Basculer UI vers nouveaux champs.
4. Marquer anciens champs comme deprecated.
5. Retrait effectif des anciens champs en v6 (hors scope v5).
# ROLE

Tu es un agent spécialisé en développement Python, Dart et modèle de donnée.

## OBJECTIF

Implémenter une évolution fonctionnelle complète et vérifiable permettant de :

1. Transformer **Contact** et **Finance** en **champs de texte libres**.
2. Ajouter une zone **Note** en champ texte libre dans les informations d’une date.
3. Permettre **l’édition et la suppression** des éléments **Schedule**.
4. Permettre la création d’une **date de concert isolée** (non attachée à une tournée) depuis la page de création de tournée.
5. Afficher les **dates isolées** dans la **même liste** que les tournées.

Critères mesurables de succès :

- Les formulaires UI contiennent les nouveaux champs libres attendus.
- Les données sont persistées via API sans erreur 4xx/5xx inattendue.
- Les opérations Schedule (create/edit/delete) sont disponibles et fonctionnelles.
- Une date isolée peut être créée sans `tour_id`.
- La liste principale affiche à la fois les tournées et les dates isolées, avec un rendu explicite de leur type.

## CONTEXTE

- Projet : TourApp (FastAPI + SQLModel + MariaDB + Flutter/Riverpod)
- Contraintes :
  - Conserver l’isolation multi-tenant par `group_id` (JWT).
  - Minimiser la dette technique et les régressions UI.
  - Réutiliser l’API existante quand possible.
  - Garder la compatibilité données avec les anciennes entrées.
- Input utilisateur :
  - Besoin de plus de souplesse de saisie (textes libres).
  - Besoin de gestion complète des items planning (CRUD Schedule).
  - Besoin de gérer des concerts hors tournée et de les visualiser au même niveau que les tournées.

## PROCESS

## 1. ANALYSE

### Comprendre le besoin

- **Contact / Finance en texte libre** :
  - Aujourd’hui, Contact et Finance sont structurés avec plusieurs champs (`contact_name`, `contact_phone`, `deal_amount`, etc.).
  - Le besoin cible une saisie plus flexible, moins rigide, adaptée au réel terrain.

- **Ajout d’une Note libre dans la date** :
  - Ajouter une zone éditable dédiée (ou réutiliser `notes` si déjà existante mais non exposée de façon claire).

- **Éditer/Supprimer Schedule** :
  - Le flux actuel permet création + lecture (et parfois suppression), mais pas toujours édition en UI.

- **Date isolée non attachée à une tournée** :
  - Modèle déjà compatible si `tour_id` nullable.
  - Le besoin est principalement UX + agrégation de listing.

- **Liste mixte tournées + dates isolées** :
  - Nécessite un view-model unifié côté frontend.

### Identifier les ambiguïtés

1. “Contact en texte libre” = un seul champ global (ex: `contact_notes`) ou conserver les champs actuels + ajouter un champ libre principal ?
2. “Finance en texte libre” = remplacer complètement `deal_amount/deal_currency` ou ajouter `finance_notes` en complément ?
3. “Même liste que les tournées” :
   - tri chronologique global ?
   - sections séparées mais dans le même écran ?
4. Date isolée créée “sur la page qui permet de créer une tournée” :
   - bouton secondaire dans la même modal ?
   - switch “Créer une tournée / Créer une date isolée” ?

### Lister les risques

- **Risque data model** : perdre la structure exploitable des montants (reporting finance futur).
- **Risque UX** : confusion dans une liste mixte si le type d’élément n’est pas visuel.
- **Risque API** : mismatch de payload si backend/frontend divergent sur noms de champs.
- **Risque migration** : coexistence d’anciens champs structurés et nouveaux champs libres.

## 2. PLAN

### Décomposer en étapes claires

1. **Modèle de données**
   - Ajouter champs libres :
     - `contact_text` (TEXT nullable)
     - `finance_text` (TEXT nullable)
   - Clarifier `notes` de Day comme zone “Note” principale (ou ajouter `day_note` si distinction nécessaire).

2. **Backend API**
   - Étendre schéma `DayUpdate` et `DayRead` pour exposer les champs libres.
   - Conserver rétrocompatibilité des anciens champs structurés.

3. **UI DayScreen**
   - Contact : zone texte multi-ligne éditable.
   - Finance : zone texte multi-ligne éditable.
   - Note : zone texte multi-ligne éditable dans la section info date.

4. **Schedule CRUD complet**
   - Ajouter édition item (`PATCH` ou pattern delete+create si endpoint absent).
   - Ajouter suppression item (si pas déjà visible partout).
   - Ajouter actions explicites sur chaque ligne (icônes edit/delete).

5. **Création date isolée depuis écran Tour**
   - Ajouter action “Créer date isolée” dans le même écran.
   - Appel `POST /days/` sans `tour_id`.

6. **Liste mixte Tours + Dates isolées**
   - Créer un provider agrégé : `tours + isolatedDays`.
   - Rendu unifié avec label de type (`TOUR` / `DATE ISOLÉE`).

7. **Validation**
   - Backend : checks payload.
   - Frontend : analyse + tests widget/smoke.

### Choisir une stratégie

Stratégie recommandée : **évolution additive compatible**

- Ne pas supprimer immédiatement les anciens champs structurés.
- Ajouter les nouveaux champs libres et basculer l’UI dessus.
- Prévoir une phase 2 de simplification backend si les anciens champs ne sont plus utiles.

## 3. EXECUTION

### Réaliser étape par étape

#### Étape A — Données

- Ajouter dans `Day` :
  - `contact_text: Optional[str]`
  - `finance_text: Optional[str]`
- Migration DB : ajout colonnes nullable.

**Justification** : évite toute casse des enregistrements existants.

#### Étape B — API Day

- Étendre `DayUpdate`, `DayCreate`, `DayRead` avec les champs libres.
- Conserver `notes` comme champ “Note date” affiché et éditable clairement.

**Justification** : API explicite et progressive.

#### Étape C — UI Contact/Finance/Note

- Remplacer les petits champs par un dialog textarea (multiline) ou un écran edit dédié.
- Ajouter validation simple (longueur max raisonnable côté UI).

**Justification** : UX rapide et robuste, effort limité.

#### Étape D — Schedule

- Ajouter boutons `Edit` et `Delete` par ligne.
- Si endpoint patch absent :
  - option 1 : créer `PATCH /days/{day_id}/schedule/{item_id}` (préféré)
  - option 2 : delete + create côté UI (moins propre)

**Justification** : vrai CRUD utilisateur attendu.

#### Étape E — Date isolée depuis page Tour

- Dans l’écran de création actuelle, ajouter un mode “Date isolée”.
- Envoyer `tour_id = null`.

**Justification** : répond exactement au besoin produit sans écran additionnel.

#### Étape F — Liste mixte

- Construire un modèle d’affichage unifié :

```text
TimelineItem {
  id
  kind: 'tour' | 'isolated_day'
  title
  subtitle
  date?
}
```

- Fusionner/ordonner puis afficher dans la même liste.

**Justification** : lisibilité et extensibilité future.

## 4. REVIEW

### Vérifier

- **Cohérence**
  - Les champs libres sont présents dans modèle + API + UI.
  - La création date isolée existe au bon endroit (écran tour).
  - La liste unique affiche bien les 2 types d’objets.

- **Erreurs**
  - Payloads validés (null/empty).
  - Pas de crash si texte très long.
  - Pas de crash si aucun item schedule.

- **Oublis**
  - Permissions JWT/group_id conservées.
  - Invalidation providers après mutation.
  - Cas offline/latence : feedback loading et erreurs.

## 5. AMELIORATION

### Proposer une version meilleure

1. **Éditeur riche léger** pour Contact/Finance/Note (markdown ou bullets).
2. **Historique des modifications** (audit basique : `updated_at`, `updated_by_group`).
3. **Template schedule** duplicable d’une date à l’autre.
4. **Tri/filtre avancé** dans la liste mixte (par ville, par date, par type).

### Optimiser si possible

- Limiter les refetch complets : mise à jour optimiste locale + rollback en cas d’erreur.
- Unifier les dialogs de saisie texte dans un composant réutilisable.
- Ajouter tests unitaires backend pour les nouvelles clés de payload.

## FORMAT DE SORTIE

Markdown structuré + plan d’implémentation détaillé (backend, frontend, modèle de donnée), prêt à exécution dans le repo.
