from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from pydantic import BaseModel
from sqlmodel import Session, select

from app.auth import get_current_group
from app.database import get_session
from app.models import Day, DayType, Group, ScheduleItem
from app.services.duplicate_day import duplicate_day
from app.services.pdf_export import build_day_full_pdf, build_day_roadmap_pdf, date_filename, roadmap_filename

router = APIRouter(prefix="/days", tags=["days"])


class DayCreate(BaseModel):
    tour_id: Optional[str] = None
    date: date
    type: DayType = DayType.concert
    city: Optional[str] = None
    venue: Optional[str] = None
    address: Optional[str] = None
    promo_sent: bool = False
    coplateau: bool = False
    roadmap_sent: bool = False
    backline_conversation: bool = False
    day_note: Optional[str] = None
    contact_text: Optional[str] = None
    finance_text: Optional[str] = None
    hebergement: Optional[str] = None
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
    address: Optional[str] = None
    promo_sent: Optional[bool] = None
    coplateau: Optional[bool] = None
    roadmap_sent: Optional[bool] = None
    backline_conversation: Optional[bool] = None
    day_note: Optional[str] = None
    contact_text: Optional[str] = None
    finance_text: Optional[str] = None
    hebergement: Optional[str] = None
    travel_notes: Optional[str] = None
    shared_gear: Optional[str] = None


def _validate_free_text(value: Optional[str], field_name: str) -> Optional[str]:
    if value is None:
        return None
    normalized = value.strip()
    if not normalized:
        return None
    if len(normalized) > 3000:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{field_name} must be at most 3000 characters",
        )
    return normalized


def _normalize_address(value: Optional[str], required: bool) -> Optional[str]:
    if value is None:
        if required:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="address is required for concert",
            )
        return None
    normalized = value.strip()
    if not normalized:
        if required:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="address is required for concert",
            )
        return None
    return normalized


def _apply_boolean_rules(payload: dict, effective_type: DayType):
    if effective_type == DayType.day_off:
        payload["promo_sent"] = False
        payload["coplateau"] = False
        payload["roadmap_sent"] = False
        payload["backline_conversation"] = False
        return

    if payload.get("coplateau") is False:
        payload["roadmap_sent"] = False
        payload["backline_conversation"] = False


@router.post("/", response_model=DayRead, status_code=status.HTTP_201_CREATED)
def create_day(
    body: DayCreate,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    payload = body.model_dump()
    payload["contact_text"] = _validate_free_text(payload.get("contact_text"), "contact_text")
    payload["finance_text"] = _validate_free_text(payload.get("finance_text"), "finance_text")
    payload["day_note"] = _validate_free_text(payload.get("day_note"), "day_note")
    payload["hebergement"] = _validate_free_text(payload.get("hebergement"), "hebergement")

    if payload.get("tour_id") is None:
        payload["type"] = DayType.concert

    day_type = payload.get("type")
    payload["address"] = _normalize_address(payload.get("address"), required=day_type == DayType.concert)
    _apply_boolean_rules(payload, day_type)

    day = Day(**payload, group_id=current_group.id)
    session.add(day)
    session.commit()
    session.refresh(day)
    return day


@router.get("/", response_model=list[DayRead])
def list_days(
    tour_id: Optional[str] = None,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    stmt = select(Day).where(Day.group_id == current_group.id)
    if tour_id:
        stmt = stmt.where(Day.tour_id == tour_id)
    return session.exec(stmt.order_by(Day.date)).all()


@router.get("/{day_id}", response_model=DayRead)
def get_day(
    day_id: str,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    day = session.exec(select(Day).where(Day.id == day_id, Day.group_id == current_group.id)).first()
    if not day:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Day not found")
    return day


@router.patch("/{day_id}", response_model=DayRead)
def update_day(
    day_id: str,
    body: DayUpdate,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    day = session.exec(select(Day).where(Day.id == day_id, Day.group_id == current_group.id)).first()
    if not day:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Day not found")
    payload = body.model_dump(exclude_unset=True)
    if "contact_text" in payload:
        payload["contact_text"] = _validate_free_text(payload.get("contact_text"), "contact_text")
    if "finance_text" in payload:
        payload["finance_text"] = _validate_free_text(payload.get("finance_text"), "finance_text")
    if "day_note" in payload:
        payload["day_note"] = _validate_free_text(payload.get("day_note"), "day_note")
    if "hebergement" in payload:
        payload["hebergement"] = _validate_free_text(payload.get("hebergement"), "hebergement")

    effective_type = payload.get("type", day.type)

    if "address" in payload:
        payload["address"] = _normalize_address(payload.get("address"), required=effective_type == DayType.concert)
    elif effective_type == DayType.concert:
        payload["address"] = _normalize_address(day.address, required=True)

    _apply_boolean_rules(payload, effective_type)

    if effective_type == DayType.concert:
        effective_coplateau = payload.get("coplateau", day.coplateau)
        if not effective_coplateau:
            payload["roadmap_sent"] = False
            payload["backline_conversation"] = False

    for key, value in payload.items():
        setattr(day, key, value)
    session.add(day)
    session.commit()
    session.refresh(day)
    return day


@router.delete("/{day_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_day(
    day_id: str,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    day = session.exec(select(Day).where(Day.id == day_id, Day.group_id == current_group.id)).first()
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
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    day = session.exec(select(Day).where(Day.id == day_id, Day.group_id == current_group.id)).first()
    if not day:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Day not found")
    return duplicate_day(session, day, body.new_date)


@router.get("/{day_id}/export/full")
def export_day_full_pdf(
    day_id: str,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    day = session.exec(select(Day).where(Day.id == day_id, Day.group_id == current_group.id)).first()
    if not day:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Day not found")

    schedules = session.exec(select(ScheduleItem).where(ScheduleItem.day_id == day.id).order_by(ScheduleItem.time)).all()
    pdf = build_day_full_pdf(day, schedules)
    filename = date_filename(day)
    return Response(
        content=pdf,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/{day_id}/export/roadmap")
def export_day_roadmap_pdf(
    day_id: str,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    day = session.exec(select(Day).where(Day.id == day_id, Day.group_id == current_group.id)).first()
    if not day:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Day not found")
    if day.type == DayType.day_off:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Roadmap export unavailable for day_off",
        )

    schedules = session.exec(
        select(ScheduleItem)
        .where(ScheduleItem.day_id == day.id, ScheduleItem.visibility == "public")
        .order_by(ScheduleItem.time)
    ).all()

    if not schedules:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="No public schedule to export")

    pdf = build_day_roadmap_pdf(day, schedules)
    filename = roadmap_filename(day)
    return Response(
        content=pdf,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
