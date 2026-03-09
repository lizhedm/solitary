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

from app.routers import auth, hiking, messages, friends
from app.database import database
# 显式导入所有模型，确保 create_all 能正确创建表
from app.models import User, HikingRecord, Message, Feedback, Friendship
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

app.include_router(auth.router)
app.include_router(hiking.router)
app.include_router(messages.router)
app.include_router(friends.router)

# 创建上传目录（如果不存在）
os.makedirs("uploads/avatars", exist_ok=True)

# 添加静态文件服务，用于提供上传的头像
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

@app.on_event("startup")
def startup_event():
    # Initialize users and friendships for testing
    db = SessionLocal()
    try:
        # Create user1 if not exists
        user1 = db.query(User).filter(User.username == "user1").first()
        if not user1:
            print("Creating user1")
            hashed_pwd = auth.get_password_hash("password")
            user1 = User(
                username="user1",
                email="user1@example.com",
                nickname="User One",
                hashed_password=hashed_pwd,
                is_active=True
            )
            db.add(user1)
            db.commit()
            db.refresh(user1)

        # Create user2 if not exists
        user2 = db.query(User).filter(User.username == "user2").first()
        if not user2:
            print("Creating user2")
            hashed_pwd = auth.get_password_hash("password")
            user2 = User(
                username="user2",
                email="user2@example.com",
                nickname="User Two",
                hashed_password=hashed_pwd,
                is_active=True
            )
            db.add(user2)
            db.commit()
            db.refresh(user2)
            
        if user1 and user2:
            # Check friendship
            exists = db.query(Friendship).filter(
                ((Friendship.user_id == user1.id) & (Friendship.friend_id == user2.id)) |
                ((Friendship.user_id == user2.id) & (Friendship.friend_id == user1.id))
            ).first()
            
            if not exists:
                print("Creating friendship between user1 and user2")
                f = Friendship(
                    user_id=user1.id, 
                    friend_id=user2.id, 
                    status="ACCEPTED", 
                    created_at=int(time.time()*1000)
                )
                db.add(f)
                db.commit()
    except Exception as e:
        print(f"Error in startup event: {e}")
    finally:
        db.close()

@app.get("/")
def read_root():
    return {"message": "Welcome to Solitary API"}
