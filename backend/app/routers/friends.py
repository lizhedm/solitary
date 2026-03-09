from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.database.database import get_db
from app.models.friendship import Friendship
from app.models.user import User
from app.routers.auth import get_current_user
from pydantic import BaseModel
import time

router = APIRouter(
    tags=["friends"]
)

class UserOut(BaseModel):
    id: int
    nickname: str
    avatar: str | None
    
    class Config:
        from_attributes = True

@router.get("/friends", response_model=List[UserOut])
def get_friends(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Find all accepted friendships
    friends = []
    
    # Where current_user is initiator
    f1 = db.query(Friendship).filter(
        Friendship.user_id == current_user.id,
        Friendship.status == "ACCEPTED"
    ).all()
    
    for f in f1:
        if f.friend: friends.append(f.friend)
        
    # Where current_user is receiver
    f2 = db.query(Friendship).filter(
        Friendship.friend_id == current_user.id,
        Friendship.status == "ACCEPTED"
    ).all()
    
    for f in f2:
        if f.user: friends.append(f.user)
        
    return friends

@router.post("/friends/add/{user_id}")
def add_friend(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot add yourself")
        
    # Check if exists
    exists = db.query(Friendship).filter(
        ((Friendship.user_id == current_user.id) & (Friendship.friend_id == user_id)) |
        ((Friendship.user_id == user_id) & (Friendship.friend_id == current_user.id))
    ).first()
    
    if exists:
        return {"status": exists.status}
        
    # Create friendship (auto accept for testing)
    friendship = Friendship(
        user_id=current_user.id,
        friend_id=user_id,
        status="ACCEPTED",
        created_at=int(time.time() * 1000)
    )
    db.add(friendship)
    db.commit()
    return {"status": "ACCEPTED"}
