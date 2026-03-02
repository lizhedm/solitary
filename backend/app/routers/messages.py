from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.database.database import get_db
from app.models.message import Feedback, Message
from app.routers.auth import get_current_user
from app.models.user import User
from pydantic import BaseModel

router = APIRouter()

class FeedbackCreate(BaseModel):
    type: str
    content: str
    latitude: float
    longitude: float
    address: str
    created_at: int

class FeedbackOut(FeedbackCreate):
    id: int
    user_id: int
    status: str
    view_count: int
    confirm_count: int
    
    class Config:
        from_attributes = True

@router.post("/messages/feedback", response_model=FeedbackOut)
def create_feedback(
    feedback: FeedbackCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    db_feedback = Feedback(**feedback.dict(), user_id=current_user.id)
    db.add(db_feedback)
    db.commit()
    db.refresh(db_feedback)
    return db_feedback

@router.get("/messages/feedback/my", response_model=List[FeedbackOut])
def get_my_feedbacks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return db.query(Feedback).filter(Feedback.user_id == current_user.id).all()
