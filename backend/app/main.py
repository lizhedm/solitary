from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
import os

# 在导入passlib之前补丁bcrypt以解决版本检测问题
import bcrypt
if not hasattr(bcrypt, '__about__'):
    # 创建一个简单的__about__模块，包含__version__属性
    class AboutModule:
        __version__ = getattr(bcrypt, '__version__', '4.1.2')
    bcrypt.__about__ = AboutModule()

from app.routers import auth, hiking, messages
from app.database import database
# 显式导入所有模型，确保 create_all 能正确创建表
from app.models import User, HikingRecord, Message, Feedback
from app.database.database import SessionLocal
from passlib.context import CryptContext

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

# 创建上传目录（如果不存在）
os.makedirs("uploads/avatars", exist_ok=True)

# 添加静态文件服务，用于提供上传的头像
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

@app.get("/")
def read_root():
    return {"message": "Welcome to Solitary API"}
