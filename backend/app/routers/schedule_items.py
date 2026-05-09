from datetime import time
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlmodel import Session, select

from app.auth import get_current_group
from app.database import get_session
from app.models import Day, Group, ScheduleItem

router = APIRouter(prefix="/days/{day_id}/schedule", tags=["schedule"])


class ScheduleItemCreate(BaseModel):
    time: time
    label: str
    notes: Optional[str] = None
    visibility: str = "private"


class ScheduleItemUpdate(BaseModel):
    time: Optional[time] = None
    label: Optional[str] = None
    notes: Optional[str] = None
    visibility: Optional[str] = None


class ScheduleItemRead(ScheduleItemCreate):
    id: str
    day_id: str


def _validate_visibility(value: str) -> str:
    normalized = value.strip().lower()
    if normalized not in {"public", "private"}:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="visibility must be public or private")
    return normalized


def _get_day(day_id: str, group_id: str, session: Session) -> Day:
    day = session.exec(select(Day).where(Day.id == day_id, Day.group_id == group_id)).first()
    if not day:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Day not found")
    return day


@router.post("/", response_model=ScheduleItemRead, status_code=status.HTTP_201_CREATED)
def create_schedule_item(
    day_id: str,
    body: ScheduleItemCreate,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    _get_day(day_id, current_group.id, session)
    payload = body.model_dump()
    payload["visibility"] = _validate_visibility(payload.get("visibility", "private"))
    item = ScheduleItem(**payload, day_id=day_id)
    session.add(item)
    session.commit()
    session.refresh(item)
    return item


@router.get("/", response_model=list[ScheduleItemRead])
def list_schedule_items(
    day_id: str,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    _get_day(day_id, current_group.id, session)
    return session.exec(
        select(ScheduleItem).where(ScheduleItem.day_id == day_id).order_by(ScheduleItem.time)
    ).all()


@router.patch("/{item_id}", response_model=ScheduleItemRead)
def update_schedule_item(
    day_id: str,
    item_id: str,
    body: ScheduleItemUpdate,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    _get_day(day_id, current_group.id, session)
    item = session.exec(select(ScheduleItem).where(ScheduleItem.id == item_id, ScheduleItem.day_id == day_id)).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Schedule item not found")

    payload = body.model_dump(exclude_unset=True)
    if "visibility" in payload and payload["visibility"] is not None:
        payload["visibility"] = _validate_visibility(payload["visibility"])

    for key, value in payload.items():
        setattr(item, key, value)

    session.add(item)
    session.commit()
    session.refresh(item)
    return item


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_schedule_item(
    day_id: str,
    item_id: str,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    _get_day(day_id, current_group.id, session)
    item = session.exec(
        select(ScheduleItem).where(ScheduleItem.id == item_id, ScheduleItem.day_id == day_id)
    ).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Schedule item not found")
    session.delete(item)
    session.commit()
