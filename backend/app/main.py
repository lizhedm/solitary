from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from sqlalchemy import text
import os

# 在导入passlib之前补丁bcrypt以解决版本检测问题
import bcrypt
if not hasattr(bcrypt, '__about__'):
    # 创建一个简单的__about__模块，包含__version__属性
    class AboutModule:
        __version__ = getattr(bcrypt, '__version__', '4.1.2')
    bcrypt.__about__ = AboutModule()

from app.routers import auth, hiking, messages, friends
from app.database import database
# 显式导入所有模型，确保 create_all 能正确创建表
from app.models import User, HikingRecord, Message, Feedback, Friendship, FriendMessage, TempFriendship
from app.database.database import SessionLocal
from passlib.context import CryptContext
import time

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


def _ensure_schema_updates():
    """轻量级补字段/补表，兼容已有 SQLite 数据库。"""
    with database.engine.begin() as conn:
        # feedbacks.forward_count
        try:
            conn.execute(text("ALTER TABLE feedbacks ADD COLUMN forward_count INTEGER DEFAULT 0"))
        except Exception:
            pass
        # temp_friendships
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS temp_friendships (
                id INTEGER PRIMARY KEY,
                user_id INTEGER,
                partner_id INTEGER,
                last_message TEXT,
                last_message_type TEXT,
                last_timestamp BIGINT,
                created_at BIGINT,
                updated_at BIGINT
            )
        """))
        try:
            conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS uq_temp_friendship_user_partner_idx ON temp_friendships (user_id, partner_id)"))
        except Exception:
            pass


_ensure_schema_updates()

app.include_router(auth.router, tags=["auth"])
app.include_router(hiking.router, tags=["hiking"])
app.include_router(messages.router, tags=["messages"])
app.include_router(friends.router, tags=["friends"])

# 创建上传目录（如果不存在）
os.makedirs("uploads/avatars", exist_ok=True)

# 添加静态文件服务，用于提供上传的头像
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

@app.get("/")
def read_root():
    return {"message": "Welcome to Solitary API"}
