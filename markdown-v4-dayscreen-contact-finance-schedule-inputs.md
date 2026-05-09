# Spécification Technique v4 — Saisie Contact / Finance / Schedule (TourApp)

## Objectif

Permettre la saisie directe des sections **Contact**, **Finance** et **Schedule** depuis le frontend sur la page d’un jour (`DayScreen`).

---

## 1. Problème observé

Sur l’écran détail d’un jour, les sections suivantes étaient seulement en lecture :

- Contact
- Finance
- Schedule

Il manquait des zones de texte (inputs) pour renseigner/modifier ces données.

---

## 2. Solution implémentée (Frontend)

Fichier impacté : `frontend/lib/screens/day_screen.dart`

### 2.1 Contact

- Ajout d’un bouton **Edit** dans la carte Contact.
- Ouverture d’une modal avec champs texte :
  - `Name`
  - `Phone`
  - `Email`
- Sauvegarde via appel API :

```http
PATCH /days/{dayId}
```

Payload envoyé :

```json
{
  "contact_name": "...",
  "contact_phone": "...",
  "contact_email": "..."
}
```

- Rafraîchissement automatique de la vue via invalidation de `dayDetailProvider(dayId)`.

### 2.2 Finance

- Ajout d’un bouton **Edit** dans la carte Finance.
- Ouverture d’une modal avec champs texte :
  - `Deal amount`
  - `Currency`
- Sauvegarde via :

```http
PATCH /days/{dayId}
```

Payload envoyé :

```json
{
  "deal_amount": 1200,
  "deal_currency": "EUR"
}
```

- Le montant est parsé en numérique (`num.tryParse`).
- La devise est normalisée en majuscules.
- Rafraîchissement de `dayDetailProvider(dayId)`.

### 2.3 Schedule

- Ajout d’un bouton **Add** dans la carte Schedule.
- Ouverture d’une modal avec :
  - sélecteur d’heure (`showTimePicker`)
  - `Label`
  - `Notes (optional)`
- Création via :

```http
POST /days/{dayId}/schedule/
```

Payload envoyé :

```json
{
  "time": "HH:MM",
  "label": "...",
  "notes": "..."
}
```

- Rafraîchissement de `scheduleProvider(dayId)` après ajout.

---

## 3. Impact API / Backend

Aucun nouvel endpoint requis.

Endpoints existants réutilisés :

- `PATCH /days/{dayId}`
- `POST /days/{dayId}/schedule/`

---

## 4. UX attendue

- L’utilisateur peut maintenant **renseigner et modifier** Contact et Finance sans quitter l’écran.
- L’utilisateur peut **ajouter des éléments de planning** (`Schedule`) rapidement depuis la carte dédiée.
- Les modifications sont visibles immédiatement après sauvegarde.

---

## 5. Résumé

✅ Contact : champs de saisie ajoutés  
✅ Finance : champs de saisie ajoutés  
✅ Schedule : ajout d’item avec text inputs et heure  
✅ Données persistées via API existante et UI rafraîchie automatiquement
