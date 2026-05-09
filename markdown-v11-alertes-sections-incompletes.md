# ROLE

Tu es un agent spécialisé en Python, Flutter et BDD.

## OBJECTIF

Spécifier et implémenter des alertes visuelles d’incomplétude (badge rouge `❗`) sur les dates et sections, avec détail des sections manquantes via tooltip.

Évolutions à couvrir :

1. **Page date `concert`** : afficher un badge `❗` blanc dans un cercle rouge en haut à droite de chaque section incomplète.
2. **Page date `day_off`** : afficher un badge `❗` sur la section `hébergement` si elle est incomplète.
3. **Page tournée** : afficher un badge `❗` sur chaque carte date incomplète selon les règles de son type.
4. **Date isolée (home/timeline)** : afficher un badge `❗` si la date isolée est incomplète selon les mêmes règles métier.
5. **Tooltip obligatoire** : au survol/clic du badge (web/mobile), afficher les sections à compléter.
6. **Page register** : afficher une micro-explication sous chaque champ (nom groupe, email, mot de passe).
7. **Page date / planning** : afficher une explication claire de l’utilité `public` / `privé` pour chaque élément de planning (FR/EN).
8. **Page tournée (timeline)** : afficher pour chaque tournée la première et la dernière date (ordre chronologique).

## RÈGLES MÉTIER VALIDÉES

### 1) Sections obligatoires par type

- **Pour `concert`** (contrôle obligatoire) :
  - `city`
  - `venue`
  - `address`
  - `contact`
  - `deal`
  - `hebergement`
  - `planning` (au moins un item schedule)

- **Pour `concert`** (explicitement exclus du contrôle) :
  - `note`
  - `suivi`

- **Pour `day_off`** :
  - seule la section `hebergement` est obligatoire
  - les autres champs n’entrent pas dans la règle d’alerte

### 2) Définition de « vide »

Un champ est considéré **vide** si sa valeur est :

- `null`
- chaîne vide `""`
- chaîne d’espaces uniquement
- valeur de placeholder `"-"`

`planning` est considéré vide si la liste schedule contient **0 élément**.

### 3) Cardinalité du badge

- **Un seul badge par section** (page date).
- **Un seul badge par date** (page tournée / date isolée), même si plusieurs sections manquent.

### 4) Contenu tooltip

Le tooltip doit lister explicitement les sections manquantes de la cible (section/date), par exemple :

- `Sections à compléter : Ville, Lieu, Adresse, Planning`

## CRITÈRES DE SUCCÈS (MESURABLES)

- Sur une date `concert`, chaque section obligatoire vide affiche un badge `❗`.
- Sur une date `concert`, `note` et `suivi` n’affichent jamais de badge d’incomplétude.
- Sur une date `day_off`, seul `hébergement` peut déclencher le badge.
- Sur la page tournée, une date a un badge si et seulement si elle viole sa règle métier de type.
- Sur une date isolée, même logique de badge que pour la page tournée.
- Le tooltip affiche la liste exacte des sections manquantes.

## CAS LIMITES

1. **Champs présents mais blancs** (`"   "`) : doivent être traités comme vides.
2. **Valeur `"-"`** : traitée comme vide.
3. **Concert sans schedule** : `planning` manquant => badge visible.
4. **Concert avec plusieurs champs manquants** :
   - badges sectionnels multiples sur la page date,
   - un seul badge sur carte date tournée/isolée,
   - tooltip liste tous les manquants.
5. **Day off avec tous champs vides sauf hébergement rempli** : aucun badge.
6. **Day off avec hébergement vide** : badge présent avec tooltip `Hébergement`.
7. **Données partielles legacy** : la règle s’applique uniquement aux champs définis ci-dessus, sans effet de bord.

## COMPORTEMENTS ATTENDUS

### Page register

- Sous chaque champ du mode inscription, afficher un texte d’aide court en petit :
  - nom du groupe,
  - email,
  - mot de passe.
- Les textes sont traduits en français et en anglais.

### Page date / planning (public vs privé)

- Dans le formulaire d’ajout/édition d’un item planning, afficher un texte explicatif sur la visibilité.
- Le texte doit expliquer :
  - `privé` = interne, non visible dans l’export roadmap,
  - `public` = visible dans l’export roadmap (partage externe).
- Dans la liste des items planning, afficher aussi le rappel d’explication par item selon sa visibilité.
- Les textes sont traduits en français et en anglais.

