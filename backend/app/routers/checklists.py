from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlmodel import Session, select

from app.auth import get_current_group
from app.database import get_session
from app.models import ChecklistItem, ChecklistTemplate, Day

router = APIRouter(tags=["checklists"])


class TemplateCreate(BaseModel):
    name: str
    category: Optional[str] = None
    default_offset_days: int = 0


class TemplateRead(TemplateCreate):
    id: str
    group_id: str


class ChecklistItemCreate(BaseModel):
    template_id: Optional[str] = None
    label: str
    due_date: Optional[date] = None
    assigned_to: Optional[str] = None


class ChecklistItemRead(ChecklistItemCreate):
    id: str
    day_id: str
    is_done: bool
    is_overdue_flagged: bool


class ChecklistItemUpdate(BaseModel):
    is_done: Optional[bool] = None
    label: Optional[str] = None
    due_date: Optional[date] = None
    assigned_to: Optional[str] = None


@router.post("/checklist-templates", response_model=TemplateRead, status_code=status.HTTP_201_CREATED)
def create_template(
    body: TemplateCreate,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    tpl = ChecklistTemplate(**body.model_dump(), group_id=group_id)
    session.add(tpl)
    session.commit()
    session.refresh(tpl)
    return tpl


@router.get("/checklist-templates", response_model=list[TemplateRead])
def list_templates(
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    return session.exec(select(ChecklistTemplate).where(ChecklistTemplate.group_id == group_id)).all()


def _get_day(day_id: str, group_id: str, session: Session) -> Day:
    day = session.exec(select(Day).where(Day.id == day_id, Day.group_id == group_id)).first()
    if not day:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Day not found")
    return day


@router.post("/days/{day_id}/checklist", response_model=ChecklistItemRead, status_code=status.HTTP_201_CREATED)
def create_checklist_item(
    day_id: str,
    body: ChecklistItemCreate,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    _get_day(day_id, group_id, session)
    item = ChecklistItem(**body.model_dump(), day_id=day_id)
    session.add(item)
    session.commit()
    session.refresh(item)
    return item


@router.get("/days/{day_id}/checklist", response_model=list[ChecklistItemRead])
def list_checklist_items(
    day_id: str,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    _get_day(day_id, group_id, session)
    return session.exec(select(ChecklistItem).where(ChecklistItem.day_id == day_id)).all()


@router.patch("/checklist-items/{item_id}", response_model=ChecklistItemRead)
def update_checklist_item(
    item_id: str,
    body: ChecklistItemUpdate,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Checklist item not found")
    _get_day(item.day_id, group_id, session)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(item, key, value)
    session.add(item)
    session.commit()
    session.refresh(item)
    return item
