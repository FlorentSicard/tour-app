from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlmodel import Session, select

from app.auth import get_current_group, get_current_user
from app.database import get_session
from app.models import Tour, User

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
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    tour = Tour(name=body.name, group_id=group_id)
    session.add(tour)
    session.commit()
    session.refresh(tour)
    return tour


@router.get("/", response_model=list[TourRead])
def list_tours(
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    return session.exec(select(Tour).where(Tour.group_id == group_id)).all()


@router.get("/{tour_id}", response_model=TourRead)
def get_tour(
    tour_id: str,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    tour = session.exec(select(Tour).where(Tour.id == tour_id, Tour.group_id == group_id)).first()
    if not tour:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tour not found")
    return tour


@router.delete("/{tour_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_tour(
    tour_id: str,
    group_id: str = Depends(get_current_group),
    session: Session = Depends(get_session),
):
    tour = session.exec(select(Tour).where(Tour.id == tour_id, Tour.group_id == group_id)).first()
    if not tour:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tour not found")
    session.delete(tour)
    session.commit()