### Page tournée (timeline)

- Pour chaque item de type tournée, afficher une plage de dates : `première date → dernière date`.
- Le calcul est chronologique sur l’ensemble des dates de la tournée.
- Si date manquante, fallback sur `Pas de date` / `No date`.

### Page date (`concert`)

- Chaque section contrôlée doit pouvoir afficher un badge en **haut à droite**.
- Le badge est visuel : cercle rouge + `!` blanc.
- Interaction :
  - web : tooltip au survol,
  - mobile : tooltip / info-bulle au tap long ou tap.
- Le tooltip indique la/les section(s) à compléter.

### Page date (`day_off`)

- Seule la section `hébergement` gère l’alerte.
- Même style de badge et même logique de tooltip.

### Page tournée + dates isolées

- La carte date affiche un badge en haut à droite si la date est incomplète selon son type.
- Tooltip de carte : liste des sections manquantes de cette date.
- Une seule icône par carte date, même avec plusieurs manques.

## PLAN D’IMPLÉMENTATION

1. **Normaliser la validation “is empty”**
   - helper commun backend/frontend ou frontend centralisé : `isMissing(value)`.
   - inclure `null`, `""`, espaces, `"-"`.

2. **Calcul des sections manquantes par date**
   - `concert` => `city`, `venue`, `address`, `contact`, `deal`, `hebergement`, `planning`.
   - `day_off` => `hebergement`.
   - produire une liste stable ordonnée pour le tooltip.

3. **UI page date**
   - ajouter un composant badge+tooltip réutilisable sur les sections concernées.
   - ignorer `note` et `suivi` pour `concert`.

4. **UI page tournée / date isolée**
   - ajouter badge+tooltip au niveau de la carte date.
   - source tooltip = liste consolidée des sections manquantes.

5. **Tests**
   - unit tests sur la logique de “missing sections”.
   - widget tests pour présence/absence badge selon type et données.
   - tests tooltip (contenu attendu).

6. **Aides register** : ajouter des clés i18n FR/EN pour les micro-explications et afficher les aides en petit sous les champs du mode inscription.
7. **Aides visibilité planning** : ajouter des clés i18n FR/EN pour l’explication `public/privé`, afficher l’explication dans le formulaire planning et afficher un rappel explicatif sur chaque ligne de planning.
8. **Timeline tournée (bornes de dates)** : calculer première/dernière date par tournée et afficher la plage dans le sous-titre des items tournée.

## PSEUDO-LOGIQUE

```text
isMissing(value):
  if value is null: return true
  text = String(value).trim()
  return text == "" or text == "-"

missingSections(day, schedules):
  if day.type == "concert":
    missing = []
    if isMissing(day.city): missing += ["Ville"]
    if isMissing(day.venue): missing += ["Lieu"]
    if isMissing(day.address): missing += ["Adresse"]
    if isMissing(day.contact): missing += ["Contact"]
    if isMissing(day.deal): missing += ["Deal"]
    if isMissing(day.hebergement): missing += ["Hébergement"]
    if schedules.count == 0: missing += ["Planning"]
    return missing

  if day.type == "day_off":
    return isMissing(day.hebergement) ? ["Hébergement"] : []

  return []

showSectionBadge(sectionMissing):
  return sectionMissing == true

showDateBadge(dayMissingSections):
  return dayMissingSections.length > 0

tooltipContent(missing):
  return "Sections à compléter : " + join(missing, ", ")
```

## CRITÈRES D’ACCEPTATION

1. Une date `concert` avec `city` vide affiche un badge sur la section ville et la carte tournée/isolée.
2. Une date `concert` avec `note` vide n’affiche aucun badge lié à `note`.
3. Une date `concert` sans schedule affiche `Planning` dans le tooltip.
4. Une date `day_off` avec `hebergement` vide affiche le badge (section + carte), sinon non.
5. Le tooltip liste exactement les sections manquantes, sans doublons.
6. Une carte date n’affiche jamais plus d’un badge.
7. En mode register, chaque champ affiche une micro-explication localisée FR/EN.
8. Sur la page date, la visibilité `public/privé` est expliquée dans le formulaire planning et sur chaque item planning.
9. Sur la timeline, chaque tournée affiche `première date → dernière date` calculées chronologiquement.

## FORMAT DE SORTIE ATTENDU

Markdown structuré prêt implémentation (backend + frontend), priorisant :

- règles métier,
- cas limites,
- comportements attendus.
