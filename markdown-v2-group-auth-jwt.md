# Tour Manager v2 — Authentification group-based

## Rôle

Agent spécialisé en architecture backend & authentification.

## Objectif

Transformer le système d’authentification actuel (`users` + `memberships`) en un système **group-based uniquement**, où :

- 1 groupe = 1 identité authentifiée
- Login via email + password du groupe
- Suppression des utilisateurs internes
- Maintien de l’isolation multi-tenant

## Contexte

- Projet : TourApp (dashboard logistique pour groupes en tournée)
- Backend : FastAPI + MariaDB
- Frontend : Flutter
- Architecture actuelle :
  - users
  - memberships
  - groups
- Objectif : simplifier radicalement l’authentification

## 1. Analyse

### Compréhension du besoin

Tu veux :

- supprimer la notion de `users`
- faire du `group` une identité unique
- authentifier directement un groupe

👉 Le groupe devient un compte.

### Risques

#### Sécurité

- compte partagé entre plusieurs personnes
- pas de traçabilité individuelle

#### Architecture

- perte de granularité future
- difficulté à réintroduire des rôles

#### Exploitation

- audit impossible (qui a fait quoi)

## 2. Plan

### Stratégie retenue

👉 Authentification simplifiée basée uniquement sur `groups`.

### Étapes

1. Refactor base de données
2. Adapter login backend
3. Simplifier JWT
4. Modifier middleware
5. Supprimer gestion multi-group côté frontend
6. Sécuriser toutes les requêtes via `group_id` issu du token

## 3. Exécution

### 3.1 Base de données

#### Nouveau modèle

```sql
groups:
  id CHAR(36) PRIMARY KEY
  name VARCHAR(255)
  email VARCHAR(255) UNIQUE
  password_hash VARCHAR(255)
  created_at DATETIME
```

Suppression :

```sql
DROP TABLE users;
DROP TABLE memberships;
```

### 3.2 Authentification (FastAPI)

#### Login

```python
@router.post("/auth/login")
def login(data: LoginInput):
    group = db.query(Group).filter(Group.email == data.email).first()
    if not group or not verify_password(data.password, group.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = create_jwt({"group_id": group.id})
    return {"access_token": token}
```

### 3.3 JWT

```json
{
  "group_id": "uuid"
}
```

👉 Le token devient la seule source de vérité.

### 3.4 Middleware / Auth dependency

```python
def get_current_group(token: str = Depends(oauth2_scheme)):
    payload = decode_jwt(token)
    group_id = payload.get("group_id")
    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=401)
    return group
```

### 3.5 Sécurisation des requêtes

Avant :

```sql
WHERE group_id = :header_group_id
```

Après :

```sql
WHERE group_id = :current_group.id
```

👉 Le backend devient 100% trust JWT.

### 3.6 Suppression du header groupe

❌ Supprimé :

- `X-Group-ID`

✅ Remplacé par :

- `Authorization: Bearer <JWT>`

### 3.7 Frontend Flutter

❌ Supprimé :

- `activeGroupId` provider
- logique multi-group
- interceptor `X-Group-ID`

✅ Conservé :

- `options.headers["Authorization"] = "Bearer $token";`

## 4. Review

### Cohérence

- architecture simplifiée ✔
- multi-tenant conservé ✔
- flux auth centralisé ✔

### Problèmes restants

- pas de traçabilité utilisateur
- compte partagé
- difficulté d’évolution future

### Risques critiques

- oubli de filtrage `group_id` → fuite de données
- mauvaise gestion JWT
- stockage insecure côté Flutter

## 5. Amélioration

### Option recommandée (léger futur-proof)

Ajouter une table optionnelle :

```sql
activity_logs:
  id CHAR(36)
  group_id CHAR(36)
  action VARCHAR(255)
  created_at DATETIME
```

👉 Permet un audit minimal sans complexifier l’architecture.

### Option évolutive (fortement recommandée)

Prévoir une réintroduction légère des users :

```sql
users:
  id
  group_id
  email
  password_hash
```

👉 Sans casser le modèle actuel.

### Optimisation backend

Créer un helper obligatoire :

```python
def scoped_query(model, group):
    return db.query(model).filter(model.group_id == group.id)
```

👉 Empêche les erreurs de filtrage.

## Résumé

- ❌ suppression `users` + `memberships`
- ✔ `group` devient identité unique
- ✔ login email/password sur `group`
- ✔ JWT basé uniquement sur `group_id`
- ❌ suppression `X-Group-ID`
- ✔ sécurité via token uniquement
