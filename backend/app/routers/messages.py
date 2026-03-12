from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, aliased
from typing import List, Optional
from app.database.database import get_db
from app.models.message import Feedback, Message, SOSAlert
from app.routers.auth import get_current_user
from app.models.user import User
from pydantic import BaseModel
import time
import json

router = APIRouter()

# --- Message Models ---

class MessageCreate(BaseModel):
    receiver_id: int
    content: str
    type: str = "text" # text, image, sos
    hike_id: Optional[int] = None

class MessageOut(BaseModel):
    id: int
    sender_id: int
    receiver_id: Optional[int]
    content: str
    type: str
    timestamp: int
    is_read: bool = False
    hike_id: Optional[int] = None
    sender_hike_id: Optional[int] = None
    receiver_hike_id: Optional[int] = None
    
    class Config:
        from_attributes = True

class MarkReadRequest(BaseModel):
    message_ids: List[int]

class MessageAssociateRequest(BaseModel):
    hike_id: int
    start_time: int
    end_time: int

# --- Feedback Models ---

class FeedbackCreate(BaseModel):
    type: str
    content: str
    latitude: float
    longitude: float
    address: str
    photos: Optional[List[str]] = None
    created_at: int

class FeedbackOut(FeedbackCreate):
    id: int
    user_id: int
    user_name: Optional[str] = None
    status: str
    view_count: int
    confirm_count: int
    photos: Optional[List[str]] = None
    
    class Config:
        from_attributes = True

# --- Message Endpoints ---

import math

# ... existing code ...

class AskQuestionRequest(BaseModel):
    content: str
    latitude: float
    longitude: float

class QuestionBroadcastOut(BaseModel):
    question_messages: List[MessageOut]
    recipient_count: int

# ... existing code ...

