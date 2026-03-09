from sqlalchemy import Column, Integer, String, ForeignKey, BigInteger, Enum
from sqlalchemy.orm import relationship
from app.database.database import Base
import time

class Friendship(Base):
    __tablename__ = "friendships"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    friend_id = Column(Integer, ForeignKey("users.id"))
    status = Column(String, default="ACCEPTED") # PENDING, ACCEPTED, BLOCKED
    created_at = Column(BigInteger, default=lambda: int(time.time() * 1000))

    user = relationship("User", foreign_keys=[user_id], back_populates="friends")
    friend = relationship("User", foreign_keys=[friend_id])
