from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth, hiking, messages
from app.database import database

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create tables
database.Base.metadata.create_all(bind=database.engine)

app.include_router(auth.router)
app.include_router(hiking.router)
app.include_router(messages.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to Solitary API"}
