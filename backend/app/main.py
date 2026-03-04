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
from app.models.user import User
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

# Create test user if not exists
def create_test_user():
    db: Session = SessionLocal()
    try:
        test_user = db.query(User).filter(User.username == "user").first()
        if not test_user:
            pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
            
            # 安全地哈希密码，处理bcrypt的72字节限制
            password = "12345678"
            # 确保密码是字符串
            if not isinstance(password, str):
                password = str(password)
            
            # 如果密码长度超过72字节（bcrypt限制），进行截断
            password_bytes = password.encode('utf-8')
            if len(password_bytes) > 72:
                password_bytes = password_bytes[:72]
                password = password_bytes.decode('utf-8', errors='ignore')
            
            try:
                hashed_password = pwd_context.hash(password)
            except Exception as e:
                # 如果bcrypt失败，使用简单的sha256哈希作为回退（仅用于测试）
                import hashlib
                hashed_password = hashlib.sha256(password.encode('utf-8')).hexdigest()
                print(f"Warning: Using SHA256 fallback for password hash due to bcrypt error: {e}")
            
            test_user = User(
                username="user",
                email="user@example.com",
                hashed_password=hashed_password,
                nickname="测试用户",
                is_active=True
            )
            db.add(test_user)
            db.commit()
            print("Test user created: user/12345678")
    except Exception as e:
        print(f"Error creating test user: {e}")
    finally:
        db.close()

create_test_user()

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
