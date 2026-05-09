# TourApp

TourApp is an operational dashboard for touring bands.

It combines a FastAPI backend and a Flutter frontend to manage:

- tours and isolated concert dates,
- concert/day-off logistics,
- schedule visibility (`public` / `private`),
- PDF exports (day, roadmap, full tour compilation),
- and UX helpers (i18n/theme toggle, completeness badges, inline field guidance).

## Tech Stack

- **Backend**: FastAPI, SQLModel, MariaDB, ReportLab, pypdf
- **Frontend**: Flutter, Riverpod, Dio, GoRouter
- **Auth model**: group-based JWT (`group_id` in token)
- **Database**: MariaDB 11 (via Docker Compose)

## Current Functional Scope (aligned with specs v1 → v11)

### Authentication & tenancy

- Group-based registration/login:
  - register with `name + email + password`
  - login with `group_id + password`
- JWT carries `group_id` and scopes all protected data access.
- No `X-Group-ID` header workflow.

### Tours & dates

- Create tours and days.
- Day types:
  - `concert`
  - `day_off`
- Isolated date support (`tour_id = null`, forced `concert`).
- In home timeline:
  - mixed list (tours + isolated dates),
  - tour item displays chronological range: `first_date → last_date`.

### Day screen rules

- `concert` requires `address`.
- `day_off` has restricted display behavior.
- Free-text sections (`contact_text`, `finance_text`/Deal, `day_note`, `hebergement`) with max length 3000.
- Concert tracking booleans:
  - `promo_sent`
  - `coplateau`
  - conditional: `roadmap_sent`, `backline_conversation`
- If `coplateau` is turned off, dependent booleans are reset to `false`.

### Schedule visibility

- Each schedule item has `visibility` in `{public, private}`.
- Visibility is editable.
- UI explains public/private meaning in FR/EN.

### PDF exports

- Day full export: `GET /days/{id}/export/full`
  - `day_off` export is restricted to visible fields (type/date/hebergement/note).
- Day roadmap export: `GET /days/{id}/export/roadmap`
  - only `public` schedule items,
  - blocked for `day_off`,
  - blocked if no public schedule.
- Tour full export: `GET /tours/{id}/export/full`
  - compiled PDF ordered by date,
  - includes cover page,
  - cover lists non-`day_off` dates only,
  - fallback `-` for missing city/venue.
- Tracking block removed from full PDF rendering.

### UX/i18n additions

- Global theme and language switching (FR/EN, immediate apply, locally persisted).
- Register screen helper text below each field.
- Completeness badges (`❗`) on sections/cards with tooltip listing missing required sections.

## Project Structure

```text
tour-app/
  backend/
    app/
      routers/         # auth, groups, tours, days, schedule_items
      services/        # duplicate_day, pdf generation, reminders
      models.py
      auth.py
      config.py
      database.py
      main.py
    Dockerfile
    .dockerignore
    requirements.txt
  frontend/
    lib/
      providers/
      screens/
      utils/
      widgets/
      l10n/
      app.dart
      router.dart
      main.dart
    Dockerfile
    .dockerignore
    nginx.conf
    pubspec.yaml
  docker-compose.yml
  .env.example
  markdown-v*.md       # feature/spec history
```

## Production Deployment (Docker)

The application is deployed via Docker Compose using pre-built images hosted on Docker Hub.

### Images

| Service  | Image                                      |
|----------|--------------------------------------------|
| Backend  | `<dockerhub_username>/tourapp-backend`     |
| Frontend | `<dockerhub_username>/tourapp-frontend`    |
| Database | `mariadb:11` (official image)              |

The frontend image is a multi-stage build: Flutter web compiled to static files, served by Nginx.
The backend is not exposed publicly — Nginx proxies `/api/` to the backend on the internal Docker network.

### Environment variables

Copy `.env.example` to `.env` and fill in the values:

```bash
cp .env.example .env
```

