from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Request
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt

# 在导入passlib之前补丁bcrypt以解决版本检测问题
import bcrypt
if not hasattr(bcrypt, '__about__'):
    # 创建一个简单的__about__模块，包含__version__属性
    class AboutModule:
        __version__ = getattr(bcrypt, '__version__', '4.1.2')
    bcrypt.__about__ = AboutModule()

from passlib.context import CryptContext
from sqlalchemy.orm import Session
import shutil
import os
from app.database.database import get_db
from app.models.user import User
from app.schemas.user import UserCreate, User as UserSchema, Token, TokenData
from pydantic import BaseModel

router = APIRouter()

SECRET_KEY = "your_secret_key_keep_it_secret" # In production, use env variable
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    # 确保密码是字符串
    if not isinstance(password, str):
        password = str(password)
    
    # 如果密码长度超过72字节（bcrypt限制），进行截断
    # bcrypt限制密码为72字节，不是字符
    password_bytes = password.encode('utf-8')
    if len(password_bytes) > 72:
        password_bytes = password_bytes[:72]
        password = password_bytes.decode('utf-8', errors='ignore')
    
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # Development convenience: accept a hard-coded test token to allow frontend demo without JWTs
        if token == "test_token_12345678":
            user = db.query(User).filter(User.username == "user").first()
            if user is None:
                raise credentials_exception
            return user
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: Optional[str] = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except JWTError:
        raise credentials_exception
    user = db.query(User).filter(User.username == token_data.username).first()
    if user is None:
        raise credentials_exception
    return user

@router.post("/register", response_model=UserSchema)
def register(user: UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.username == user.username).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    hashed_password = get_password_hash(user.password)
    db_user = User(
        username=user.username,
        email=user.email,
        hashed_password=hashed_password,
        nickname=user.nickname or user.username
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@router.post("/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

class UserUpdate(BaseModel):
    nickname: Optional[str] = None
    email: Optional[str] = None
    avatar: Optional[str] = None

@router.get("/users/me", response_model=UserSchema)
async def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

@router.post("/users/me/update", response_model=UserSchema)
async def update_user_profile(
    user_update: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # 更新提供的字段
    if user_update.nickname is not None:
        current_user.nickname = user_update.nickname  # type: ignore
    if user_update.email is not None:
        current_user.email = user_update.email  # type: ignore
    if user_update.avatar is not None:
        current_user.avatar = user_update.avatar  # type: ignore
    
    db.commit()
    db.refresh(current_user)
    return current_user

@router.post("/users/me/avatar", response_model=dict)
async def upload_avatar(
    request: Request,  # 添加Request参数以获取基础URL
    avatar: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # 创建上传目录（如果不存在）
    upload_dir = "uploads/avatars"
    os.makedirs(upload_dir, exist_ok=True)
    
    # 生成文件名
    if not avatar.filename:
        raise HTTPException(status_code=400, detail="No filename provided")
    file_extension = os.path.splitext(avatar.filename)[1]  # type: ignore
    filename = f"user_{current_user.id}_avatar{file_extension}"
    file_path = os.path.join(upload_dir, filename)
    
    # 保存文件
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(avatar.file, buffer)
    
    # 生成完整的头像URL
    # 使用请求的基础URL构建绝对路径
    base_url = str(request.base_url)
    # 移除末尾的斜杠
    if base_url.endswith('/'):
        base_url = base_url[:-1]
    avatar_url = f"{base_url}/uploads/avatars/{filename}"
    
    # 更新用户头像URL
    current_user.avatar = avatar_url  # type: ignore
    
    db.commit()
    db.refresh(current_user)
    
    return {"avatar_url": avatar_url}
