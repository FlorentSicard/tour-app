from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlmodel import Session, select

from app.auth import get_current_group
from app.database import get_session
from app.models import Group

router = APIRouter(prefix="/groups", tags=["groups"])


class GroupRead(BaseModel):
    id: str
    name: str
    email: str


class PublicGroupRead(BaseModel):
    id: str
    name: str


@router.get("/", response_model=list[PublicGroupRead])
def list_groups(session: Session = Depends(get_session)):
    return session.exec(select(Group).order_by(Group.name)).all()


@router.get("/me", response_model=GroupRead)
def get_my_group(group: Group = Depends(get_current_group)):
    return group
