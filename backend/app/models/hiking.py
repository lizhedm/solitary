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
    calories = Column(Integer, default=0) # kcal
    elevation_gain = Column(Integer, default=0) # Meters
    
    start_location = Column(String)
    end_location = Column(String)
    start_latitude = Column(Float, nullable=True)
    start_longitude = Column(Float, nullable=True)
    end_latitude = Column(Float, nullable=True)
    end_longitude = Column(Float, nullable=True)
    
    map_snapshot = Column(String, nullable=True)
    coordinates_json = Column(String, nullable=True) # JSON string of coordinates
    message_count = Column(Integer, default=0) # Number of messages
    
    user = relationship("User", back_populates="hikes")
