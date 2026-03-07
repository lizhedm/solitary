from sqlalchemy import Boolean, Column, Integer, String, Float, BigInteger
from sqlalchemy.orm import relationship
from app.database.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    is_active = Column(Boolean, default=True)
    nickname = Column(String)
    avatar = Column(String, nullable=True)
    
    # 徒步状态与位置
    is_hiking = Column(Boolean, default=False, index=True)
    current_lat = Column(Float, nullable=True)
    current_lng = Column(Float, nullable=True)
    location_updated_at = Column(BigInteger, nullable=True) # Timestamp in ms

    # 隐私设置
    visible_on_map = Column(Boolean, default=True) # 在地图上显示我的位置
    visible_range = Column(Integer, default=5) # 可见范围（公里）：1,3,5,10
    receive_sos = Column(Boolean, default=True) # 接收求救信息
    receive_questions = Column(Boolean, default=True) # 接收周围提问
    receive_feedback = Column(Boolean, default=True) # 接收路况反馈
    
    hikes = relationship("HikingRecord", back_populates="user")
    feedbacks = relationship("Feedback", back_populates="user")
