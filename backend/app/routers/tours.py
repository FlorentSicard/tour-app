from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from pydantic import BaseModel
from sqlmodel import Session, select

from app.auth import get_current_group
from app.database import get_session
from app.models import Day, Group, ScheduleItem, Tour
from app.services.pdf_export import build_tour_full_pdf, tour_filename

router = APIRouter(prefix="/tours", tags=["tours"])


class TourCreate(BaseModel):
    name: str


class TourRead(BaseModel):
    id: str
    group_id: str
    name: str


@router.post("/", response_model=TourRead, status_code=status.HTTP_201_CREATED)
def create_tour(
    body: TourCreate,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    tour = Tour(name=body.name, group_id=current_group.id)
    session.add(tour)
    session.commit()
    session.refresh(tour)
    return tour


@router.get("/", response_model=list[TourRead])
def list_tours(
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    return session.exec(select(Tour).where(Tour.group_id == current_group.id)).all()


@router.get("/{tour_id}", response_model=TourRead)
def get_tour(
    tour_id: str,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    tour = session.exec(select(Tour).where(Tour.id == tour_id, Tour.group_id == current_group.id)).first()
    if not tour:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tour not found")
    return tour


@router.delete("/{tour_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_tour(
    tour_id: str,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    tour = session.exec(select(Tour).where(Tour.id == tour_id, Tour.group_id == current_group.id)).first()
    if not tour:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tour not found")
    session.delete(tour)
    session.commit()


@router.get("/{tour_id}/export/full")
def export_tour_full_pdf(
    tour_id: str,
    current_group: Group = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    tour = session.exec(select(Tour).where(Tour.id == tour_id, Tour.group_id == current_group.id)).first()
    if not tour:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tour not found")

    days = session.exec(select(Day).where(Day.group_id == current_group.id, Day.tour_id == tour.id)).all()
    if not days:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Tour has no dates")

    day_ids = [d.id for d in days]
    schedules = session.exec(
        select(ScheduleItem)
        .where(ScheduleItem.day_id.in_(day_ids))
        .order_by(ScheduleItem.day_id, ScheduleItem.time)
    ).all()

    schedules_by_day_id: dict[str, list[ScheduleItem]] = {d.id: [] for d in days}
    for schedule in schedules:
        schedules_by_day_id.setdefault(schedule.day_id, []).append(schedule)

    day_entries = [(day, schedules_by_day_id.get(day.id, [])) for day in days]
    pdf = build_tour_full_pdf(tour, day_entries)
    filename = tour_filename(tour)
    return Response(
        content=pdf,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
