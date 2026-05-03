from contextlib import asynccontextmanager

from apscheduler.schedulers.background import BackgroundScheduler
from fastapi import FastAPI

from app.database import init_db
from app.routers import auth, groups, tours, days, schedule_items, checklists
from app.services.reminder import flag_overdue_items

scheduler = BackgroundScheduler()


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    scheduler.add_job(flag_overdue_items, "cron", hour=0, minute=0)
    scheduler.start()
    yield
    scheduler.shutdown()


app = FastAPI(title="TourApp", version="0.1.0", lifespan=lifespan)

app.include_router(auth.router)
app.include_router(groups.router)
app.include_router(tours.router)
app.include_router(days.router)
app.include_router(schedule_items.router)
app.include_router(checklists.router)


@app.get("/health")
def health():
    return {"status": "ok"}