| Variable              | Description                              |
|-----------------------|------------------------------------------|
| `DOCKER_HUB_USERNAME` | Docker Hub account name                  |
| `IMAGE_TAG`           | Image tag to deploy (default: `latest`)  |
| `DB_ROOT_PASSWORD`    | MariaDB root password                    |
| `DB_NAME`             | Database name                            |
| `DB_USER`             | Database user                            |
| `DB_PASSWORD`         | Database password                        |
| `JWT_SECRET`          | JWT signing secret                       |
| `JWT_ALGORITHM`       | JWT algorithm (default: `HS256`)         |
| `JWT_EXPIRE_MINUTES`  | JWT expiry in minutes (default: `1440`)  |

### Deploy

```bash
docker compose pull
docker compose up -d
```

### Update to a new version

Set `IMAGE_TAG` in `.env` to the new version, then:

```bash
docker compose pull
docker compose up -d
```

The database volume (`db_data`) is preserved across restarts.

---

## Getting Started

### Prérequis (important)

1. **Docker + Docker Compose v2**
   - Required to run MariaDB (`docker compose up -d`).

2. **Python version for backend**
   - Use **Python 3.11 or 3.12 recommended**.
   - ⚠ **Do not use Python 3.14 currently** for backend runtime with this dependency set (`sqlmodel==0.0.22`, current pydantic stack), as model import fails with:
     - `pydantic.errors.PydanticUserError: Field 'id' requires a type annotation`

3. **Flutter / Dart**
   - Flutter SDK compatible with project constraint:
     - `Dart >=3.2.0 <4.0.0` (from `pubspec.yaml`).

4. **OS tools**
   - Git
   - A browser for Flutter web target

### Backend configuration

Backend reads environment variables from `backend/.env` (optional; defaults exist in `app/config.py`):

- `DATABASE_URL` (default: `mysql+pymysql://tourapp:tourpass@localhost:3306/tourapp`)
- `JWT_SECRET` (default is development-only; change in real environments)
- `JWT_ALGORITHM` (default `HS256`)
- `JWT_EXPIRE_MINUTES` (default `1440`)

### Start database

```powershell
cd <repo-root>
docker compose up -d
```

### Start backend

```powershell
cd <repo-root>\backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
uvicorn app.main:app --reload
```

Backend URLs:

- API: `http://localhost:8000`
- Docs: `http://localhost:8000/docs`
- Health: `http://localhost:8000/health`

### Start frontend (web)

```powershell
cd <repo-root>\frontend
flutter pub get
flutter run -d chrome
```

## API Summary (current)

### Public / auth

- `POST /auth/register`
- `POST /auth/login`
- `GET /groups/` (public list of groups)

### Protected (Bearer JWT)

- `GET /groups/me`
- `POST /tours/`
- `GET /tours/`
- `GET /tours/{tour_id}`
- `DELETE /tours/{tour_id}`
- `GET /tours/{tour_id}/export/full`
- `POST /days/`
- `GET /days/?tour_id=...`
- `GET /days/{day_id}`
- `PATCH /days/{day_id}`
- `DELETE /days/{day_id}`
- `POST /days/{day_id}/duplicate`
- `GET /days/{day_id}/export/full`
- `GET /days/{day_id}/export/roadmap`
- `POST /days/{day_id}/schedule/`
- `GET /days/{day_id}/schedule/`
- `PATCH /days/{day_id}/schedule/{item_id}`
- `DELETE /days/{day_id}/schedule/{item_id}`

## Notes about legacy docs/spec history

- The repository still contains earlier design specs (`markdown-v1` … `markdown-v11`).
- Some older sections (e.g. checklist/reminder expectations) are historical and no longer part of the active product behavior.
- Runtime source of truth is the current code under `backend/app` and `frontend/lib`.

## Troubleshooting

- If backend fails at startup/import with Pydantic model errors on Python 3.14, switch to Python 3.11/3.12 and recreate the virtual environment.
- If roadmap export fails with conflict:
  - verify the day is not `day_off`,
  - verify at least one schedule item is `public`.
