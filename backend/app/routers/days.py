from datetime import date
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlmodel import Session, select

from app.auth import get_current_group
from app.database import get_session
from app.models import Day, DayType
from app.services.duplicate_day import duplicate_day

router = APIRouter(prefix="/days", tags=["days"])


class DayCreate(BaseModel):
    tour_id: Optional[str] = None
    date: date
    type: DayType = DayType.concert
    city: Optional[str] = None
    venue: Optional[str] = None
    notes: Optional[str] = None
    contact_name: Optional[str] = None
    contact_phone: Optional[str] = None
    contact_email: Optional[str] = None
    deal_amount: Optional[Decimal] = None
    deal_currency: Optional[str] = None
    travel_notes: Optional[str] = None
    shared_gear: Optional[str] = None


class DayRead(DayCreate):
    id: str
    group_id: str


class DayUpdate(BaseModel):
    date: Optional[date] = None
    type: Optional[DayType] = None
    city: Optional[str] = None
    venue: Optional[str] = None
    notes: Optional[str] = None
    contact_name: Optional[str] = None
    contact_phone: Optional[str] = None
    contact_email: Optional[str] = None
    deal_amount: Optional[Decimal] = None
    deal_currency: Optional[str] = None
    travel_notes: Optional[str] = None
    shared_gear: Optional[str] = None


@router.post("/", response_model=DayRead, status_code=status.HTTP_201_CREATED)
def create_day(
    body: DayCreate,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    day = Day(**body.model_dump(), group_id=group_id)
    session.add(day)
    session.commit()
    session.refresh(day)
    return day


@router.get("/", response_model=list[DayRead])
def list_days(
    tour_id: Optional[str] = None,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    stmt = select(Day).where(Day.group_id == group_id)
    if tour_id:
        stmt = stmt.where(Day.tour_id == tour_id)
    return session.exec(stmt.order_by(Day.date)).all()


@router.get("/{day_id}", response_model=DayRead)
def get_day(
    day_id: str,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    day = session.exec(select(Day).where(Day.id == day_id, Day.group_id == group_id)).first()
    if not day:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Day not found")
    return day


@router.patch("/{day_id}", response_model=DayRead)
def update_day(
    day_id: str,
    body: DayUpdate,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    day = session.exec(select(Day).where(Day.id == day_id, Day.group_id == group_id)).first()
    if not day:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Day not found")
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(day, key, value)
    session.add(day)
    session.commit()
    session.refresh(day)
    return day


@router.delete("/{day_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_day(
    day_id: str,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    day = session.exec(select(Day).where(Day.id == day_id, Day.group_id == group_id)).first()
    if not day:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Day not found")
    session.delete(day)
    session.commit()


class DayDuplicate(BaseModel):
    new_date: date


@router.post("/{day_id}/duplicate", response_model=DayRead, status_code=status.HTTP_201_CREATED)
def duplicate_day_route(
    day_id: str,
    body: DayDuplicate,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    day = session.exec(select(Day).where(Day.id == day_id, Day.group_id == group_id)).first()
    if not day:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Day not found")
    return duplicate_day(session, day, body.new_date)
