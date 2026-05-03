import uuid
from datetime import date, datetime, time
from decimal import Decimal
from enum import Enum
from typing import Optional

from sqlmodel import Field, Relationship, SQLModel


def gen_uuid() -> str:
    return str(uuid.uuid4())


class RoleEnum(str, Enum):
    admin = "admin"
    member = "member"
    viewer = "viewer"


class DayType(str, Enum):
    concert = "concert"
    day_off = "day_off"


class Group(SQLModel, table=True):
    __tablename__ = "groups"
    id: str = Field(default_factory=gen_uuid, primary_key=True, max_length=36)
    name: str = Field(max_length=255)
    owner_id: str = Field(max_length=36, foreign_key="users.id")


class User(SQLModel, table=True):
    __tablename__ = "users"
    id: str = Field(default_factory=gen_uuid, primary_key=True, max_length=36)
    name: str = Field(max_length=255)
    email: str = Field(max_length=255, unique=True, index=True)
    password_hash: str = Field(max_length=255)
    current_group_id: Optional[str] = Field(default=None, max_length=36, foreign_key="groups.id")


class Membership(SQLModel, table=True):
    __tablename__ = "memberships"
    user_id: str = Field(max_length=36, foreign_key="users.id", primary_key=True)
    group_id: str = Field(max_length=36, foreign_key="groups.id", primary_key=True)
    role: RoleEnum = Field(default=RoleEnum.member)
    joined_at: datetime = Field(default_factory=datetime.utcnow)


class Tour(SQLModel, table=True):
    __tablename__ = "tours"
    id: str = Field(default_factory=gen_uuid, primary_key=True, max_length=36)
    group_id: str = Field(max_length=36, foreign_key="groups.id", index=True)
    name: str = Field(max_length=255)


class Day(SQLModel, table=True):
    __tablename__ = "days"
    id: str = Field(default_factory=gen_uuid, primary_key=True, max_length=36)
    group_id: str = Field(max_length=36, foreign_key="groups.id", index=True)
    tour_id: Optional[str] = Field(default=None, max_length=36, foreign_key="tours.id")
    date: date
    type: DayType = Field(default=DayType.concert)
    city: Optional[str] = Field(default=None, max_length=255)
    venue: Optional[str] = Field(default=None, max_length=255)
    notes: Optional[str] = Field(default=None)
    contact_name: Optional[str] = Field(default=None, max_length=255)
    contact_phone: Optional[str] = Field(default=None, max_length=50)
    contact_email: Optional[str] = Field(default=None, max_length=255)
    deal_amount: Optional[Decimal] = Field(default=None, max_digits=10, decimal_places=2)
    deal_currency: Optional[str] = Field(default=None, max_length=3)
    travel_notes: Optional[str] = Field(default=None)
    shared_gear: Optional[str] = Field(default=None)


class ScheduleItem(SQLModel, table=True):
    __tablename__ = "schedule_items"
    id: str = Field(default_factory=gen_uuid, primary_key=True, max_length=36)
    day_id: str = Field(max_length=36, foreign_key="days.id", index=True)
    time: time
    label: str = Field(max_length=255)
    notes: Optional[str] = Field(default=None)


class ChecklistTemplate(SQLModel, table=True):
    __tablename__ = "checklist_templates"
    id: str = Field(default_factory=gen_uuid, primary_key=True, max_length=36)
    group_id: str = Field(max_length=36, foreign_key="groups.id", index=True)
    name: str = Field(max_length=255)
    category: Optional[str] = Field(default=None, max_length=255)
    default_offset_days: int = Field(default=0)


class ChecklistItem(SQLModel, table=True):
    __tablename__ = "checklist_items"
    id: str = Field(default_factory=gen_uuid, primary_key=True, max_length=36)
    day_id: str = Field(max_length=36, foreign_key="days.id", index=True)
    template_id: Optional[str] = Field(default=None, max_length=36, foreign_key="checklist_templates.id")
    label: str = Field(max_length=255)
    is_done: bool = Field(default=False)
    due_date: Optional[date] = Field(default=None)
    assigned_to: Optional[str] = Field(default=None, max_length=36, foreign_key="users.id")
    is_overdue_flagged: bool = Field(default=False)
