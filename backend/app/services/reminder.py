from datetime import date

from sqlmodel import Session, select

from app.database import engine
from app.models import ChecklistItem


def flag_overdue_items():
    with Session(engine) as session:
        items = session.exec(
            select(ChecklistItem).where(
                ChecklistItem.is_done == False,
                ChecklistItem.due_date <= date.today(),
                ChecklistItem.is_overdue_flagged == False,
            )
        ).all()
        for item in items:
            item.is_overdue_flagged = True
            session.add(item)
        session.commit()
