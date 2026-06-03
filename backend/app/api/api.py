from fastapi import APIRouter

from app.api.routers import auth, companion, doctor, chatbot, videos, journal, appointments, doctors, tracker, community, patient, donation, tasks, articles, notifications

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(doctor.router)
api_router.include_router(patient.router)
api_router.include_router(chatbot.router)
api_router.include_router(videos.router)
api_router.include_router(journal.router)
api_router.include_router(appointments.router)
api_router.include_router(doctors.router)
api_router.include_router(tracker.router)
api_router.include_router(community.router)
api_router.include_router(donation.router)
api_router.include_router(companion.router)
api_router.include_router(tasks.router)
api_router.include_router(articles.router)
api_router.include_router(notifications.router)