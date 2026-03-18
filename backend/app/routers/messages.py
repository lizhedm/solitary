from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, aliased
from typing import List, Optional
from app.database.database import get_db
from app.models.message import Feedback, Message, SOSAlert, FriendMessage, FeedbackConfirm, FeedbackComment
from app.models.friendship import Friendship
from app.routers.auth import get_current_user
from app.models.user import User
from pydantic import BaseModel
import time
import json
import os
import requests

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


# --- FriendMessage Models (好友间消息，仅存成为好友后的对话) ---

class FriendMessageCreate(BaseModel):
    receiver_id: int
    content: str
    type: str = "text"  # text, image, emoji
    attachment_url: Optional[str] = None

class FriendMessageOut(BaseModel):
    id: int
    sender_id: int
    receiver_id: int
    content: str
    type: str
    attachment_url: Optional[str] = None
    timestamp: int
    is_read: bool = False

    class Config:
        from_attributes = True

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
    user_avatar: Optional[str] = None
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


def _are_friends(db: Session, user_id: int, other_id: int) -> bool:
    return db.query(Friendship).filter(
        ((Friendship.user_id == user_id) & (Friendship.friend_id == other_id)) |
        ((Friendship.user_id == other_id) & (Friendship.friend_id == user_id)),
        Friendship.status == "ACCEPTED"
    ).first() is not None


