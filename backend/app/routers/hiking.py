from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.database.database import get_db
from app.models.hiking import HikingRecord
from app.routers.auth import get_current_user
from app.models.user import User
from pydantic import BaseModel

router = APIRouter()

class HikingRecordCreate(BaseModel):
    start_time: int
    end_time: int
    duration: int
    distance: float
    start_location: str
    end_location: str
    map_snapshot: str | None = None

class HikingRecordOut(HikingRecordCreate):
    id: int
    user_id: int
    
    class Config:
        from_attributes = True

@router.post("/hiking/records", response_model=HikingRecordOut)
def create_hiking_record(
    record: HikingRecordCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    db_record = HikingRecord(**record.dict(), user_id=current_user.id)
    db.add(db_record)
    db.commit()
    db.refresh(db_record)
    return db_record

@router.get("/hiking/records", response_model=List[HikingRecordOut])
def get_hiking_records(
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    records = db.query(HikingRecord).filter(HikingRecord.user_id == current_user.id).offset(skip).limit(limit).all()
    return records
