import uuid
from datetime import date, datetime, time
from decimal import Decimal
from enum import Enum
from typing import Optional

from sqlmodel import Field, SQLModel


def gen_uuid() -> str:
    return str(uuid.uuid4())


class DayType(str, Enum):
    concert = "concert"
    day_off = "day_off"


class Group(SQLModel, table=True):
    __tablename__ = "groups"
    id: str = Field(default_factory=gen_uuid, primary_key=True, max_length=36)
    name: str = Field(max_length=255)
    email: str = Field(max_length=255, unique=True, index=True)
    password_hash: str = Field(max_length=255)
    created_at: datetime = Field(default_factory=datetime.utcnow)


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
    address: Optional[str] = Field(default=None, max_length=500)
    promo_sent: bool = Field(default=False)
    coplateau: bool = Field(default=False)
    roadmap_sent: bool = Field(default=False)
    backline_conversation: bool = Field(default=False)
    day_note: Optional[str] = Field(default=None, max_length=3000)
    contact_text: Optional[str] = Field(default=None, max_length=3000)
    finance_text: Optional[str] = Field(default=None, max_length=3000)
    hebergement: Optional[str] = Field(default=None, max_length=3000)
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
    visibility: str = Field(default="private", max_length=20)
