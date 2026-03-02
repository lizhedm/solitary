from sqlalchemy import Boolean, Column, Integer, String
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
    
    hikes = relationship("HikingRecord", back_populates="user")
    feedbacks = relationship("Feedback", back_populates="user")
