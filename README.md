# TourApp

Operational dashboard for touring bands. Manage daily tour logistics, schedules, and checklists across multiple groups.

## Tech Stack

- **Backend**: FastAPI + SQLModel + MariaDB
- **Frontend**: Flutter + Riverpod + Dio
- **Auth**: JWT with multi-tenant group context (X-Group-ID header)
- **Database**: MariaDB (Docker)

## Project Structure

```
tour/
  backend/           # FastAPI API server
    app/
      routers/       # API endpoints (auth, groups, tours, days, schedule, checklists)
      services/      # Business logic (day duplication, reminder job)
      models.py      # SQLModel database models
      auth.py        # JWT auth + multi-tenant middleware
      config.py      # Environment configuration
      database.py    # Database engine + session
      main.py        # FastAPI app entrypoint
    requirements.txt
    .env
  frontend/          # Flutter mobile/web app
    lib/
      providers/     # Riverpod state management (auth, API, tours)
      screens/       # UI screens (login, home, tour, day detail)
      app.dart       # App widget + dark theme
      router.dart    # GoRouter navigation
      main.dart      # Flutter entrypoint
    pubspec.yaml
  docker-compose.yml # MariaDB local instance
```

## Getting Started

### Prerequisites

- Docker
- Python 3.11+
- Flutter SDK 3.2+

### Database

```bash
docker compose up -d
```

MariaDB will be available on `localhost:3306` with database `tourapp`.

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

API available at `http://localhost:8000`. Swagger docs at `http://localhost:8000/docs`.

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d web-server --web-port=8080
```

Open `http://localhost:8080` in your browser (Brave, Chrome, or any Chromium-based browser).

If Chrome is installed, you can also use `flutter run -d chrome` to launch directly.

## Features

- **Multi-tenant**: Users can belong to multiple bands/groups, switch context via group selector
- **Tour management**: Create tours, add days (concert/day off) with logistics, contacts, finances
- **Schedule**: Time-based schedule items per day
- **Checklists**: Checklist items with due dates, assignment, and overdue flagging
- **Day duplication**: Clone a day with its schedule and incomplete checklist items (due dates recalculated)
- **Reminder job**: Background task (APScheduler, daily at midnight) flags overdue checklist items

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /auth/register | Register a new user |
| POST | /auth/login | Login, get JWT token |
| POST | /groups/ | Create a group |
| GET | /groups/ | List user's groups |
| POST | /tours/ | Create a tour |
| GET | /tours/ | List tours |
| GET | /tours/:id | Get tour |
| DELETE | /tours/:id | Delete tour |
| POST | /days/ | Create a day |
| GET | /days/ | List days (optional ?tour_id=) |
| GET | /days/:id | Get day detail |
| PATCH | /days/:id | Update day |
| DELETE | /days/:id | Delete day |
| POST | /days/:id/duplicate | Duplicate a day |
| POST | /days/:id/schedule/ | Add schedule item |
| GET | /days/:id/schedule/ | List schedule items |
| DELETE | /days/:id/schedule/:itemId | Delete schedule item |
| POST | /days/:id/checklist | Add checklist item |
| GET | /days/:id/checklist | List checklist items |
| PATCH | /checklist-items/:id | Update checklist item |
| POST | /checklist-templates | Create template |
| GET | /checklist-templates | List templates |

All endpoints except /auth/* and /groups/* require the `X-Group-ID` header.

## Future Improvements

- Push notifications for overdue checklist items
- Real-time sync (WebSockets)
- Offline mode with local SQLite cache
- File attachments (riders, contracts, stage plots)
- Export tour data (PDF, CSV)
- Group member invitation system with email
- Role-based permissions (admin/member/viewer enforcement)
- Setlist management per day
- Budget tracking and expense reports
- Map integration for venue locations and routing
- Desktop-optimized layout with dashboard view
