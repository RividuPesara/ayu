from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes.feed import router as feed_router
from routes.moderation import router as moderation_router
from routes.posts import router as posts_router
from routes.documents import router as documents_router
from routes.profile import router as profile_router
from routes.patient import router as patient_router
from routes.account_logs import router as account_logs_router
from routes.doctors import router as doctor_router
from routes.articles import router as articles_router
from routes.dashboard import router as dashboard_router
from routes.manage import router as manage_router
from routes.sidebar import router as sidebar_router

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(feed_router, prefix="/api/feed")
app.include_router(moderation_router, prefix="/api/moderation/posts")
app.include_router(posts_router, prefix="/api/posts")
app.include_router(documents_router, prefix="/api/documents", tags=["Documents"])
app.include_router(profile_router, prefix="/api/profile", tags=["Profile"])
app.include_router(patient_router, prefix="/api/patient", tags=["Patients"])
app.include_router(account_logs_router, prefix="/api/account-logs", tags=["Account Logs"])
app.include_router(doctor_router, prefix="/api/doctors", tags=["Doctors"])
app.include_router(articles_router, prefix="/api/articles", tags=["Articles"])
app.include_router(dashboard_router, prefix="/api/dashboard", tags=["Dashboard"])
app.include_router(manage_router, prefix="/api/manage")
app.include_router(sidebar_router, prefix="/api/sidebar", tags=["Sidebar"])
