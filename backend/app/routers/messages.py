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
    is_read: bool
    hike_id: Optional[int]
    
    class Config:
        from_attributes = True

class MarkReadRequest(BaseModel):
    message_ids: List[int]

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
    status: str
    view_count: int
    confirm_count: int
    photos: Optional[List[str]] = None
    
    class Config:
        from_attributes = True

# --- Message Endpoints ---

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
        if pid: partner_ids.add(pid)
    for (pid,) in received_from:
        if pid: partner_ids.add(pid)
        
    conversations = []
    for pid in partner_ids:
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

# --- SOS Models ---
class SOSOut(BaseModel):
    id: int
    user_id: int
    latitude: float
    longitude: float
    message: str
    status: str
    created_at: int
    resolved_at: Optional[int]
    
    class Config:
        from_attributes = True

class SOSCreate(BaseModel):
    latitude: float
    longitude: float
    message: str

# --- SOS Endpoints (Placeholder for now, usually part of hiking or separate router, but putting here for map query) ---

@router.post("/messages/sos", response_model=SOSOut)
def create_sos(
    sos: SOSCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db_sos = SOSAlert(
        user_id=current_user.id,
        latitude=sos.latitude,
        longitude=sos.longitude,
        message=sos.message,
        status='ACTIVE',
        created_at=int(time.time() * 1000)
    )
    db.add(db_sos)
    db.commit()
    db.refresh(db_sos)
    return db_sos

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
    return query.all()

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
    return db_feedback

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
    
    # Manual conversion of photos from JSON string to list
    for f in feedbacks:
        if f.photos and isinstance(f.photos, str):
            try:
                f.photos = json.loads(f.photos)
            except:
                f.photos = []
    return feedbacks

@router.get("/messages/feedback/my", response_model=List[FeedbackOut])
def get_my_feedbacks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    feedbacks = db.query(Feedback).filter(Feedback.user_id == current_user.id).all()
    # Manual conversion of photos from JSON string to list
    for f in feedbacks:
        if f.photos and isinstance(f.photos, str):
            try:
                f.photos = json.loads(f.photos)
            except:
                f.photos = []
    return feedbacks
