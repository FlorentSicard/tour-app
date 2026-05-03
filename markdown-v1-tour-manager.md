# 📂 Project Master Plan: TourApp (Multi-Group)

## 1. Overview & Context
TourApp is a mobile-first operational dashboard for touring bands.
- **Goal**: Manage daily tour logistics, schedules, and checklists.
- **Tenancy**: Multi-group (A user can belong to multiple bands/groups).
- **Scale**: Small teams (<10 users), low traffic, high business logic.

## 2. Tech Stack
- **Frontend**: Flutter (Mobile/Web) + Riverpod (State management) + Dio (HTTP).
- **Backend**: FastAPI (Python) + SQLModel (SQLAlchemy + Pydantic).
- **Database**: **MariaDB** (using `CHAR(36)` for UUID strings).
- **Auth**: JWT with Group-ID context via headers.

---

## 3. Database Schema (MariaDB Optimized)

### 3.1 Core System
- **groups**: `id (CHAR(36) PK)`, `name (VARCHAR)`, `owner_id (FK users)`.
- **users**: `id (CHAR(36) PK)`, `name`, `email (unique)`, `password_hash`, `current_group_id`.
- **memberships**: `user_id (FK)`, `group_id (FK)`, `role (admin/member/viewer)`, `joined_at (datetime)`.

### 3.2 Tour Entities
- **tours**: `id (CHAR(36) PK)`, `group_id (FK)`, `name`.
- **days**: 
    - `id (CHAR(36) PK)`, `group_id (FK)`, `tour_id (FK, null)`, `date`, `type (concert/day_off)`.
    - `city`, `venue`, `notes (TEXT)`.
    - `contact_name`, `contact_phone`, `contact_email`.
    - `deal_amount (DECIMAL(10,2))`, `deal_currency (VARCHAR(3))`, `travel_notes (TEXT)`, `shared_gear (TEXT)`.
- **schedule_items**: `id (CHAR(36) PK)`, `day_id (FK)`, `time`, `label`, `notes (TEXT)`.

### 3.3 Checklists
- **checklist_templates**: `id (PK)`, `name`, `category`, `default_offset_days (INT)`.
- **checklist_items**: `id (PK)`, `day_id (FK)`, `template_id (FK, null)`, `label`, `is_done (TINYINT)`, `due_date (DATE)`, `assigned_to (FK user)`.

---

## 4. Backend Logic (Implementation Blocks)

### Block B1: Multi-Tenant Middleware
- Implement a dependency `get_current_group` that:
    1. Extracts `X-Group-ID` from HTTP header.
    2. Verifies if the authenticated `current_user` has a valid `membership` for this group.
    3. Raises 403 Forbidden if the link is missing.

### Block B2: Day Duplication Service
- Service to clone a `Day`:
    - Duplicate core info (venue, contacts, notes).
    - Duplicate all related `schedule_items`.
    - Clone `checklist_items` (filter for required/incomplete ones, recalculate `due_date` relative to the new day).

### Block B3: Reminder Job
- Background task (APScheduler) running daily:
    - Scans `checklist_items` where `is_done = false` and `due_date <= today`.
    - Dispatches notifications or flags for the dashboard.

---

## 5. Frontend Architecture (Implementation Blocks)

### Block F1: Group Provider & Interceptor
- **State**: A global provider to store `activeGroupId`.
- **Network**: A Dio Interceptor that automatically injects `X-Group-ID: <activeGroupId>` in every request header.

### Block F2: Day Management UI
- **Mobile**: Vertical scroll, collapsible cards for Logistics/Finance/Contact to save space.
- **Desktop**: Dashboard layout with the schedule timeline taking center stage.

---

## 6. Development Instructions for Copilot Agent
1. **UUIDs**: Generate and handle UUID v4 as strings in Python and Dart.
2. **Security**: Never perform a database write or read without a `WHERE group_id = :active_group_id` clause.
3. **Flutter**: Use a high-contrast dark theme (Touring/Live event aesthetic).
4. **Data Integrity**: Use `DECIMAL` for financial data, never `FLOAT`.

---
**Status**: Ready for Implementation.
**Database**: MariaDB.
