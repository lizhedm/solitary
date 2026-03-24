from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.database.database import get_db
from app.models.friendship import Friendship
from app.models.message import TempFriendship
from app.models.snap import Snap
from app.models.user import User
from app.routers.auth import get_current_user
from pydantic import BaseModel
import time

router = APIRouter()

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
        
    # Create friendship (PENDING for real scenario, but user asked to remove auto-friend logic?)
    # User said: "将之前写的将user1和user2设置为好友的逻辑去掉"
    # This might mean removing any hardcoded auto-friending in other places, or changing this back to pending.
    # Assuming user wants standard friend request flow:
    
    friendship = Friendship(
        user_id=current_user.id,
        friend_id=user_id,
        status="PENDING",
        created_at=int(time.time() * 1000)
    )
    db.add(friendship)
    db.commit()
    return {"status": "PENDING"}

@router.post("/friends/snap/{user_id}")
def snap_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot snap yourself")
        
    # 1. Check if already friends
    is_friend = db.query(Friendship).filter(
        ((Friendship.user_id == current_user.id) & (Friendship.friend_id == user_id)) |
        ((Friendship.user_id == user_id) & (Friendship.friend_id == current_user.id)),
        Friendship.status == "ACCEPTED"
    ).first()
    
    if is_friend:
        # 已是好友时，清理遗留的临时会话关系
        db.query(TempFriendship).filter(
            ((TempFriendship.user_id == current_user.id) & (TempFriendship.partner_id == user_id)) |
            ((TempFriendship.user_id == user_id) & (TempFriendship.partner_id == current_user.id))
        ).delete(synchronize_session=False)
        db.commit()
        return {"status": "FRIENDS"}
        
    # 2. Check if I already snapped this user
    my_snap = db.query(Snap).filter(
        Snap.user_id == current_user.id,
        Snap.target_id == user_id
    ).first()
    
    if my_snap:
        # Check if they also snapped me (mutual)
        their_snap = db.query(Snap).filter(
            Snap.user_id == user_id,
            Snap.target_id == current_user.id
        ).first()
        if their_snap:
            return {"status": "MATCHED"}
        return {"status": "SNAPPED"}
        
    # 3. Check if they snapped me (mutual match!)
    their_snap = db.query(Snap).filter(
        Snap.user_id == user_id,
        Snap.target_id == current_user.id
    ).first()
    
    if their_snap:
        # Create mutual friendship
        friendship = Friendship(
            user_id=current_user.id,
            friend_id=user_id,
            status="ACCEPTED",
            created_at=int(time.time() * 1000)
        )
        # Also record my snap
        new_snap = Snap(user_id=current_user.id, target_id=user_id)
        db.add(friendship)
        db.add(new_snap)
        # 成为好友后，删除双方临时会话关系
        db.query(TempFriendship).filter(
            ((TempFriendship.user_id == current_user.id) & (TempFriendship.partner_id == user_id)) |
            ((TempFriendship.user_id == user_id) & (TempFriendship.partner_id == current_user.id))
        ).delete(synchronize_session=False)
        db.commit()
        return {"status": "MATCHED"}
    else:
        # Record my snap
        new_snap = Snap(user_id=current_user.id, target_id=user_id)
        db.add(new_snap)
        db.commit()
        return {"status": "SNAPPED"}

@router.get("/friends/snap/status/{user_id}")
def get_snap_status(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Check friendship first
    is_friend = db.query(Friendship).filter(
        ((Friendship.user_id == current_user.id) & (Friendship.friend_id == user_id)) |
        ((Friendship.user_id == user_id) & (Friendship.friend_id == current_user.id)),
        Friendship.status == "ACCEPTED"
    ).first()
    
    if is_friend:
        return {"status": "FRIENDS"}
        
    # Check snap
    my_snap = db.query(Snap).filter(
        Snap.user_id == current_user.id,
        Snap.target_id == user_id
    ).first()
    
    if my_snap:
        return {"status": "SNAPPED"}
    
    return {"status": "NONE"}