def calculate_distance(lat1, lon1, lat2, lon2):
    """
    Haversine formula to calculate distance between two points in km
    Reuse from hiking.py or duplicate here to avoid circular imports if hiking imports messages
    """
    R = 6371  # Earth radius in km
    dLat = math.radians(lat2 - lat1)
    dLon = math.radians(lon2 - lon1)
    a = math.sin(dLat/2) * math.sin(dLat/2) + \
        math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * \
        math.sin(dLon/2) * math.sin(dLon/2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

@router.post("/messages/ask", response_model=QuestionBroadcastOut)
def ask_question(
    req: AskQuestionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    向周围人提问接口
    逻辑：
    1. 寻找10km内最近的3个活跃用户（is_hiking=True）
    2. 如果活跃用户不足3个，则补充寻找历史用户（最近发过路况或求助的）
       - 范围：10km
       - 排序：按发布时间倒序
       - 数量：5个
    3. 给所有目标用户发送消息（类型为 'question'）
    """
    
    targets = {} # user_id -> User object
    
    # 1. Find Active Users (10km，全局上限)，同时尊重对方的「接收提问」与可见范围设置
    active_users = db.query(User).filter(
        User.id != current_user.id,
        User.is_hiking == True,
        User.current_lat != None,
        User.current_lng != None,
        User.receive_questions == True,
        User.visible_on_map == True,
    ).all()
    
    active_candidates = []
    for user in active_users:
        dist = calculate_distance(req.latitude, req.longitude, user.current_lat, user.current_lng)
        # 每个用户有自己的 visible_range（公里），再与全局 10km 上限取较小值
        max_range_km = float(user.visible_range or 10)
        effective_range = min(10.0, max_range_km)
        if dist <= effective_range:
            active_candidates.append((dist, user))
            
    # Sort by distance and take top 3
    active_candidates.sort(key=lambda x: x[0])
    top_active = active_candidates[:3]
    
    for _, user in top_active:
        targets[user.id] = user
        
    # 2. If fewer than 3, find historical contributors
    if len(targets) < 3:
        # Find users from Feedbacks
        recent_feedbacks = db.query(Feedback).filter(
            Feedback.user_id != current_user.id,
            Feedback.latitude >= req.latitude - 0.1, # Approx 10km box optimization
            Feedback.latitude <= req.latitude + 0.1,
            Feedback.longitude >= req.longitude - 0.1,
            Feedback.longitude <= req.longitude + 0.1
        ).order_by(Feedback.created_at.desc()).limit(20).all()
        
        # Find users from SOS
        recent_sos = db.query(SOSAlert).filter(
            SOSAlert.user_id != current_user.id,
            SOSAlert.latitude >= req.latitude - 0.1,
            SOSAlert.latitude <= req.latitude + 0.1,
            SOSAlert.longitude >= req.longitude - 0.1,
            SOSAlert.longitude <= req.longitude + 0.1
        ).order_by(SOSAlert.created_at.desc()).limit(20).all()
        
        # Merge and check precise distance
        historical_candidates = []
        seen_users = set()
        
        # Helper to process historical items
        def process_items(items):
            for item in items:
                if item.user_id in targets or item.user_id in seen_users:
                    continue
                
                # Check real distance
                dist = calculate_distance(req.latitude, req.longitude, item.latitude, item.longitude)
                if dist <= 10.0:
                    seen_users.add(item.user_id)
                    historical_candidates.append({
                        'user_id': item.user_id,
                        'time': item.created_at,
                        'dist': dist
                    })
        
        process_items(recent_feedbacks)
        process_items(recent_sos)
        
        # Sort by time desc
        historical_candidates.sort(key=lambda x: x['time'], reverse=True)
        
        # Take top 5
        top_historical = historical_candidates[:5]
        
        for cand in top_historical:
            # 历史用户同样需要尊重「接收提问」与可见范围
            user = db.query(User).filter(
                User.id == cand['user_id'],
                User.receive_questions == True,
                User.visible_on_map == True,
                User.current_lat != None,
                User.current_lng != None,
            ).first()
            if not user:
                continue
            max_range_km = float(user.visible_range or 10)
            effective_range = min(10.0, max_range_km)
            if cand['dist'] <= effective_range:
                targets[user.id] = user

    # 3. Create Messages
    created_messages = []
    timestamp = int(time.time() * 1000)
    
    for target_id, target_user in targets.items():
        msg = Message(
            sender_id=current_user.id,
            receiver_id=target_id,
            content=req.content,
            type='question', # Special type
            timestamp=timestamp,
            is_read=False
        )
        db.add(msg)
        created_messages.append(msg)
        
    db.commit()
    
    # Refresh to get IDs
    for msg in created_messages:
        db.refresh(msg)
        
    return {
        "question_messages": created_messages,
        "recipient_count": len(created_messages)
    }

@router.post("/messages", response_model=MessageOut)
def send_message(
    msg: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Verify receiver exists
    receiver = db.query(User).filter(User.id == msg.receiver_id).first()
    if not receiver:
        raise HTTPException(status_code=404, detail="Receiver not found")
        
    db_msg = Message(
        sender_id=current_user.id,
        receiver_id=msg.receiver_id,
        content=msg.content,
        type=msg.type,
        timestamp=int(time.time() * 1000),
        is_read=False,
        hike_id=msg.hike_id
    )
    db.add(db_msg)
    db.commit()
    db.refresh(db_msg)
    return db_msg

@router.get("/messages", response_model=List[MessageOut])
def get_messages(
    since: Optional[int] = None,
    partner_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Message).filter(
        (Message.sender_id == current_user.id) | (Message.receiver_id == current_user.id)
    )
    
    if partner_id:
        query = query.filter(
            ((Message.sender_id == current_user.id) & (Message.receiver_id == partner_id)) |
            ((Message.sender_id == partner_id) & (Message.receiver_id == current_user.id))
        )
        
    if since:
        query = query.filter(Message.timestamp > since)
        
    return query.order_by(Message.timestamp.asc()).all()

@router.get("/messages/conversations")
def get_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Get last message for each conversation
    # This is a bit complex in pure SQL, simpler to fetch recent messages and aggregate in python for MVP
    # Or find all unique partners
    
    sent_to = db.query(Message.receiver_id).filter(Message.sender_id == current_user.id).distinct()
    received_from = db.query(Message.sender_id).filter(Message.receiver_id == current_user.id).distinct()
    
    partner_ids = set()
    for (pid,) in sent_to:
        if pid is not None: partner_ids.add(pid)
    for (pid,) in received_from:
        if pid is not None: partner_ids.add(pid)
        
    conversations = []
    for pid in partner_ids:
        if pid == 0:
            # Special case for broadcast/SOS
            last_msg = db.query(Message).filter(
                Message.sender_id == current_user.id,
                Message.receiver_id == 0
            ).order_by(Message.timestamp.desc()).first()
            
            if last_msg:
                conversations.append({
                    "partner": {
                        "id": 0,
                        "nickname": "所有人 (SOS广播)",
                        "avatar": None
                    },
                    "last_message": {
                        "content": last_msg.content,
                        "type": last_msg.type,
                        "timestamp": last_msg.timestamp
                    },
                    "unread_count": 0
                })
            continue

        partner = db.query(User).filter(User.id == pid).first()
        if not partner: continue
        
        last_msg = db.query(Message).filter(
            ((Message.sender_id == current_user.id) & (Message.receiver_id == pid)) |
            ((Message.sender_id == pid) & (Message.receiver_id == current_user.id))
        ).order_by(Message.timestamp.desc()).first()
        
        unread_count = db.query(Message).filter(
            Message.sender_id == pid,
            Message.receiver_id == current_user.id,
            Message.is_read == False
        ).count()
        
        conversations.append({
            "partner": {
                "id": partner.id,
                "nickname": partner.nickname,
                "avatar": partner.avatar
            },
            "last_message": {
                "content": last_msg.content,
                "type": last_msg.type,
                "timestamp": last_msg.timestamp
            } if last_msg else None,
            "unread_count": unread_count
        })
        
    # Sort by last message timestamp
    conversations.sort(key=lambda x: x["last_message"]["timestamp"] if x["last_message"] else 0, reverse=True)
    return conversations

@router.post("/messages/mark-read")
def mark_messages_read(
    req: MarkReadRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db.query(Message).filter(
        Message.id.in_(req.message_ids),
        Message.receiver_id == current_user.id
    ).update({"is_read": True}, synchronize_session=False)
    db.commit()
    return {"success": True}

@router.post("/messages/associate")
def associate_messages(
    req: MessageAssociateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    将用户在指定时间段内产生的所有消息关联到某个徒步记录 hike_id
    """
    # 1. Update sender_hike_id where current user is the sender
    sender_updated = db.query(Message).filter(
        Message.sender_id == current_user.id,
        Message.timestamp >= req.start_time,
        Message.timestamp <= req.end_time
    ).update({"sender_hike_id": req.hike_id}, synchronize_session=False)
    
    # 2. Update receiver_hike_id where current user is the receiver
    receiver_updated = db.query(Message).filter(
        Message.receiver_id == current_user.id,
        Message.timestamp >= req.start_time,
        Message.timestamp <= req.end_time
    ).update({"receiver_hike_id": req.hike_id}, synchronize_session=False)
    
    db.commit()
    return {"success": True, "updated_count": sender_updated + receiver_updated}

# --- SOS Models ---
class SOSRecipient(BaseModel):
    id: int
    nickname: Optional[str] = None


class SOSOut(BaseModel):
    id: int
    user_id: int
    user_name: Optional[str] = None
    latitude: float
    longitude: float
    message: str
    status: str
    created_at: int
    resolved_at: Optional[int]
    # 本次 SOS 实际广播到的用户（用于前端展示“已发送给 n 位用户：A、B、C”）
    recipients: Optional[List[SOSRecipient]] = None
    photos: Optional[List[str]] = None
    
    class Config:
        from_attributes = True

class SOSCreate(BaseModel):
    latitude: float
    longitude: float
    message: str
    photos: Optional[List[str]] = None

# --- SOS Endpoints (Placeholder for now, usually part of hiking or separate router, but putting here for map query) ---

@router.post("/messages/sos", response_model=SOSOut)
def create_sos(
    sos: SOSCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    创建 SOS 记录并向周围用户广播。

    注意：作为“中心点”的坐标优先使用 users 表中 current_user 的 current_lat/current_lng，
    这样即使前端没有传经纬度（或传了 0,0），仍然可以用服务器端已保存的位置来做距离判断；
    只有在 current_lat/current_lng 为空的情况下，才退回到使用 body 里的 sos.latitude/longitude。
    """
    center_lat = current_user.current_lat if current_user.current_lat is not None else sos.latitude
    center_lng = current_user.current_lng if current_user.current_lng is not None else sos.longitude

    # 1. Create SOS Alert Record（也使用 center_lat/center_lng 作为本次 SOS 的坐标）
    db_sos = SOSAlert(
        user_id=current_user.id,
        latitude=center_lat,
        longitude=center_lng,
        message=sos.message,
        photos=json.dumps(sos.photos) if sos.photos else None,
        status='ACTIVE',
        created_at=int(time.time() * 1000)
    )
    db.add(db_sos)
    db.commit()
    db.refresh(db_sos)
    
    # 2. Find nearby users to broadcast SOS (10km -> 50km)
    targets = {}
    
    # Strategy:
    # - First try 10km (3 users)
    # - If < 3, try 50km (fill up to 3 users)
    
    def find_targets(radius_km, limit, exclude_ids):
        """
        按距离和开关来筛选 SOS 接收者，并打印详细日志，方便排查“为什么某个用户没有被选中”。

        逻辑：
        1. 从 users 中选出：不是自己、不在排除列表、开启 receive_sos，且有合法坐标的用户；
        2. 计算与 SOS 位置的真实球面距离；
        3. 距离 <= radius_km 的才视为候选；
        4. 按距离排序后取前 limit 个。

        之前的基于经纬度 bounding box 的粗滤逻辑保留在下面（已注释），需要时可以恢复。
        """
        # 打印当前 SOS 位置，方便确认是不是 0,0 或者异常值
        print(f"[SOS] create_sos: center=({center_lat}, {center_lng}), radius={radius_km}km, exclude_ids={exclude_ids}")

        # 1. 先按开关/坐标做第一步过滤
        users = db.query(User).filter(
            User.id != current_user.id,
            User.id.notin_(exclude_ids),
            User.receive_sos == True,
            User.current_lat != None,
            User.current_lng != None,
        ).all()

        candidates = []
        for u in users:
            # 与中心点（当前用户 last known 位置）计算实际距离
            dist = calculate_distance(center_lat, center_lng, u.current_lat, u.current_lng)
            within = dist <= radius_km
            print(
                f"[SOS] candidate user_id={u.id}, nickname={u.nickname}, "
                f"loc=({u.current_lat}, {u.current_lng}), dist={dist:.3f}km, "
                f"receive_sos={u.receive_sos}, is_hiking={u.is_hiking}, within_radius={within}"
            )
            if within:
                candidates.append((dist, u))

        # 按距离排序并截断
        candidates.sort(key=lambda x: x[0])
        print(f"[SOS] total within {radius_km}km: {len(candidates)} (from {len(users)} users)")
        return candidates[:limit]

        # ---- 旧的基于 bounding box 的粗滤逻辑（保留注释，方便以后恢复/对比） ----
        # delta = radius_km / 111.0 
        # users = db.query(User).filter(
        #     User.id != current_user.id,
        #     User.id.notin_(exclude_ids),
        #     User.receive_sos == True,
        #     User.current_lat >= sos.latitude - delta,
        #     User.current_lat <= sos.latitude + delta,
        #     User.current_lng >= sos.longitude - delta,
        #     User.current_lng <= sos.longitude + delta
        # ).all()
        # candidates = []
        # for u in users:
        #     if u.current_lat and u.current_lng:
        #         dist = calculate_distance(sos.latitude, sos.longitude, u.current_lat, u.current_lng)
        #         if dist <= radius_km:
        #             candidates.append((dist, u))
        # candidates.sort(key=lambda x: x[0])
        # return candidates[:limit]

    # Step 2a: 10km search
    nearby_10km = find_targets(10.0, 3, [])
    for _, u in nearby_10km:
        targets[u.id] = u
        
    # Step 2b: If needed, 50km search
    if len(targets) < 3:
        needed = 3 - len(targets)
        nearby_50km = find_targets(50.0, needed, list(targets.keys()))
        for _, u in nearby_50km:
            targets[u.id] = u
            
    # 3. Always create a broadcast message for the sender to see in their message center
    timestamp = int(time.time() * 1000)
    broadcast_msg = Message(
        sender_id=current_user.id,
        receiver_id=0, # 0 means broadcast or everyone
        content=sos.message,
        type='sos',
        timestamp=timestamp,
        is_read=True # Mark as read for the sender
    )
    db.add(broadcast_msg)

    # 4. Send SOS Message to targets
    for target_id in targets:
        # Create message for receiver
        msg_to_target = Message(
            sender_id=current_user.id,
            receiver_id=target_id,
            content=sos.message,  # Contains full JSON or formatted text
            type='sos',  # Special type for card rendering
            timestamp=timestamp,
            is_read=False,
        )
        db.add(msg_to_target)
        
    db.commit()
    
    # 准备返回给前端的接收者列表信息
    recipient_list = [
        SOSRecipient(id=u.id, nickname=u.nickname) for u in targets.values()
    ]
    
    out = SOSOut.from_orm(db_sos)
    out.user_name = current_user.nickname
    out.recipients = recipient_list
    out.photos = sos.photos or []
    return out

@router.get("/messages/sos", response_model=List[SOSOut])
def get_sos_in_bounds(
    min_lat: float,
    max_lat: float,
    min_lng: float,
    max_lng: float,
    db: Session = Depends(get_db)
):
    query = db.query(SOSAlert).filter(
        SOSAlert.latitude >= min_lat,
        SOSAlert.latitude <= max_lat,
        SOSAlert.longitude >= min_lng,
        SOSAlert.longitude <= max_lng,
        SOSAlert.status == 'ACTIVE'
    )
    alerts = query.all()
    results = []
    for a in alerts:
        out = SOSOut.from_orm(a)
        if a.user:
            out.user_name = a.user.nickname
        results.append(out)
    return results

def create_feedback(
    feedback: FeedbackCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    feedback_dict = feedback.dict()
    # Convert list of photos to JSON string if needed, or store as is if DB handles it (sqlite doesn't handle lists natively)
    # But wait, Pydantic handles validation. SQLAlchemy needs a string for TEXT column.
    import json # already imported at top
    if feedback.photos:
        feedback_dict['photos'] = json.dumps(feedback.photos)
    
    db_feedback = Feedback(**feedback_dict, user_id=current_user.id)
    db.add(db_feedback)
    db.commit()
    db.refresh(db_feedback)

    # Convert photos back to list for response if needed, 
    # but Pydantic's from_attributes might struggle if the attribute on db_feedback is a JSON string
    # while the model expects a list.
    # We should manually patch it or use a property.
    # Let's simple reload or patch.
    if db_feedback.photos and isinstance(db_feedback.photos, str):
        try:
            db_feedback.photos = json.loads(db_feedback.photos)
        except:
            db_feedback.photos = []
            
    out = FeedbackOut.from_orm(db_feedback)
    out.user_name = current_user.nickname
    return out

@router.post("/messages/feedback", response_model=FeedbackOut)
def create_feedback_endpoint(
    feedback: FeedbackCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    return create_feedback(feedback, db, current_user)

@router.get("/messages/feedbacks", response_model=List[FeedbackOut])
def get_feedbacks_in_bounds(
    min_lat: float,
    max_lat: float,
    min_lng: float,
    max_lng: float,
    days: Optional[int] = None,
    min_confirms: Optional[int] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Feedback).filter(
        Feedback.latitude >= min_lat,
        Feedback.latitude <= max_lat,
        Feedback.longitude >= min_lng,
        Feedback.longitude <= max_lng,
        Feedback.status == 'ACTIVE'
    )
    
    if days:
        cutoff = int((time.time() - days * 86400) * 1000)
        query = query.filter(Feedback.created_at >= cutoff)
        
    if min_confirms:
        query = query.filter(Feedback.confirm_count >= min_confirms)
        
    feedbacks = query.all()
    results = []
    
    # Manual conversion of photos from JSON string to list
    for f in feedbacks:
        if f.photos and isinstance(f.photos, str):
            try:
                f.photos = json.loads(f.photos)
            except:
                f.photos = []
        
        out = FeedbackOut.from_orm(f)
        if f.user:
            out.user_name = f.user.nickname
        results.append(out)
            
    return results

@router.get("/messages/feedback/my", response_model=List[FeedbackOut])
def get_my_feedbacks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    feedbacks = db.query(Feedback).filter(Feedback.user_id == current_user.id).all()
    results = []
    # Manual conversion of photos from JSON string to list
    for f in feedbacks:
        if f.photos and isinstance(f.photos, str):
            try:
                f.photos = json.loads(f.photos)
            except:
                f.photos = []
        
        out = FeedbackOut.from_orm(f)
        out.user_name = current_user.nickname
        results.append(out)
            
    return results
