import os
import shutil
import math
import time
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, File, UploadFile
from sqlalchemy.orm import Session
from sqlalchemy import text
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

class LocationUpdate(BaseModel):
    lat: float
    lng: float
    accuracy: float | None = None
    altitude: float | None = None

class NearbyUser(BaseModel):
    id: int
    nickname: str | None = None
    avatar: str | None = None
    lat: float
    lng: float
    distance: float
    visible_range: int

class PrivacySettingsUpdate(BaseModel):
    visible_on_map: bool | None = None
    visible_range: int | None = None
    receive_sos: bool | None = None
    receive_questions: bool | None = None
    receive_feedback: bool | None = None

# -----------------------------------------------------------------------------
# 1. 徒步状态管理 (Start/End/Heartbeat)
# -----------------------------------------------------------------------------

@router.post("/hiking/start")
def start_hiking(
    location: LocationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    开始徒步：
    1. 更新用户状态 is_hiking = True
    2. 更新初始位置和时间
    """
    current_user.is_hiking = True
    current_user.current_lat = location.lat
    current_user.current_lng = location.lng
    current_user.location_updated_at = int(time.time() * 1000)
    
    db.commit()
    return {"success": True, "message": "Hiking started"}

@router.post("/hiking/end")
def end_hiking(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    结束徒步：
    1. 更新用户状态 is_hiking = False
    2. 清除位置信息
    """
    current_user.is_hiking = False
    current_user.current_lat = None
    current_user.current_lng = None
    current_user.location_updated_at = None
    
    db.commit()
    return {"success": True, "message": "Hiking ended"}

@router.post("/users/heartbeat")
def heartbeat(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    心跳保活：
    更新 location_updated_at，防止被判定为离线
    """
    if current_user.is_hiking:
        current_user.location_updated_at = int(time.time() * 1000)
        db.commit()
    return {"success": True}

@router.post("/users/offline")
def user_offline(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    用户离线（App退出）：
    清除徒步状态
    """
    current_user.is_hiking = False
    current_user.current_lat = None
    current_user.current_lng = None
    current_user.location_updated_at = None
    db.commit()
    return {"success": True}

# -----------------------------------------------------------------------------
# 2. 位置更新与周围用户查询
# -----------------------------------------------------------------------------

def calculate_distance(lat1, lon1, lat2, lon2):
    """
    Haversine formula to calculate distance between two points in km
    """
    R = 6371  # Earth radius in km
    dLat = math.radians(lat2 - lat1)
    dLon = math.radians(lon2 - lon1)
    a = math.sin(dLat/2) * math.sin(dLat/2) + \
        math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * \
        math.sin(dLon/2) * math.sin(dLon/2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

@router.post("/users/location")
def update_location(
    location: LocationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    更新位置并返回周围用户
    """
    # 1. 更新当前用户位置
    current_user.current_lat = location.lat
    current_user.current_lng = location.lng
    current_user.location_updated_at = int(time.time() * 1000)
    current_user.is_hiking = True # 确保状态正确
    db.commit()
    
    # 2. 查询周围用户
    # 逻辑：
    # - 排除自己
    # - 对方正在徒步 (is_hiking=True)
    # - 对方开启了地图可见 (visible_on_map=True)
    # - 距离 <= 10km
    # - 距离 <= 对方的可见范围 (visible_range)
    
    # 获取所有潜在的附近用户（简单起见，这里先获取所有正在徒步的用户，然后在内存中过滤距离）
    # 生产环境应使用PostGIS或数据库空间索引
    
    active_users = db.query(User).filter(
        User.id != current_user.id,
        User.is_hiking == True,
        User.visible_on_map == True,
        User.current_lat != None,
        User.current_lng != None
    ).all()
    
    nearby_users = []
    for user in active_users:
        dist = calculate_distance(location.lat, location.lng, user.current_lat, user.current_lng)
        
        # 判定条件：距离 <= 10km 且 距离 <= 对方设定的可见范围
        if dist <= 10.0 and dist <= user.visible_range:
            nearby_users.append({
                "id": user.id,
                "nickname": user.nickname,
                "avatar": user.avatar,
                "lat": user.current_lat,
                "lng": user.current_lng,
                "distance": round(dist, 2),
                "visible_range": user.visible_range
            })
            
    # 按距离排序
    nearby_users.sort(key=lambda x: x["distance"])
    
    return {
        "success": True,
        "nearbyUsers": nearby_users
    }

# -----------------------------------------------------------------------------
# 3. 隐私设置
# -----------------------------------------------------------------------------

@router.get("/users/privacy-settings")
def get_privacy_settings(current_user: User = Depends(get_current_user)):
    return {
        "visible_on_map": current_user.visible_on_map,
        "visible_range": current_user.visible_range,
        "receive_sos": current_user.receive_sos,
        "receive_questions": current_user.receive_questions,
        "receive_feedback": current_user.receive_feedback
    }

@router.put("/users/privacy-settings")
def update_privacy_settings(
    settings: PrivacySettingsUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if settings.visible_on_map is not None:
        current_user.visible_on_map = settings.visible_on_map
    if settings.visible_range is not None:
        current_user.visible_range = settings.visible_range
    if settings.receive_sos is not None:
        current_user.receive_sos = settings.receive_sos
    if settings.receive_questions is not None:
        current_user.receive_questions = settings.receive_questions
    if settings.receive_feedback is not None:
        current_user.receive_feedback = settings.receive_feedback
        
    db.commit()
    return {"success": True}

# -----------------------------------------------------------------------------
# 4. 原有的徒步记录接口
# -----------------------------------------------------------------------------

@router.post("/upload/snapshot")
async def upload_snapshot(file: UploadFile = File(...)):
    try:
        upload_dir = "uploads/snapshots"
        os.makedirs(upload_dir, exist_ok=True)
        timestamp = int(datetime.now().timestamp())
        filename = f"snapshot_{timestamp}_{file.filename}"
        file_path = os.path.join(upload_dir, filename)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        return {"url": f"/uploads/snapshots/{filename}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/upload/sos-photo")
async def upload_sos_photo(file: UploadFile = File(...)):
    """
    上传 SOS 现场照片，返回可公开访问的 URL。
    """
    try:
        upload_dir = "uploads/sos_photos"
        os.makedirs(upload_dir, exist_ok=True)

        timestamp = int(datetime.now().timestamp())
        filename = f"sos_{timestamp}_{file.filename}"
        file_path = os.path.join(upload_dir, filename)

        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        return {"url": f"/uploads/sos_photos/{filename}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/hiking-records", response_model=HikingRecordOut)
def create_hiking_record(
    record: HikingRecordCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    # ... existing code ...
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
    # ... existing code ...
    # Filter by user_id if provided, otherwise use current user
    target_user_id = user_id if user_id else current_user.id
    if target_user_id != current_user.id:
        pass 
        target_user_id = current_user.id

    query = db.query(HikingRecord).filter(HikingRecord.user_id == target_user_id)
    total_count = query.count()
    records = query.order_by(HikingRecord.start_time.desc()).offset(skip).limit(limit).all()
    
    # Calculate aggregates
    all_records = db.query(HikingRecord).filter(HikingRecord.user_id == target_user_id).all()
    total_distance_all = sum(r.distance for r in all_records)
    total_elevation_gain_all = sum(r.elevation_gain for r in all_records)
    
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
