# Spécification Technique — Authentification Group-Based avec Sélection de Groupe (TourApp)

Ce document décrit l’évolution du système d’authentification où les groupes sont pré-enregistrés et sélectionnables depuis l’écran d’accueil.
L’utilisateur n’a plus qu’à saisir un mot de passe pour se connecter.

---

## 1. Vision & Analyse

### Objectif

Simplifier l’expérience utilisateur en supprimant la saisie d’email lors de la connexion :

- Les groupes existants sont affichés sur la page d’accueil
- L’utilisateur sélectionne un groupe
- Il saisit uniquement le mot de passe pour se connecter

### Avantages

#### UX simplifiée

- Aucun email à retenir ou saisir
- Connexion en 2 étapes visuelles simples

#### Réduction des erreurs

- Pas de faute de frappe sur email
- Sélection guidée

#### Adapté aux équipes

- Les groupes deviennent des « espaces de travail visibles »

### Risques identifiés

#### Sécurité

- Les noms de groupes sont visibles sur l’appareil

#### Bruteforce ciblé

- Attaque possible sur un groupe identifié

#### Scalabilité UX

- Si beaucoup de groupes, interface potentiellement chargée

---

## 2. Refactorisation de la Base de Données (MariaDB)

### Structure des groupes (inchangée)

```sql
CREATE TABLE groups (
    id CHAR(36) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

👉 Aucun changement structurel côté DB, uniquement UX/auth flow.

---

## 3. Architecture Backend (FastAPI)

### 3.1 Nouveau flux d’authentification

#### Étape 1 : récupération des groupes

```python
@router.get("/groups")
def list_groups(db: Session = Depends(get_db)):
    return db.query(Group.id, Group.name).all()
```

👉 Retourne la liste des groupes disponibles.

#### Étape 2 : login par groupe + password

```python
@router.post("/auth/login")
def login(data: LoginInput, db: Session = Depends(get_db)):
    group = db.query(Group).filter(Group.id == data.group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Groupe introuvable")
    if not verify_password(data.password, group.password_hash):
        raise HTTPException(status_code=401, detail="Mot de passe invalide")
    token = create_jwt({"group_id": str(group.id)})
    return {
        "access_token": token,
        "token_type": "bearer"
    }
```

### 3.2 Middleware (inchangé)

```python
def get_current_group(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    payload = decode_jwt(token)
    group_id = payload.get("group_id")
    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=401)
    return group
```

---

## 4. Impact Frontend (Flutter)

### 4.1 Nouvelle page d’accueil

Flow UI :

1. Charger la liste des groupes
2. Afficher en cards / liste
3. Tap sur un groupe
4. Afficher champ password
5. Login

### 4.2 API call groupes

```dart
final response = await dio.get("/groups");
```

### 4.3 Login

```dart
final response = await dio.post("/auth/login", data: {
  "group_id": selectedGroupId,
  "password": password,
});
```

### 4.4 State simplifié

- plus d’email
- plus de sélection persistante de groupe
- uniquement :
  - `selectedGroup`
  - `token`

---

## 5. Sécurité

### Mesures recommandées

#### Protection brute force

- rate limiting sur `/auth/login`

#### Durcissement login

- délai progressif après échecs
- captcha optionnel si nécessaire

---

## 6. Améliorations possibles

### UX avancée

- recherche de groupe
- favoris locaux
- login rapide dernier groupe utilisé

### Sécurité renforcée

- device binding (optionnel)
- logs de connexion

```sql
CREATE TABLE login_logs (
    id CHAR(36),
    group_id CHAR(36),
    success BOOLEAN,
    created_at DATETIME
);
```

---

## 7. Résumé du changement

| Élément | Avant | Après |
| --- | --- | --- |
| Login | Email + password | Groupe sélectionné + password |
| UX | Saisie libre | Sélection visuelle |
| Auth flow | identifier + credentials | group_id + password |
| Page d’accueil | vide ou login | liste des groupes |
| Sécurité | standard | rate limiting recommandé |

### Statut

✅ Prêt pour implémentation.
