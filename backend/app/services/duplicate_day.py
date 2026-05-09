from datetime import date

from sqlmodel import Session, select

from app.models import Day, ScheduleItem


def duplicate_day(session: Session, source_day: Day, new_date: date) -> Day:
    delta = new_date - source_day.date

    new_day = Day(
        group_id=source_day.group_id,
        tour_id=source_day.tour_id,
        date=new_date,
        type=source_day.type,
        city=source_day.city,
        venue=source_day.venue,
    address=source_day.address,
    promo_sent=source_day.promo_sent,
    coplateau=source_day.coplateau,
    roadmap_sent=source_day.roadmap_sent,
    backline_conversation=source_day.backline_conversation,
        day_note=source_day.day_note,
        contact_text=source_day.contact_text,
        finance_text=source_day.finance_text,
    hebergement=source_day.hebergement,
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
        session.add(
            ScheduleItem(
                day_id=new_day.id,
                time=si.time,
                label=si.label,
                notes=si.notes,
                visibility=si.visibility,
            )
        )

    session.commit()
    session.refresh(new_day)
    return new_day
