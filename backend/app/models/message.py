from sqlalchemy import Column, Integer, String, Float, ForeignKey, Boolean, BigInteger
from sqlalchemy.orm import relationship
from app.database.database import Base

class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("users.id"))
    receiver_id = Column(Integer, ForeignKey("users.id"), nullable=True) # Null for broadcast/group
    
    content = Column(String)
    type = Column(String) # 'text', 'image', 'sos', 'feedback', 'question'
    timestamp = Column(BigInteger)
    is_read = Column(Boolean, default=False)
    
    sender_hike_id = Column(Integer, ForeignKey("hiking_records.id"), nullable=True)
    receiver_hike_id = Column(Integer, ForeignKey("hiking_records.id"), nullable=True)
    
    sender = relationship("User", foreign_keys=[sender_id])
    receiver = relationship("User", foreign_keys=[receiver_id])

class Feedback(Base):
    __tablename__ = "feedbacks"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    
    type = Column(String) # 'blocked', 'weather', etc.
    content = Column(String)
    latitude = Column(Float)
    longitude = Column(Float)
    address = Column(String)
    photos = Column(String, nullable=True) # JSON list of URLs
    
    created_at = Column(BigInteger)
    status = Column(String, default='ACTIVE') # ACTIVE, EXPIRED
    
    view_count = Column(Integer, default=0)
    confirm_count = Column(Integer, default=0)
    
    user = relationship("User", back_populates="feedbacks")

class SOSAlert(Base):
    __tablename__ = "sos_alerts"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    latitude = Column(Float)
    longitude = Column(Float)
    message = Column(String)
    photos = Column(String, nullable=True)  # JSON list of base64 strings (临时存DB，后续可换成URL列表)
    status = Column(String, default='ACTIVE') # ACTIVE, RESOLVED
    created_at = Column(BigInteger)
    resolved_at = Column(BigInteger, nullable=True)
    
    user = relationship("User")
