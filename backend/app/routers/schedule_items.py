from datetime import time
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlmodel import Session, select

from app.auth import get_current_group
from app.database import get_session
from app.models import Day, ScheduleItem

router = APIRouter(prefix="/days/{day_id}/schedule", tags=["schedule"])


class ScheduleItemCreate(BaseModel):
    time: time
    label: str
    notes: Optional[str] = None


class ScheduleItemRead(ScheduleItemCreate):
    id: str
    day_id: str


def _get_day(day_id: str, group_id: str, session: Session) -> Day:
    day = session.exec(select(Day).where(Day.id == day_id, Day.group_id == group_id)).first()
    if not day:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Day not found")
    return day


@router.post("/", response_model=ScheduleItemRead, status_code=status.HTTP_201_CREATED)
def create_schedule_item(
    day_id: str,
    body: ScheduleItemCreate,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    _get_day(day_id, group_id, session)
    item = ScheduleItem(**body.model_dump(), day_id=day_id)
    session.add(item)
    session.commit()
    session.refresh(item)
    return item


@router.get("/", response_model=list[ScheduleItemRead])
def list_schedule_items(
    day_id: str,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    _get_day(day_id, group_id, session)
    return session.exec(
        select(ScheduleItem).where(ScheduleItem.day_id == day_id).order_by(ScheduleItem.time)
    ).all()


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_schedule_item(
    day_id: str,
    item_id: str,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    _get_day(day_id, group_id, session)
    item = session.exec(
        select(ScheduleItem).where(ScheduleItem.id == item_id, ScheduleItem.day_id == day_id)
    ).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Schedule item not found")
    session.delete(item)
    session.commit()
