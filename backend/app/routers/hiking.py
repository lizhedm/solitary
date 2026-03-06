import os
import shutil
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, File, UploadFile
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
    calories: int
    elevation_gain: int
    start_location: str | None = None
    end_location: str | None = None
    map_snapshot_url: str | None = None
    coordinates_json: str | None = None
    message_count: int = 0

class HikingRecordOut(HikingRecordCreate):
    id: int
    user_id: int
    map_snapshot: str | None = None
    
    class Config:
        from_attributes = True

@router.post("/upload/snapshot")
async def upload_snapshot(file: UploadFile = File(...)):
    try:
        # Create directory if not exists
        upload_dir = "uploads/snapshots"
        os.makedirs(upload_dir, exist_ok=True)
        
        # Generate filename
        timestamp = int(datetime.now().timestamp())
        filename = f"snapshot_{timestamp}_{file.filename}"
        file_path = os.path.join(upload_dir, filename)
        
        # Save file
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        return {"url": f"/uploads/snapshots/{filename}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/hiking-records", response_model=HikingRecordOut)
def create_hiking_record(
    record: HikingRecordCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    # Map map_snapshot_url to map_snapshot for DB
    db_record = HikingRecord(
        start_time=record.start_time,
        end_time=record.end_time,
        duration=record.duration,
        distance=record.distance,
        calories=record.calories,
        elevation_gain=record.elevation_gain,
        start_location=record.start_location,
        end_location=record.end_location,
        map_snapshot=record.map_snapshot_url,
        coordinates_json=record.coordinates_json,
        message_count=record.message_count,
        user_id=current_user.id
    )
    db.add(db_record)
    db.commit()
    db.refresh(db_record)
    # Map back for response
    return db_record

@router.get("/hiking-records", response_model=dict)
def get_hiking_records(
    skip: int = 0, 
    limit: int = 100, 
    user_id: int | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Filter by user_id if provided, otherwise use current user
    # Ideally should only allow accessing own records or admin access
    target_user_id = user_id if user_id else current_user.id
    if target_user_id != current_user.id:
        # Simple permission check: only allow own data for now
        # raise HTTPException(status_code=403, detail="Not authorized")
        pass # Allow for demo purpose if needed, or strictly enforce:
        target_user_id = current_user.id

    query = db.query(HikingRecord).filter(HikingRecord.user_id == target_user_id)
    total_count = query.count()
    records = query.order_by(HikingRecord.start_time.desc()).offset(skip).limit(limit).all()
    
    # Calculate aggregates
    total_distance = sum(r.distance for r in records) # This is sum of *fetched* records, maybe should be total?
    # For total stats, we should query all records without limit
    all_records = db.query(HikingRecord).filter(HikingRecord.user_id == target_user_id).all()
    total_distance_all = sum(r.distance for r in all_records)
    total_elevation_gain_all = sum(r.elevation_gain for r in all_records)
    
    # Transform records to match frontend expectation if needed, or use response_model
    # The frontend expects:
    # {
    #   "records": [...],
    #   "total_count": 10,
    #   "total_distance": 100.0,
    #   "total_elevation_gain": 500
    # }
    
    result_records = []
    for r in records:
        result_records.append({
            "id": r.id,
            "user_id": r.user_id,
            "start_time": r.start_time,
            "end_time": r.end_time,
            "duration": r.duration,
            "distance": r.distance,
            "calories": r.calories,
            "elevation_gain": r.elevation_gain,
            "start_location": r.start_location,
            "end_location": r.end_location,
            "map_snapshot_url": r.map_snapshot, # Map DB field to frontend field
            "coordinates_json": r.coordinates_json,
            "message_count": r.message_count
        })

    return {
        "records": result_records,
        "total_count": total_count,
        "total_distance": total_distance_all,
        "total_elevation_gain": total_elevation_gain_all
    }