@router.post("/friend-messages", response_model=FriendMessageOut)
def send_friend_message(
    msg: FriendMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """发送好友消息：仅当两人已是好友时写入 friend_messages 表。"""
    receiver = db.query(User).filter(User.id == msg.receiver_id).first()
    if not receiver:
        raise HTTPException(status_code=404, detail="Receiver not found")
    if not _are_friends(db, current_user.id, msg.receiver_id):
        raise HTTPException(status_code=403, detail="Only friends can send friend messages")
    db_msg = FriendMessage(
        sender_id=current_user.id,
        receiver_id=msg.receiver_id,
        content=msg.content,
        type=msg.type or "text",
        attachment_url=msg.attachment_url,
        timestamp=int(time.time() * 1000),
        is_read=False,
    )
    db.add(db_msg)
    db.commit()
    db.refresh(db_msg)
    return db_msg


@router.get("/friend-messages", response_model=List[FriendMessageOut])
def get_friend_messages(
    partner_id: Optional[int] = Query(None),
    since: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """拉取好友消息：无 partner_id 时返回当前用户所有好友消息；有 partner_id 时仅返回与该好友的对话，且校验好友关系。"""
    query = db.query(FriendMessage).filter(
        (FriendMessage.sender_id == current_user.id) | (FriendMessage.receiver_id == current_user.id)
    )
    if partner_id is not None:
        if not _are_friends(db, current_user.id, partner_id):
            return []
        query = query.filter(
            ((FriendMessage.sender_id == current_user.id) & (FriendMessage.receiver_id == partner_id)) |
            ((FriendMessage.sender_id == partner_id) & (FriendMessage.receiver_id == current_user.id))
        )
    if since is not None:
        query = query.filter(FriendMessage.timestamp > since)
    return query.order_by(FriendMessage.timestamp.asc()).all()


@router.post("/friend-messages/mark-read")
def mark_friend_messages_read(
    req: MarkReadRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db.query(FriendMessage).filter(
        FriendMessage.id.in_(req.message_ids),
        FriendMessage.receiver_id == current_user.id
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

    # 将 DB 中的 photos(JSON字符串) 转为 List[str]
    photos_list: list[str] = []
    if db_sos.photos and isinstance(db_sos.photos, str):
        try:
            decoded = json.loads(db_sos.photos)
            if isinstance(decoded, list):
                photos_list = [str(x) for x in decoded]
        except Exception:
            photos_list = []

    # 手动构造 SOSOut，避免 from_orm 把 photos 字符串直接塞进 List[str]
    out = SOSOut(
        id=db_sos.id,
        user_id=db_sos.user_id,
        user_name=current_user.nickname,
        latitude=db_sos.latitude,
        longitude=db_sos.longitude,
        message=db_sos.message,
        status=db_sos.status,
        created_at=db_sos.created_at,
        resolved_at=db_sos.resolved_at,
        recipients=recipient_list,
        photos=photos_list,
    )
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
    results: list[SOSOut] = []
    for a in alerts:
        photos_list: list[str] = []
        if a.photos and isinstance(a.photos, str):
            try:
                decoded = json.loads(a.photos)
                if isinstance(decoded, list):
                    photos_list = [str(x) for x in decoded]
            except Exception:
                photos_list = []

        out = SOSOut(
            id=a.id,
            user_id=a.user_id,
            user_name=a.user.nickname if a.user else None,
            latitude=a.latitude,
            longitude=a.longitude,
            message=a.message,
            status=a.status,
            created_at=a.created_at,
            resolved_at=a.resolved_at,
            recipients=None,
            photos=photos_list,
        )
        results.append(out)
    return results


# --- 高德逆地理编码（ReGeocoding） ---

AMAP_REST_KEY = os.getenv("AMAP_REST_KEY")


class RegeoResult(BaseModel):
    formatted_address: str
    province: Optional[str] = None
    city: Optional[str] = None
    district: Optional[str] = None
    township: Optional[str] = None


@router.get("/geo/regeo", response_model=RegeoResult)
def gaode_reverse_geocode(
    lat: float,
    lng: float,
):
    """
    使用高德 Web 服务进行逆地理编码，将经纬度转换为位置名称。

    返回的数据中，formatted_address 即完整地址，如：
    "上海市浦东新区世纪大道1号"
    """
    if not AMAP_REST_KEY:
        raise HTTPException(status_code=500, detail="AMAP_REST_KEY is not configured on server")

    try:
        resp = requests.get(
            "https://restapi.amap.com/v3/geocode/regeo",
            params={
                "key": AMAP_REST_KEY,
                "location": f"{lng},{lat}",  # 高德要求先经度后纬度
                "radius": 1000,
                "extensions": "base",
                "batch": "false",
            },
            timeout=5,
        )
    except requests.RequestException as e:
        raise HTTPException(status_code=502, detail=f"Regeo request failed: {e}")

    if resp.status_code != 200:
        raise HTTPException(status_code=502, detail=f"Regeo HTTP {resp.status_code}")

    data = resp.json()
    if data.get("status") != "1":
        raise HTTPException(status_code=400, detail=data.get("info", "Regeo failed"))

    regeocode = data.get("regeocode") or {}
    formatted = regeocode.get("formatted_address") or ""
    comp = regeocode.get("addressComponent") or {}

    province = comp.get("province") or None
    city = None
    if isinstance(comp.get("city"), list):
        if comp["city"]:
            city = comp["city"][0]
    else:
        city = comp.get("city") or None
    district = comp.get("district") or None
    township = comp.get("township") or None

    return RegeoResult(
        formatted_address=formatted,
        province=province,
        city=city,
        district=district,
        township=township,
    )


# --- Feedback view / confirm / comments ---


class FeedbackCommentCreate(BaseModel):
    content: str


class FeedbackCommentOut(BaseModel):
    id: int
    user_id: int
    user_name: Optional[str] = None
    user_avatar: Optional[str] = None
    content: str
    created_at: int

    class Config:
        from_attributes = True


@router.post("/messages/feedback/{feedback_id}/view")
def mark_feedback_viewed(
    feedback_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    fb = db.query(Feedback).filter(Feedback.id == feedback_id).first()
    if not fb:
        raise HTTPException(status_code=404, detail="Feedback not found")
    fb.view_count = (fb.view_count or 0) + 1
    db.commit()
    return {"view_count": fb.view_count}


@router.post("/messages/feedback/{feedback_id}/confirm")
def confirm_feedback(
    feedback_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    fb = db.query(Feedback).filter(Feedback.id == feedback_id).first()
    if not fb:
        raise HTTPException(status_code=404, detail="Feedback not found")

    existing = (
        db.query(FeedbackConfirm)
        .filter(
            FeedbackConfirm.feedback_id == feedback_id,
            FeedbackConfirm.user_id == current_user.id,
        )
        .first()
    )
    if existing:
        return {
            "confirmed": True,
            "confirm_count": fb.confirm_count,
        }

    now_ms = int(time.time() * 1000)
    conf = FeedbackConfirm(
        feedback_id=feedback_id,
        user_id=current_user.id,
        created_at=now_ms,
    )
    db.add(conf)
    fb.confirm_count = (fb.confirm_count or 0) + 1
    db.commit()
    return {
        "confirmed": True,
        "confirm_count": fb.confirm_count,
    }


@router.get("/messages/feedback/{feedback_id}/confirm-status")
def get_feedback_confirm_status(
    feedback_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    fb = db.query(Feedback).filter(Feedback.id == feedback_id).first()
    if not fb:
        raise HTTPException(status_code=404, detail="Feedback not found")

    existing = (
        db.query(FeedbackConfirm)
        .filter(
            FeedbackConfirm.feedback_id == feedback_id,
            FeedbackConfirm.user_id == current_user.id,
        )
        .first()
    )
    return {
        "confirmed": existing is not None,
        "confirm_count": fb.confirm_count,
    }


@router.get("/messages/feedback/{feedback_id}/comments", response_model=List[FeedbackCommentOut])
def get_feedback_comments(
    feedback_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    comments = (
        db.query(FeedbackComment)
        .filter(FeedbackComment.feedback_id == feedback_id)
        .order_by(FeedbackComment.created_at.desc())
        .all()
    )
    results: list[FeedbackCommentOut] = []
    for c in comments:
        out = FeedbackCommentOut.from_orm(c)
        if c.user:
            out.user_name = c.user.nickname
            out.user_avatar = c.user.avatar
        results.append(out)
    return results


@router.post("/messages/feedback/{feedback_id}/comments", response_model=FeedbackCommentOut)
def add_feedback_comment(
    feedback_id: int,
    comment: FeedbackCommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    fb = db.query(Feedback).filter(Feedback.id == feedback_id).first()
    if not fb:
        raise HTTPException(status_code=404, detail="Feedback not found")

    now_ms = int(time.time() * 1000)
    db_comment = FeedbackComment(
        feedback_id=feedback_id,
        user_id=current_user.id,
        content=comment.content,
        created_at=now_ms,
    )
    db.add(db_comment)
    db.commit()
    db.refresh(db_comment)

    out = FeedbackCommentOut.from_orm(db_comment)
    out.user_name = current_user.nickname
    out.user_avatar = current_user.avatar
    return out

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
    out.user_avatar = current_user.avatar
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
            out.user_avatar = f.user.avatar
        results.append(out)
            
    return results

@router.get("/messages/feedbacks/{feedback_id}", response_model=FeedbackOut)
def get_feedback(
    feedback_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    f = db.query(Feedback).filter(Feedback.id == feedback_id).first()
    if not f:
        raise HTTPException(status_code=404, detail="Feedback not found")
        
    if f.photos and isinstance(f.photos, str):
        try:
            f.photos = json.loads(f.photos)
        except:
            f.photos = []
            
    out = FeedbackOut.from_orm(f)
    if f.user:
        out.user_name = f.user.nickname
        out.user_avatar = f.user.avatar
    return out

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
        out.user_avatar = current_user.avatar
        results.append(out)
            
    return results
