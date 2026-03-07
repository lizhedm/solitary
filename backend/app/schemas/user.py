from pydantic import BaseModel
from typing import Optional

class UserBase(BaseModel):
    username: str
    email: Optional[str] = None
    nickname: Optional[str] = None

class UserCreate(UserBase):
    password: str

class User(UserBase):
    id: int
    is_active: bool
    avatar: Optional[str] = None
    
    # 徒步状态与位置
    is_hiking: bool = False
    current_lat: Optional[float] = None
    current_lng: Optional[float] = None
    location_updated_at: Optional[int] = None

    # 隐私设置
    visible_on_map: bool = True
    visible_range: int = 5
    receive_sos: bool = True
    receive_questions: bool = True
    receive_feedback: bool = True

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None
