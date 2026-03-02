from sqlalchemy import Column, Integer, String, Float, ForeignKey, Boolean, BigInteger
from sqlalchemy.orm import relationship
from app.database.database import Base

class HikingRecord(Base):
    __tablename__ = "hiking_records"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    
    start_time = Column(BigInteger) # Timestamp
    end_time = Column(BigInteger)
    duration = Column(Integer) # Seconds
    distance = Column(Float) # Meters
    
    start_location = Column(String)
    end_location = Column(String)
    
    map_snapshot = Column(String, nullable=True)
    
    user = relationship("User", back_populates="hikes")
