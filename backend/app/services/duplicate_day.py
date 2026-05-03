from datetime import date, timedelta

from sqlmodel import Session, select

from app.models import ChecklistItem, Day, ScheduleItem, gen_uuid


def duplicate_day(session: Session, source_day: Day, new_date: date) -> Day:
    delta = new_date - source_day.date

    new_day = Day(
        group_id=source_day.group_id,
        tour_id=source_day.tour_id,
        date=new_date,
        type=source_day.type,
        city=source_day.city,
        venue=source_day.venue,
        notes=source_day.notes,
        contact_name=source_day.contact_name,
        contact_phone=source_day.contact_phone,
        contact_email=source_day.contact_email,
        deal_amount=source_day.deal_amount,
        deal_currency=source_day.deal_currency,
        travel_notes=source_day.travel_notes,
        shared_gear=source_day.shared_gear,
    )
    session.add(new_day)
    session.flush()

    items = session.exec(select(ScheduleItem).where(ScheduleItem.day_id == source_day.id)).all()
    for si in items:
        session.add(ScheduleItem(day_id=new_day.id, time=si.time, label=si.label, notes=si.notes))

    checklists = session.exec(
        select(ChecklistItem).where(ChecklistItem.day_id == source_day.id, ChecklistItem.is_done == False)
    ).all()
    for ci in checklists:
        new_due = ci.due_date + delta if ci.due_date else None
        session.add(
            ChecklistItem(
                day_id=new_day.id,
                template_id=ci.template_id,
                label=ci.label,
                due_date=new_due,
                assigned_to=ci.assigned_to,
            )
        )

    session.commit()
    session.refresh(new_day)
    return new_day
