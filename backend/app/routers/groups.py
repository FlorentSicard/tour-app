from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlmodel import Session, select

from app.auth import get_current_user
from app.database import get_session
from app.models import Group, Membership, RoleEnum, User

router = APIRouter(prefix="/groups", tags=["groups"])


class GroupCreate(BaseModel):
    name: str


class GroupRead(BaseModel):
    id: str
    name: str
    owner_id: str


@router.post("/", response_model=GroupRead, status_code=status.HTTP_201_CREATED)
def create_group(
    body: GroupCreate,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    group = Group(name=body.name, owner_id=user.id)
    session.add(group)
    session.flush()
    session.add(Membership(user_id=user.id, group_id=group.id, role=RoleEnum.admin))
    session.commit()
    session.refresh(group)
    return group


@router.get("/", response_model=list[GroupRead])
def list_my_groups(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    memberships = session.exec(select(Membership).where(Membership.user_id == user.id)).all()
    group_ids = [m.group_id for m in memberships]
    if not group_ids:
        return []
    return session.exec(select(Group).where(Group.id.in_(group_ids))).all()
