from sqlalchemy import Column, Integer, ForeignKey, BigInteger
from sqlalchemy.orm import relationship
from app.database.database import Base
import time

class Snap(Base):
    __tablename__ = "snaps"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    target_id = Column(Integer, ForeignKey("users.id"))
    created_at = Column(BigInteger, default=lambda: int(time.time() * 1000))

    user = relationship("User", foreign_keys=[user_id])
    target = relationship("User", foreign_keys=[target_id])
